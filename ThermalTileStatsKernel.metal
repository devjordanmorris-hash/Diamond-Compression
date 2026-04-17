//
//  ThermalTileStatsKernel.metal
//  daimond compression
//
//  Created by Jordan Morris  on 04/04/2026.
//

#include <metal_stdlib>
using namespace metal;

struct ThermalTileStatsParams {
    uint width;
    uint height;
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

inline float thermal_luminance(uchar4 px) {
    return 0.299f * float(px.r) + 0.587f * float(px.g) + 0.114f * float(px.b);
}

kernel void thermalTileStatsKernel(
    const device uchar4 *pixels                    [[buffer(0)]],
    device ThermalTileStats *tileStatsOut          [[buffer(1)]],
    constant ThermalTileStatsParams &params        [[buffer(2)]],
    uint tid                                       [[thread_index_in_threadgroup]],
    uint threadsPerGroup                           [[threads_per_threadgroup]],
    uint groupPos                                  [[threadgroup_position_in_grid]]
) {
    // We dispatch one threadgroup per tile, using a 4x4 tile layout.
    const uint tileIndex = groupPos;
    if (tileIndex >= 16) {
        return;
    }

    const uint tileX = tileIndex % 4;
    const uint tileY = tileIndex / 4;

    const uint x0 = tileX * params.width / 4;
    const uint x1 = max(x0 + 1, (tileX + 1) * params.width / 4);
    const uint y0 = tileY * params.height / 4;
    const uint y1 = max(y0 + 1, (tileY + 1) * params.height / 4);

    const uint midX = (x0 + x1) / 2;
    const uint midY = (y0 + y1) / 2;
    const uint tileWidth = x1 - x0;
    const uint tileHeight = y1 - y0;
    const uint totalTilePixels = tileWidth * tileHeight;

    threadgroup float tgTileTotal[256];
    threadgroup float tgTileMin[256];
    threadgroup float tgTileMax[256];
    threadgroup float tgTopLeftEnergy[256];
    threadgroup float tgBottomRightEnergy[256];
    threadgroup float tgLeftEnergy[256];
    threadgroup float tgRightEnergy[256];
    threadgroup float tgTopEnergy[256];
    threadgroup float tgBottomEnergy[256];
    threadgroup uint tgTileCount[256];

    float localTileTotal = 0.0f;
    float localTileMin = 1e9f;
    float localTileMax = -1e9f;
    float localTopLeftEnergy = 0.0f;
    float localBottomRightEnergy = 0.0f;
    float localLeftEnergy = 0.0f;
    float localRightEnergy = 0.0f;
    float localTopEnergy = 0.0f;
    float localBottomEnergy = 0.0f;
    uint localTileCount = 0;

    for (uint linearIndex = tid; linearIndex < totalTilePixels; linearIndex += threadsPerGroup) {
        const uint localY = linearIndex / tileWidth;
        const uint localX = linearIndex % tileWidth;
        const uint x = x0 + localX;
        const uint y = y0 + localY;
        const uint pixelIndex = y * params.width + x;

        const uchar4 px = pixels[pixelIndex];
        const float l = thermal_luminance(px);

        localTileTotal += l;
        localTileMin = min(localTileMin, l);
        localTileMax = max(localTileMax, l);
        localTileCount += 1;

        if (x < midX && y < midY) {
            localTopLeftEnergy += l;
        } else if (x >= midX && y >= midY) {
            localBottomRightEnergy += l;
        }

        if (x < midX) {
            localLeftEnergy += l;
        } else {
            localRightEnergy += l;
        }

        if (y < midY) {
            localTopEnergy += l;
        } else {
            localBottomEnergy += l;
        }
    }

    tgTileTotal[tid] = localTileTotal;
    tgTileMin[tid] = localTileCount > 0 ? localTileMin : 1e9f;
    tgTileMax[tid] = localTileCount > 0 ? localTileMax : -1e9f;
    tgTopLeftEnergy[tid] = localTopLeftEnergy;
    tgBottomRightEnergy[tid] = localBottomRightEnergy;
    tgLeftEnergy[tid] = localLeftEnergy;
    tgRightEnergy[tid] = localRightEnergy;
    tgTopEnergy[tid] = localTopEnergy;
    tgBottomEnergy[tid] = localBottomEnergy;
    tgTileCount[tid] = localTileCount;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = threadsPerGroup / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            tgTileTotal[tid] += tgTileTotal[tid + stride];
            tgTileMin[tid] = min(tgTileMin[tid], tgTileMin[tid + stride]);
            tgTileMax[tid] = max(tgTileMax[tid], tgTileMax[tid + stride]);
            tgTopLeftEnergy[tid] += tgTopLeftEnergy[tid + stride];
            tgBottomRightEnergy[tid] += tgBottomRightEnergy[tid + stride];
            tgLeftEnergy[tid] += tgLeftEnergy[tid + stride];
            tgRightEnergy[tid] += tgRightEnergy[tid + stride];
            tgTopEnergy[tid] += tgTopEnergy[tid + stride];
            tgBottomEnergy[tid] += tgBottomEnergy[tid + stride];
            tgTileCount[tid] += tgTileCount[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        ThermalTileStats out;
        out.tileTotal = tgTileTotal[0];
        out.tileMin = tgTileCount[0] > 0 ? tgTileMin[0] : 0.0f;
        out.tileMax = tgTileCount[0] > 0 ? tgTileMax[0] : 0.0f;
        out.topLeftEnergy = tgTopLeftEnergy[0];
        out.bottomRightEnergy = tgBottomRightEnergy[0];
        out.leftEnergy = tgLeftEnergy[0];
        out.rightEnergy = tgRightEnergy[0];
        out.topEnergy = tgTopEnergy[0];
        out.bottomEnergy = tgBottomEnergy[0];
        out.tileCount = tgTileCount[0];
        tileStatsOut[tileIndex] = out;
    }
}
