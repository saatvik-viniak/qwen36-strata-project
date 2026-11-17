/* s12b_microbench.c — S12 lever B: the arena-sized TLB test (CPU-only, ~60 s).
   malloc 21.14 GiB (the expert arena's size), touch every 4 KiB page, then
   sequential read passes timed by 5 and 8 worker threads, 3 reps each, with
   transparent hugepages FORCED OFF (MADV_NOHUGEPAGE); then the S11-3 recipe
   verbatim (pad + 2 MiB round-up + madvise(MADV_HUGEPAGE)) and repeat.
   Decision rule (SUGGESTIONS.MD S12-B): THP-on >= +10% faster at the same
   thread count -> implement STRATA_THP; within +/-5% -> the TLB term is small
   -> drop S11-3. Prints THP state, touch times, per-pass GB/s, and the
   anon-THP counts (from /proc/vmstat) so the recipe's engagement is verified,
   not assumed. PRECONDITION: no server may hold the 21.14 GiB arena (a
   25.4 GiB box cannot host a second one) — run with every server stopped. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <sys/mman.h>
#include <time.h>
#include <stdint.h>

#ifndef MADV_HUGEPAGE
#define MADV_HUGEPAGE 14
#endif
#ifndef MADV_NOHUGEPAGE
#define MADV_NOHUGEPAGE 15
#endif

#define ARENA_BYTES ((size_t)(21.14 * 1073741824.0))
#define ALIGN2M     ((size_t)0x200000)

static volatile unsigned char *g_base;
static size_t g_chunk;

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

/* minor-fault count from /proc/self/stat (field 10, 1-based; comm has no
   spaces for this binary, so splitting on single spaces is safe) */
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

typedef struct { size_t off, len; double ms; uint64_t sink; } task_t;

static void *reader(void *arg){
  task_t *t = (task_t *)arg;
  const volatile unsigned char *p = g_base + t->off;
  uint64_t s = 0;
  for (size_t i = 0; i < t->len; i += 64) s += p[i];  /* real loads: volatile sink */
  t->sink = s;
  return NULL;
}

/* one timed pass: nthreads contiguous chunks read in parallel; returns GB/s,
   and reports the pass's elapsed ms and minor-fault delta */
static double pass(int nthreads, task_t *tasks, long *faults_out, double *el_out){
  pthread_t th[32];
  size_t total = 0;
  for (int i = 0; i < nthreads; i++){
    tasks[i].off  = (size_t)i * g_chunk;
    tasks[i].len  = g_chunk;
    tasks[i].sink = 0;
  }
  long f0 = get_minflt();
  double t0 = now_ms();
  for (int i = 0; i < nthreads; i++)
    if (pthread_create(&th[i], NULL, reader, &tasks[i]) != 0){
      fprintf(stderr, "pthread_create failed\n"); exit(1);
    }
  for (int i = 0; i < nthreads; i++) pthread_join(th[i], NULL);
  double el = now_ms() - t0;
  long f1 = get_minflt();
  if (faults_out) *faults_out = (f0 >= 0 && f1 >= 0) ? f1 - f0 : -1;
  if (el_out) *el_out = el;
  for (int i = 0; i < nthreads; i++) total += tasks[i].len;
  return (double)total / el / 1e6;   /* bytes/ms -> GB/s (1 GB/s = 1e6 B/ms) */
}

static double median3(double a, double b, double c){
  double mn = a < b ? a : b; if (c < mn) mn = c;
  double mx = a > b ? a : b; if (c > mx) mx = c;
  return a + b + c - mn - mx;
}

static void run_phase(const char *name, int thp_on){
  long thp_before = vmstat_anon_thp();
  unsigned char *raw = malloc(ARENA_BYTES + ALIGN2M);
  if (!raw){ fprintf(stderr, "%s: malloc failed (is a server holding RAM?)\n", name); exit(1); }
  volatile unsigned char *base =
    (volatile unsigned char *)(((uintptr_t)raw + ALIGN2M - 1) & ~((uintptr_t)ALIGN2M - 1));
  size_t advised = ARENA_BYTES & ~(ALIGN2M - 1);
  int r = madvise((void *)base, advised, thp_on ? MADV_HUGEPAGE : MADV_NOHUGEPAGE);
  printf("%s: arena %.2f GiB, madvise(%s) rc=%d\n",
         name, (double)ARENA_BYTES / 1073741824.0,
         thp_on ? "MADV_HUGEPAGE" : "MADV_NOHUGEPAGE", r);
  double t0 = now_ms();
  for (size_t i = 0; i < ARENA_BYTES; i += 4096) base[i] = 1;
  double touch_s = (now_ms() - t0) / 1000.0;
  long thp_after = vmstat_anon_thp();
  printf("%s: touch %.1f s; anon-THP %ld -> %ld (delta %ld pages = %ld MiB of 2 MiB pages)\n",
         name, touch_s, thp_before, thp_after,
         thp_after - thp_before, (thp_after - thp_before) * 2);
  g_base = base;
  task_t tasks[32];
  double b5[3], b8[3];
  long f5[3], f8[3];
  double e5[3], e8[3];
  g_chunk = (ARENA_BYTES / 5) & ~((size_t)63);
  pass(5, tasks, 0, 0);   /* two untimed warm-ups: the first passes run cold */
  pass(5, tasks, 0, 0);
  for (int rep = 0; rep < 3; rep++){
    b5[rep] = pass(5, tasks, &f5[rep], &e5[rep]);
    printf("%s: 5t rep%d %.2f GB/s (%.2f s, minor faults %ld)\n",
           name, rep, b5[rep], e5[rep] / 1000.0, f5[rep]);
  }
  printf("%s: 5 threads median %.2f GB/s\n", name, median3(b5[0], b5[1], b5[2]));
  g_chunk = (ARENA_BYTES / 8) & ~((size_t)63);
  pass(8, tasks, 0, 0);
  for (int rep = 0; rep < 3; rep++){
    b8[rep] = pass(8, tasks, &f8[rep], &e8[rep]);
    printf("%s: 8t rep%d %.2f GB/s (%.2f s, minor faults %ld)\n",
           name, rep, b8[rep], e8[rep] / 1000.0, f8[rep]);
  }
  printf("%s: 8 threads median %.2f GB/s\n", name, median3(b8[0], b8[1], b8[2]));
  free((void *)raw);
}

int main(void){
  FILE *f = fopen("/sys/kernel/mm/transparent_hugepage/enabled", "r");
  char mode[128] = "(unreadable)";
  if (f){ if (!fgets(mode, sizeof mode, f)) mode[0] = 0; fclose(f); }
  printf("THP enabled: %s", mode);
  printf("arena size: %.2f GiB\n", (double)ARENA_BYTES / 1073741824.0);
  run_phase("THP-OFF", 0);
  run_phase("THP-ON ", 1);
  printf("done\n");
  return 0;
}
