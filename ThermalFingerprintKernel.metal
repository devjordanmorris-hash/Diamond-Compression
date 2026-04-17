#include <metal_stdlib>
using namespace metal;

struct ThermalFingerprintParams {
    uint width;
    uint height;
};

kernel void thermalFingerprintKernel(
    const device uchar4 *pixels            [[buffer(0)]],
    device ulong *fingerprints             [[buffer(1)]],
    constant ThermalFingerprintParams &p   [[buffer(2)]],
    uint gid                               [[thread_position_in_grid]]
) {
    // One thread builds one whole fingerprint for one image.
    // First pass: compute global average luminance.
    float totalLuminance = 0.0f;
    uint sampleCount = p.width * p.height;

    for (uint y = 0; y < p.height; ++y) {
        for (uint x = 0; x < p.width; ++x) {
            uint idx = y * p.width + x;
            uchar4 px = pixels[idx];
            float l = 0.299f * float(px.r) + 0.587f * float(px.g) + 0.114f * float(px.b);
            totalLuminance += l;
        }
    }

    float globalAverage = sampleCount > 0 ? totalLuminance / float(sampleCount) : 0.0f;

    ulong fingerprint = 0;
    uint nibbleIndex = 0;

    // 4x4 tiles -> 16 nibbles -> 64 bits
    for (uint gy = 0; gy < 4; ++gy) {
        for (uint gx = 0; gx < 4; ++gx) {
            uint x0 = gx * p.width / 4;
            uint x1 = max(x0 + 1, (gx + 1) * p.width / 4);
            uint y0 = gy * p.height / 4;
            uint y1 = max(y0 + 1, (gy + 1) * p.height / 4);

            float tileTotal = 0.0f;
            uint tileCount = 0;
            float tileMin = 1e9f;
            float tileMax = -1e9f;

            float topLeftEnergy = 0.0f;
            float bottomRightEnergy = 0.0f;
            float leftEnergy = 0.0f;
            float rightEnergy = 0.0f;
            float topEnergy = 0.0f;
            float bottomEnergy = 0.0f;

            uint midX = (x0 + x1) / 2;
            uint midY = (y0 + y1) / 2;

            for (uint y = y0; y < y1; ++y) {
                for (uint x = x0; x < x1; ++x) {
                    uint idx = y * p.width + x;
                    uchar4 px = pixels[idx];
                    float l = 0.299f * float(px.r) + 0.587f * float(px.g) + 0.114f * float(px.b);

                    tileTotal += l;
                    tileCount += 1;
                    tileMin = min(tileMin, l);
                    tileMax = max(tileMax, l);

                    if (x < midX && y < midY) {
                        topLeftEnergy += l;
                    } else if (x >= midX && y >= midY) {
                        bottomRightEnergy += l;
                    }

                    if (x < midX) {
                        leftEnergy += l;
                    } else {
                        rightEnergy += l;
                    }

                    if (y < midY) {
                        topEnergy += l;
                    } else {
                        bottomEnergy += l;
                    }
                }
            }

            float tileAverage = tileCount > 0 ? tileTotal / float(tileCount) : 0.0f;
            float rawNormalized = tileAverage - globalAverage;
            float normalized = floor(rawNormalized / 4.0f) * 4.0f;

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

            ulong contrastFlag = (tileMax - tileMin) > 36.0f ? 0x4UL : 0x0UL;

            float diagonalBias = topLeftEnergy - bottomRightEnergy;
            float horizontalBias = leftEnergy - rightEnergy;
            float verticalBias = topEnergy - bottomEnergy;
            float axialBias = fabs(horizontalBias) > fabs(verticalBias) ? horizontalBias : verticalBias;
            float dominantBias = fabs(diagonalBias) > fabs(axialBias) ? diagonalBias : axialBias;

            ulong directionFlag = dominantBias > 0.0f ? 0x8UL : 0x0UL;

            ulong nibble = (band & 0x3UL) | contrastFlag | directionFlag;
            fingerprint |= (nibble << (nibbleIndex * 4));
            nibbleIndex += 1;
        }
    }

    fingerprints[gid] = fingerprint;
}
