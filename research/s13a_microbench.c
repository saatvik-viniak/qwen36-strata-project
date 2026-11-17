/* s13a_microbench.c — S13-(a): the pool's pattern-exact host-memory microbench
 * (CPU-only; the server MUST be stopped — the runner enforces the window).
 *
 * Question it answers (SUGGESTIONS.MD S13, the pre-registered decision rules):
 *   at the LIVE pool's read shape — 8 workers, per step 24 distinct ~2-MiB expert
 *   blobs per layer scattered over 41 layer-spans (3 blobs per worker per layer,
 *   123 blobs per worker per step, sequential within each blob), vs the
 *   routing-shared shape (k=8, the same blobs every step) — what aggregate GB/s
 *   does this box's host memory deliver?
 * Compare against the live pool's measured 19.0 GB/s aggregate (20.3 stall-free)
 * and the S12-B 28 GB/s single-stream warmed ceiling:
 *   SPLIT >= ~25 GB/s  -> the pattern cost is small; the live pool is bounded
 *                         elsewhere (sync/imbalance/launch) -> the pattern levers die.
 *   ~14–20 GB/s        -> the pattern cost matches the live reading -> the levers
 *                         proceed (the within-reader prefetch distance, the repack).
 *   <= ~10 GB/s        -> the pattern cost dominates -> (b) is the big lever.
 *
 * Design (the pre-agreed spec, RESEARCH_HANDOFF.md #27):
 *   - 41 layer-spans; each span holds 256 blob slots; blob bytes = span/256
 *     (the Q5_K_S arena: 21.14 GiB -> 516 MiB spans -> 2.016 MiB blobs; the
 *     Q4_K_S arena: 17.45 GiB -> 422 MiB spans -> 1.65 MiB blobs).
 *     argv[1] = the arena GiB (default 17.45 = the current champion model).
 *   - SPLIT phase: per (rep, step, layer) pick k=24 DISTINCT blob slots
 *     pseudo-randomly (an LCG seeded by rep/step/layer — fresh per step, the
 *     live re-routing), assign round-robin over the workers, each worker reads
 *     its blobs in layer order, each blob sequentially with the S12-B reader
 *     verbatim (64-B stride, volatile sink — full cache-line DRAM traffic).
 *     A rep = 4 steps.
 *   - SHARED phase: k=8 distinct slots per layer picked ONCE per rep (seeded),
 *     the SAME sets across the rep's 4 steps. Two variants: SHARED-DIST (each
 *     blob read exactly once across the workers — the dedup model; the
 *     temporal-locality / L3-absorption test) and SHARED-ALL (every worker
 *     reads ALL k blobs of every layer — the spec's literal redundant-reader
 *     probe).
 *   - Configs: 5-thread SPLIT, 8-thread SPLIT, 8-thread SHARED; each: 2 untimed
 *     warm-ups + 3 timed reps, the minor-fault counters per pass (the S12-B
 *     run-2 protocol verbatim). Only the spawn+join (the reads) is timed.
 *   - THP forced OFF (MADV_NOHUGEPAGE) = the live pool's 4-KiB page state;
 *     the THP mode + the anon-THP counts printed so the state is verified.
 *
 * PRECONDITION: no server may hold the expert arena (a 25.4 GiB box cannot host
 * a second one) — run with every server stopped (the runner stops + restores).
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/mman.h>
#include <time.h>
#include <stdint.h>
#include <string.h>

#ifndef MADV_NOHUGEPAGE
#define MADV_NOHUGEPAGE 15
#endif

#define LAYERS 41
#define SLOTS_PER_LAYER 256
#define K_SPLIT 24
#define K_SHARED 8
#define STEPS_PER_REP 4
#define NREPS 3
#define NWARM 2
#define ALIGN2M ((size_t)0x200000)
#define MAX_THREADS 16

static volatile unsigned char *g_base;
static size_t g_span;   /* per-layer span bytes (2-MiB aligned) */
static size_t g_blob;   /* blob bytes = span / SLOTS_PER_LAYER */
static uint64_t g_sink; /* global OR of the thread sinks (defeat DCE) */

static double now_ms(void){
  struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec * 1000.0 + (double)t.tv_nsec / 1e6;
}

static long vmstat_anon_thp(void){
  FILE *f = fopen("/proc/vmstat", "r");
  long v = -1, val;
  char line[256];
  if (!f) return -1;
  while (fgets(line, sizeof line, f))
    if (sscanf(line, "nr_anon_transparent_hugepages %ld", &val) == 1) { v = val; break; }
  fclose(f);
  return v;
}

/* minor-fault count from /proc/self/stat (field 10) — the S12-B helper verbatim */
static long get_minflt(void){
  FILE *f = fopen("/proc/self/stat", "r");
  long v = -1;
  char line[4096];
  if (!f) return -1;
  if (fgets(line, sizeof line, f)) {
    char *p = line;
    int field = 0;
    while (field < 10 && *p) {
      while (*p == ' ') p++;
      if (*p) field++;
      if (field == 10) { v = atol(p); break; }
      while (*p && *p != ' ') p++;
    }
  }
  fclose(f);
  return v;
}

/* 32-bit LCG (numerical recipes) */
static unsigned lcg(unsigned *s){ *s = *s * 1664525u + 1013904223u; return *s; }

/* pick k DISTINCT slot indices in [0, SLOTS_PER_LAYER) */
static void pick_slots(unsigned seed_in, int k, int *out){
  unsigned s = seed_in;
  char used[SLOTS_PER_LAYER]; memset(used, 0, sizeof used);
  int n = 0;
  while (n < k){
    unsigned r = lcg(&s) % SLOTS_PER_LAYER;
    if (!used[r]){ used[r] = 1; out[n++] = (int)r; }
  }
}

/* one worker: read its blob list in order, the S12-B reader verbatim */
typedef struct { int n; const int *slots; uint64_t sink; } task_t;

static void *reader(void *arg){
  task_t *t = (task_t *)arg;
  uint64_t s = 0;
  for (int b = 0; b < t->n; b++){
    const volatile unsigned char *p =
      g_base + (size_t)b * g_span + (size_t)t->slots[b] * g_blob;
    size_t len = g_blob;
    for (size_t i = 0; i < len; i += 64) s += p[i];  /* real loads: volatile sink */
  }
  t->sink = s;
  return NULL;
}

/* one timed rep: build the per-worker slot lists per step, time the reads.
 * fixed_sets: 0 = fresh sets per step (SPLIT), 1 = the same sets all steps,
 * each blob read once (the dedup model); 2 = the same sets all steps AND every
 * worker reads ALL k blobs of every layer (the spec's literal SHARED — the
 * redundant-reader L3-absorption probe).
 * Returns GB/s = total bytes / total read ms (1 GB/s = 1e6 B/ms). */
static double run_rep(int nthreads, int k, int fixed_sets, unsigned seed_in,
                      long *faults_out, double *el_out, size_t *bytes_out){
  pthread_t th[MAX_THREADS];
  task_t tasks[MAX_THREADS];
  static int sets[LAYERS][K_SPLIT];        /* per-layer slot sets */
  static int lists[MAX_THREADS][LAYERS * K_SPLIT]; /* per-worker slot lists */
  size_t total = 0;
  double tms = 0.0;
  long f0 = get_minflt();
  for (int st = 0; st < STEPS_PER_REP; st++){
    for (int L = 0; L < LAYERS; L++){
      unsigned sd = (fixed_sets == 0)
        ? (seed_in * 100000u + (unsigned)st * 41u + (unsigned)L)
        : (seed_in * 1000u + (unsigned)L);
      pick_slots(sd, k, sets[L]);
    }
    /* pack the per-worker lists (the live pool reads its jobs layer by layer):
     * fixed_sets 0/1: worker w takes slots w, w+nthreads, ... of each layer's
     * set (round-robin; every blob read exactly once across the workers);
     * fixed_sets 2: every worker takes ALL k slots of every layer (redundant) */
    for (int w = 0; w < nthreads; w++){
      int cnt = 0;
      for (int L = 0; L < LAYERS; L++){
        if (fixed_sets == 2){
          for (int j = 0; j < k; j++) lists[w][cnt++] = sets[L][j];
        } else {
          for (int j = w; j < k; j += nthreads) lists[w][cnt++] = sets[L][j];
        }
      }
      tasks[w].n = cnt;
      tasks[w].slots = lists[w];
      tasks[w].sink = 0;
      total += (size_t)cnt * g_blob;
    }
    double t0 = now_ms();
    for (int w = 0; w < nthreads; w++)
      if (pthread_create(&th[w], NULL, reader, &tasks[w]) != 0){
        fprintf(stderr, "pthread_create failed\n"); exit(1);
      }
    for (int w = 0; w < nthreads; w++) pthread_join(th[w], NULL);
    tms += now_ms() - t0;
  }
  long f1 = get_minflt();
  if (faults_out) *faults_out = (f0 >= 0 && f1 >= 0) ? f1 - f0 : -1;
  if (el_out) *el_out = tms;
  if (bytes_out) *bytes_out = total;
  for (int w = 0; w < nthreads; w++) g_sink |= tasks[w].sink;
  return (double)total / tms / 1e6;
}

static double median3(double a, double b, double c){
  double mn = a < b ? a : b; if (c < mn) mn = c;
  double mx = a > b ? a : b; if (c > mx) mx = c;
  return a + b + c - mn - mx;
}

/* one config: 2 untimed warm-ups + 3 timed reps; prints per-rep lines + the median */
static void run_config(const char *name, int nthreads, int k, int fixed_sets,
                       unsigned seed){
  double b[NREPS]; long f[NREPS]; double e[NREPS]; size_t by[NREPS];
  printf("%s: %d threads, k=%d, %d blobs/worker/step, %.2f GB per rep (%d steps)\n",
         name, nthreads, k, LAYERS * (k / nthreads),
         (double)STEPS_PER_REP * LAYERS * k * g_blob / 1e9, STEPS_PER_REP);
  fflush(stdout);
  for (int i = 0; i < NWARM; i++){ run_rep(nthreads, k, fixed_sets, seed, NULL, NULL, NULL); }
  printf("%s: warm-ups done\n", name); fflush(stdout);
  for (int rep = 0; rep < NREPS; rep++){
    b[rep] = run_rep(nthreads, k, fixed_sets, seed, &f[rep], &e[rep], &by[rep]);
    printf("%s: rep%d %.2f GB/s (%.0f ms, %.2f GB, minor faults %ld)\n",
           name, rep, b[rep], e[rep], (double)by[rep] / 1e9, f[rep]);
    fflush(stdout);
  }
  printf("%s: median %.2f GB/s\n", name, median3(b[0], b[1], b[2]));
  fflush(stdout);
}

int main(int argc, char **argv){
  double arena_gib = argc > 1 ? atof(argv[1]) : 17.45;
  size_t arena = (size_t)(arena_gib * 1073741824.0);
  g_span = (arena / LAYERS) & ~(ALIGN2M - 1);
  g_blob = g_span / SLOTS_PER_LAYER;

  FILE *f = fopen("/sys/kernel/mm/transparent_hugepage/enabled", "r");
  char mode[128] = "(unreadable)";
  if (f){ if (!fgets(mode, sizeof mode, f)) mode[0] = 0; fclose(f); }
  printf("THP enabled: %s", mode);
  printf("arena %.2f GiB -> span %.1f MiB, blob %.3f MiB, %d slots/layer, %d layers\n",
         arena_gib, (double)g_span / 1048576.0, (double)g_blob / 1048576.0,
         SLOTS_PER_LAYER, LAYERS);
  printf("SPLIT: k=%d -> %d blobs/worker/step, %.2f GB/step total\n",
         K_SPLIT, LAYERS * (K_SPLIT / 8),
         (double)LAYERS * K_SPLIT * g_blob / 1e9);
  printf("SHARED: k=%d -> %d blobs/worker/step, %.2f GB/step total\n",
         K_SHARED, LAYERS * (K_SHARED / 8),
         (double)LAYERS * K_SHARED * g_blob / 1e9);
  fflush(stdout);

  long thp_before = vmstat_anon_thp();
  unsigned char *raw = malloc(arena + ALIGN2M);
  if (!raw){ fprintf(stderr, "malloc failed (is a server holding RAM?)\n"); return 1; }
  volatile unsigned char *base =
    (volatile unsigned char *)(((uintptr_t)raw + ALIGN2M - 1) & ~((uintptr_t)ALIGN2M - 1));
  size_t advised = arena & ~(ALIGN2M - 1);
  int r = madvise((void *)base, advised, MADV_NOHUGEPAGE);
  double t0 = now_ms();
  for (size_t i = 0; i < arena; i += 4096) base[i] = 1;
  printf("arena %.2f GiB; madvise(NOHUGEPAGE) rc=%d; touch %.1f s; anon-THP %ld -> %ld\n",
         arena_gib, r, (now_ms() - t0) / 1000.0, thp_before, vmstat_anon_thp());
  fflush(stdout);
  g_base = base;

  run_config("SPLIT-5t", 5, K_SPLIT, 0, 1u);
  run_config("SPLIT-8t", 8, K_SPLIT, 0, 2u);
  run_config("SHARED-DIST-8t", 8, K_SHARED, 1, 3u);
  run_config("SHARED-ALL-8t", 8, K_SHARED, 2, 4u);

  printf("sink %llu (defeat DCE)\n", (unsigned long long)g_sink);
  printf("done\n");
  free(raw);
  return 0;
}
