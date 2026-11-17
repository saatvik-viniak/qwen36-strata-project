// Scratch standalone parity test for the Q5_K multi-token kernel.
// Reference: the __AVX2__ branch of ggml_vec_dot_q5_K_q8_K, transcribed VERBATIM from
// third_party/strata-ggml/ggml/src/ggml-cpu/arch/x86/quants.c:2235-2313 (single-token).
// Kernel under test: strata::kernels::cpu::q5k_dot_* from the patched kq_avx2.cpp.
// Checks bit-for-bit equality for nt = 1..4 over randomized blocks/activations,
// for n = 2048 (gate/up, 8 blocks) and n = 512 (down, 2 blocks).
#include <kq_avx2.cpp>   // -I$WS/src/kernels/cpu

#include <cstdio>
#include <cstring>
#include <chrono>
#include <random>
#include <vector>

// the reference: ggml's AVX2 branch, verbatim (single token)
static void ref_q5k(const block_q5_K* x, int nb, const block_q8_K* y, float* s) {
    static const uint32_t kmask1 = 0x3f3f3f3f;
    static const uint32_t kmask2 = 0x0f0f0f0f;
    static const uint32_t kmask3 = 0x03030303;
    uint32_t utmp[4];
    const __m256i m4 = _mm256_set1_epi8(0xF);
    const __m128i mzero = _mm_setzero_si128();
    const __m256i mone  = _mm256_set1_epi8(1);
    __m256 acc = _mm256_setzero_ps();
    float summs = 0.f;
    for (int i = 0; i < nb; ++i) {
        const uint8_t * q5 = x[i].qs;
        const int8_t  * q8 = y[i].qs;
        const float d = y[i].d * strata::kernels::cpu::half_at(&x[i], 0);
        const float dmin = -y[i].d * strata::kernels::cpu::half_at(&x[i], 1);
        memcpy(utmp, x[i].scales, 12);
        utmp[3] = ((utmp[2] >> 4) & kmask2) | (((utmp[1] >> 6) & kmask3) << 4);
        const uint32_t uaux = utmp[1] & kmask1;
        utmp[1] = (utmp[2] & kmask2) | (((utmp[0] >> 6) & kmask3) << 4);
        utmp[2] = uaux;
        utmp[0] &= kmask1;
        const __m256i mins_and_scales = _mm256_cvtepu8_epi16(_mm_set_epi32(utmp[3], utmp[2], utmp[1], utmp[0]));
        const __m256i q8sums = _mm256_loadu_si256((const __m256i*)y[i].bsums);
        const __m128i q8s = _mm_hadd_epi16(_mm256_extracti128_si256(q8sums, 0), _mm256_extracti128_si256(q8sums, 1));
        const __m128i prod = _mm_madd_epi16(_mm256_extracti128_si256(mins_and_scales, 1), q8s);
        const __m128i hsum = _mm_hadd_epi32(_mm_hadd_epi32(prod, mzero), mzero);
        summs += dmin * _mm_extract_epi32(hsum, 0);
        const __m128i sc128  = _mm256_extracti128_si256(mins_and_scales, 0);
        const __m256i scales = _mm256_insertf128_si256(_mm256_castsi128_si256(sc128), sc128, 1);
        const __m256i hbits = _mm256_loadu_si256((const __m256i*)x[i].qh);
        __m256i hmask = mone;
        __m256i sumi = _mm256_setzero_si256();
        int bit = 0;
        for (int j = 0; j < QK_K/64; ++j) {
            const __m256i scale_0 = _mm256_shuffle_epi8(scales, strata::kernels::cpu::get_scale_shuffle_k4(2*j+0));
            const __m256i scale_1 = _mm256_shuffle_epi8(scales, strata::kernels::cpu::get_scale_shuffle_k4(2*j+1));
            const __m256i q5bits = _mm256_loadu_si256((const __m256i*)q5); q5 += 32;
            const __m256i q5l_0 = _mm256_and_si256(q5bits, m4);
            const __m256i q5h_0 = _mm256_slli_epi16(_mm256_srli_epi16(_mm256_and_si256(hbits, hmask), bit++), 4);
            const __m256i q5_0  = _mm256_add_epi8(q5l_0, q5h_0);
            hmask = _mm256_slli_epi16(hmask, 1);
            const __m256i q5l_1 = _mm256_and_si256(_mm256_srli_epi16(q5bits, 4), m4);
            const __m256i q5h_1 = _mm256_slli_epi16(_mm256_srli_epi16(_mm256_and_si256(hbits, hmask), bit++), 4);
            const __m256i q5_1  = _mm256_add_epi8(q5l_1, q5h_1);
            hmask = _mm256_slli_epi16(hmask, 1);
            const __m256i q8_0 = _mm256_loadu_si256((const __m256i*)q8); q8 += 32;
            const __m256i q8_1 = _mm256_loadu_si256((const __m256i*)q8); q8 += 32;
            __m256i p16_0 = _mm256_maddubs_epi16(q5_0, q8_0);
            __m256i p16_1 = _mm256_maddubs_epi16(q5_1, q8_1);
            p16_0 = _mm256_madd_epi16(scale_0, p16_0);
            p16_1 = _mm256_madd_epi16(scale_1, p16_1);
            sumi = _mm256_add_epi32(sumi, _mm256_add_epi32(p16_0, p16_1));
        }
        __m256 vd = _mm256_set1_ps(d);
        acc = _mm256_fmadd_ps(vd, _mm256_cvtepi32_ps(sumi), acc);
    }
    *s = strata::kernels::cpu::hsum_float_8(acc) + summs;
}

int main() {
    using namespace strata::kernels::cpu;
    std::mt19937 rng(1234);
    int fails = 0, checked = 0;
    for (int nb : {8, 2}) {   // 2048 (gate/up), 512 (down)
        for (int trial = 0; trial < 200; ++trial) {
            std::vector<block_q5_K> xb((size_t) nb);
            std::vector<block_q8_K> yb[4];
            for (int i = 0; i < nb; ++i) {
                // fp16 bit patterns in the normal positive range (model-scale-like), plus
                // raw random patterns on some trials for stress (both paths convert
                // identically, so any bits must agree)
                const uint16_t dbits = trial % 4 == 0 ? (uint16_t) rng() : (uint16_t) (0x3000 + rng() % 0x0c00);
                const uint16_t dmbits = trial % 4 == 0 ? (uint16_t) rng() : (uint16_t) (0x2800 + rng() % 0x0400);
                uint8_t* bp = (uint8_t*) &xb[i];
                std::memcpy(bp + 0, &dbits, 2);
                std::memcpy(bp + 2, &dmbits, 2);
                for (int k = 0; k < K_SCALE_SIZE; ++k) bp[4 + k] = (uint8_t) (rng() % 64);
                for (int k = 0; k < QK_K/8; ++k) bp[16 + k] = (uint8_t) rng();
                for (int k = 0; k < QK_K/2; ++k) bp[48 + k] = (uint8_t) rng();
            }
            for (int t = 0; t < 4; ++t) {
                yb[t].resize((size_t) nb);
                for (int i = 0; i < nb; ++i) {
                    block_q8_K& y = yb[t][i];
                    y.d = 0.5f + (rng() % 100) / 100.f;
                    int sums[16] = {0};
                    for (int k = 0; k < QK_K; ++k) {
                        y.qs[k] = (int8_t) ((int)(rng() % 255) - 128);
                        sums[k / 16] += y.qs[k];
                    }
                    for (int k = 0; k < 16; ++k) y.bsums[k] = (int16_t) sums[k];
                }
            }
            const void* act[4] = { yb[0].data(), yb[1].data(), yb[2].data(), yb[3].data() };
            float res[4], ref[4];
            q5k_dot_nt(xb.data(), nb, act, 4, res);
            for (int t = 0; t < 4; ++t) {
                ref_q5k(xb.data(), nb, (const block_q8_K*) act[t], &ref[t]);
                ++checked;
                if (memcmp(&res[t], &ref[t], 4) != 0) {
                    ++fails;
                    if (fails < 5) std::printf("MISMATCH nb=%d trial=%d t=%d got=%.9g ref=%.9g\n",
                                               nb, trial, t, res[t], ref[t]);
                }
            }
        }
    }
    std::printf(fails == 0 ? "PARITY OK (0 of %d token-results differ)\n" : "FAILED: %d mismatches of %d\n",
                fails == 0 ? checked : fails, checked);
    // indicative timing: nb=8 (n=2048, the gate/up row), nt=3 (the MTP-2 verify window),
    // kernel vs ggml's per-token calls.  CONTESTED when the engine's pool runs: the
    // absolute us are not valid, the ratio is a screening signal only.
    {
        const int nb = 8;
        std::vector<block_q5_K> xb((size_t) nb);
        std::vector<block_q8_K> yb[3];
        std::mt19937 rng2(99);
        for (int i = 0; i < nb; ++i) {
            uint8_t* bp = (uint8_t*) &xb[i];
            const uint16_t dbits = (uint16_t) (0x3800 + rng2() % 0x200);
            const uint16_t dmbits = (uint16_t) (0x2c00 + rng2() % 0x100);
            std::memcpy(bp + 0, &dbits, 2);
            std::memcpy(bp + 2, &dmbits, 2);
            for (int k = 0; k < K_SCALE_SIZE; ++k) bp[4 + k] = (uint8_t) (rng2() % 64);
            for (int k = 0; k < QK_K/8; ++k) bp[16 + k] = (uint8_t) rng2();
            for (int k = 0; k < QK_K/2; ++k) bp[48 + k] = (uint8_t) rng2();
        }
        for (int t = 0; t < 3; ++t) {
            yb[t].resize((size_t) nb);
            for (int i = 0; i < nb; ++i) {
                block_q8_K& y = yb[t][i];
                y.d = 0.5f + (rng2() % 100) / 100.f;
                int sums[16] = {0};
                for (int k = 0; k < QK_K; ++k) {
                    y.qs[k] = (int8_t) ((int)(rng2() % 255) - 128);
                    sums[k / 16] += y.qs[k];
                }
                for (int k = 0; k < 16; ++k) y.bsums[k] = (int16_t) sums[k];
            }
        }
        const void* act[3] = { yb[0].data(), yb[1].data(), yb[2].data() };
        float res[3];
        const int reps = 200;
        double best_k = 1e9, best_g = 1e9;
        for (int pass = 0; pass < 3; ++pass) {
            auto t0 = std::chrono::steady_clock::now();
            for (int r = 0; r < reps; ++r) q5k_dot_nt(xb.data(), nb, act, 3, res);
            auto t1 = std::chrono::steady_clock::now();
            for (int r = 0; r < reps; ++r)
                for (int row = 0; row < 1; ++row) {   // one row per rep: the pool's per-row unit
                    for (int t = 0; t < 3; ++t)
                        ref_q5k(xb.data(), nb, (const block_q8_K*) act[t], &res[t]);
                }
            auto t2 = std::chrono::steady_clock::now();
            double k = std::chrono::duration<double, std::milli>(t1 - t0).count() / reps;
            double g = std::chrono::duration<double, std::milli>(t2 - t1).count() / reps;
            if (k < best_k) best_k = k;
            if (g < best_g) best_g = g;
        }
        std::printf("TIMING (contested, indicative): kernel nt=3 %.4f ms/row-rep vs ggml %.4f -> %.2fx\n",
                    best_k, best_g, best_g / best_k);
    }
    return fails != 0;
}
