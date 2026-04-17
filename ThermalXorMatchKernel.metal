#include <metal_stdlib>
using namespace metal;

struct ThermalMatchParams {
    uint queryCount;
    uint libraryCount;
};

struct ThermalMatchResult {
    uint bestIndex;
    uint bestScore;
};

kernel void thermalXorMatchKernel(
    const device ulong *queryFingerprints     [[buffer(0)]],
    const device ulong *libraryFingerprints   [[buffer(1)]],
    device ThermalMatchResult *results        [[buffer(2)]],
    constant ThermalMatchParams &params       [[buffer(3)]],
    uint gid                                  [[thread_position_in_grid]]
) {
    if (gid >= params.queryCount) return;
    if (params.libraryCount == 0) return;

    ulong query = queryFingerprints[gid];

    uint bestIndex = 0;
    uint bestScore = 0;

    for (uint i = 0; i < params.libraryCount; ++i) {
        ulong lib = libraryFingerprints[i];
        uint score = 0;

        // 16 nibbles packed into one 64-bit fingerprint.
        // Low 2 bits are the intensity band, bit 2 is the contrast flag,
        // and bit 3 is the dominant directional bias flag.
        for (uint n = 0; n < 16; ++n) {
            uint shift = n * 4;

            uint a = uint((query >> shift) & 0xFUL);
            uint b = uint((lib >> shift) & 0xFUL);

            uint bandA = a & 0x3;
            uint bandB = b & 0x3;

            bool contrastA = (a & 0x4) != 0;
            bool contrastB = (b & 0x4) != 0;
            bool directionA = (a & 0x8) != 0;
            bool directionB = (b & 0x8) != 0;

            uint bandDelta = uint(abs(int(bandA) - int(bandB)));
            uint bandScore = (bandDelta < 3) ? (3 - bandDelta) : 0;
            uint contrastScore = (contrastA == contrastB) ? 3 : 0;
            uint directionScore = (directionA == directionB) ? 3 : 0;

            score += bandScore + contrastScore + directionScore;
        }

        if (score > bestScore) {
            bestScore = score;
            bestIndex = i;
        }
    }

    results[gid].bestIndex = bestIndex;
    results[gid].bestScore = bestScore;
}
