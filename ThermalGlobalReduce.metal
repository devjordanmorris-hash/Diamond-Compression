//
//  ThermalGlobalReduce.metal
//  daimond compression
//
//  Created by Jordan Morris  on 04/04/2026.
//

#include <metal_stdlib>
using namespace metal;

struct ThermalGlobalReduceParams {
    uint width;
    uint height;
    uint totalPixels;
    uint groupCount;
};

inline float thermal_luminance(uchar4 px) {
    return 0.299f * float(px.r) + 0.587f * float(px.g) + 0.114f * float(px.b);
}

// Writes one partial sum per threadgroup into `partialSums[groupPos]`
kernel void thermalGlobalReduceKernel(
    const device uchar4 *pixels                    [[buffer(0)]],
    device float *partialSums                      [[buffer(1)]],
    constant ThermalGlobalReduceParams &params     [[buffer(2)]],
    uint tid                                       [[thread_index_in_threadgroup]],
    uint threadsPerGroup                           [[threads_per_threadgroup]],
    uint groupPos                                  [[threadgroup_position_in_grid]]
) {
    threadgroup float tgSums[256];

    float localSum = 0.0f;
    uint start = groupPos * threadsPerGroup + tid;
    uint fullStride = threadsPerGroup * max(1u, params.groupCount);

    // Grid-stride loop over all pixels
    const uint groupId = groupPos;
   
    for (uint i = start; i < params.totalPixels; i += fullStride) {
        const uchar4 px = pixels[i];
        localSum += thermal_luminance(px);
    }

    tgSums[tid] = localSum;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Reduction within threadgroup
    for (uint s = threadsPerGroup / 2; s > 0; s >>= 1) {
        if (tid < s) {
            tgSums[tid] += tgSums[tid + s];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        partialSums[groupPos] = tgSums[0];
    }
}
