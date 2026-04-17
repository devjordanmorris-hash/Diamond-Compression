//
//  ThermalFingerprintPackKernel.metal
//  daimond compression
//
//  Created by Jordan Morris  on 04/04/2026.
//

#include <metal_stdlib>
using namespace metal;

struct ThermalFingerprintPackParams {
    float globalAverage;
};

struct ThermalTileStats {
    float tileTotal;
    float tileMin;
    float tileMax;
    float topLeftEnergy;
    float bottomRightEnergy;
    float leftEnergy;
    float rightEnergy;
    float topEnergy;
    float bottomEnergy;
    uint tileCount;
};

kernel void thermalFingerprintPackKernel(
    const device ThermalTileStats *tileStats        [[buffer(0)]],
    device ulong *fingerprints                      [[buffer(1)]],
    constant ThermalFingerprintPackParams &params   [[buffer(2)]],
    uint tid                                        [[thread_index_in_threadgroup]],
    uint threadsPerGroup                            [[threads_per_threadgroup]]
) {
    threadgroup ulong packedNibbles[16];

    if (tid < 16) {
        const ThermalTileStats stats = tileStats[tid];

        const float tileAverage = stats.tileCount > 0
            ? stats.tileTotal / float(stats.tileCount)
            : 0.0f;

        const float rawNormalized = tileAverage - params.globalAverage;
        const float normalized = floor(rawNormalized / 4.0f) * 4.0f;

        ulong band = 0;
        if (normalized < -32.0f) {
            band = 0;
        } else if (normalized < 0.0f) {
            band = 1;
        } else if (normalized < 32.0f) {
            band = 2;
        } else {
            band = 3;
        }

        const ulong contrastFlag = (stats.tileMax - stats.tileMin) > 36.0f ? 0x4UL : 0x0UL;

        const float diagonalBias = stats.topLeftEnergy - stats.bottomRightEnergy;
        const float horizontalBias = stats.leftEnergy - stats.rightEnergy;
        const float verticalBias = stats.topEnergy - stats.bottomEnergy;
        const float axialBias = fabs(horizontalBias) > fabs(verticalBias) ? horizontalBias : verticalBias;
        const float dominantBias = fabs(diagonalBias) > fabs(axialBias) ? diagonalBias : axialBias;
        const ulong directionFlag = dominantBias > 0.0f ? 0x8UL : 0x0UL;

        packedNibbles[tid] = (band & 0x3UL) | contrastFlag | directionFlag;
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid == 0) {
        ulong fingerprint = 0;
        for (uint i = 0; i < 16; ++i) {
            fingerprint |= (packedNibbles[i] << (i * 4));
        }
        fingerprints[0] = fingerprint;
    }
}
