/* s11_pin_probe.c — S11 lever 1's completion probe (CPU/GPU-diagnostic, ~30 s).
   The compose binary's pinerr diagnostic answered S11-1's first question: every
   cudaHostAlloc for the 21.14 GiB expert arena fails with "out of memory"
   (strata-qwen36.log, every compose serve since 09:02Z; the base binaries fail
   silently — the diagnostic rode only the compose build). "out of memory" does
   not distinguish a WSL2 page-locked cap from fragmentation. This probe asks
   cudaHostAlloc for graduated sizes (1, 2, 4, 8, 12, 16, 19, 21.14 GiB), frees
   between attempts, and prints the exact cudaGetErrorString per size.
   Decision rule (SUGGESTIONS.MD S11): a clean cut (small sizes succeed, large
   fail) = a size-dependent page-locked cap -> pinned is IMPOSSIBLE for 21.14
   GiB on this box -> S11's levers 2-3 carry (now S13/S14's pattern levers);
   everything fails = no page-locked capacity at all (a driver/DMA setup issue
   -> check the WSL GPU driver's pinned settings); everything succeeds = the
   arena failure is fragmentation/timing -> a retry/reserve path is feasible.
   PRECONDITION: run with every server stopped (the 21.14 GiB ask thrashes a
   25.4 GiB box that already holds arenas). No engine source is touched. */
#define _GNU_SOURCE
#include <stdio.h>
#include <cuda_runtime.h>
#include <time.h>

static double now_s(void){
  struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t);
  return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

int main(void){
  const double sizes_gib[] = {1, 2, 4, 8, 12, 16, 19, 21.14};
  const int n = (int)(sizeof sizes_gib / sizeof sizes_gib[0]);
  printf("THP/pinned probe: graduated cudaHostAlloc asks, freed between attempts\n");
  for (int i = 0; i < n; ++i){
    size_t bytes = (size_t)(sizes_gib[i] * 1073741824.0);
    void *p = NULL;
    double t0 = now_s();
    cudaError_t rc = cudaHostAlloc(&p, bytes, cudaHostAllocDefault);
    double ms = (now_s() - t0) * 1000.0;
    printf("ask %6.2f GiB -> %s (%s) in %.0f ms\n",
           sizes_gib[i],
           rc == cudaSuccess ? "OK" : "FAILED",
           cudaGetErrorString(rc), ms);
    if (rc == cudaSuccess) {
      /* touch the first and last page so the allocation is real, then free */
      volatile unsigned char *c = (volatile unsigned char *)p;
      c[0] = 1; c[bytes - 4096] = 1;
      cudaFreeHost(p);
    } else {
      cudaGetLastError();   /* clear the sticky error for the next ask */
    }
  }
  printf("done\n");
  return 0;
}
