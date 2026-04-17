#include <metal_stdlib>
using namespace metal;

// GPU output must match what the CPU encoder expects.
// Here we ONLY output:
//   • bucketID
//   • signed 5-5-5 residual (UInt16)
//
// No dx/dy, no shape/orient, no rolling base — CPU handles all chain logic.
// Residuals are packed against a fixed neutral RGB base (128,128,128) in GPU mode.

struct GPUOutput {
    uchar  bucketID;
    ushort signedResidual;
    uchar  _padding;
};

// Pack signed 5-5-5 residual (same math as CPU Diamond.residual555_signed)
inline ushort pack_signed_555(uchar r, uchar g, uchar b,
                              uchar baseR, uchar baseG, uchar baseB)
{
    int dr = (int)r - (int)baseR;
    int dg = (int)g - (int)baseG;
    int db = (int)b - (int)baseB;

    // Convert to signed 5-bit
    int r5 = clamp(dr >> 3, -16, 15);
    int g5 = clamp(dg >> 3, -16, 15);
    int b5 = clamp(db >> 3, -16, 15);

    ushort ur5 = (ushort)(r5 & 0x1F);
    ushort ug5 = (ushort)(g5 & 0x1F);
    ushort ub5 = (ushort)(b5 & 0x1F);

    return (ushort)((ur5 << 10) | (ug5 << 5) | ub5);
}

kernel void diamond_preprocess(
    const device uint *inPixels [[buffer(0)]],
    const device uint *baseRGBBuffer [[buffer(1)]],
    device GPUOutput *outBuffer [[buffer(2)]],
    const device uint *totalCountBuffer [[buffer(3)]],
    uint tid [[thread_position_in_grid]])
{
    uint totalCount = totalCountBuffer[0];
    if (tid >= totalCount) {
        return;
    }

    uint rgb = inPixels[tid];

    uchar r = (rgb >> 16) & 0xFF;
    uchar g = (rgb >> 8) & 0xFF;
    uchar b = rgb & 0xFF;

    // CPU-compatible bucket ID
    uchar bucket =
        ((r >> 6) << 4) |
        ((g >> 6) << 2) |
        ((b >> 6));

    // GPU residuals must stay aligned with the encoder/decoder contract.
    // In GPU mode we now use a fixed neutral base for every pixel.
    // Keep the incoming base buffer in the signature for host compatibility,
    // but ignore it here so residual packing is deterministic.
    uchar baseR = 128;
    uchar baseG = 128;
    uchar baseB = 128;

    ushort packedResidual = pack_signed_555(r, g, b, baseR, baseG, baseB);

    outBuffer[tid].bucketID = bucket;
    outBuffer[tid].signedResidual = packedResidual;
    outBuffer[tid]._padding = 0;
}
