import Foundation

/// Diamond represents a pixel in the Diamond codec pipeline.
/// It stores RGB and optional pattern/shape metadata (unused for now).
struct Diamond {

    var r: UInt8
    var g: UInt8
    var b: UInt8

    // (Unused; kept for future expansions such as shape/rotation classification.)
    var shape: UInt8 = 0
    var orient: UInt8 = 0

    // ------------------------------------------------------------
    // MARK: - Initialisers
    // ------------------------------------------------------------

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    static func fromRGB(_ value: UInt32) -> Diamond {
        let r = UInt8((value >> 16) & 0xFF)
        let g = UInt8((value >> 8) & 0xFF)
        let b = UInt8(value & 0xFF)
        return Diamond(r: r, g: g, b: b)
    }

    func rgbValue() -> UInt32 {
        (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b)
    }

    // ------------------------------------------------------------
    // MARK: - Properties
    // ------------------------------------------------------------

    /// Coarse colour bucket used for grouping similar colours.
    var bucketID: UInt8 {
        let br = r >> 6
        let bg = g >> 6
        let bb = b >> 6
        return (br << 4) | (bg << 2) | bb
    }

    /// Fast grey detection (ultra-low contrast)
    func isGrey() -> Bool {
        let drg = abs(Int(r) - Int(g))
        let dgb = abs(Int(g) - Int(b))
        let drb = abs(Int(r) - Int(b))
        return drg < 6 && dgb < 6 && drb < 6
    }

    func canonicalBase() -> UInt32 {
        rgbValue()
    }

    // ------------------------------------------------------------
    // MARK: - Signed 5-5-5 residual encoding
    // ------------------------------------------------------------

    /// Create *signed* 5-bit residuals for ΔR, ΔG, ΔB relative to a base diamond.
    /// Result: 15 bits packed as | r5 | g5 | b5 |
    func residual555_signed(from base: Diamond) -> Int16 {

        // Δ per channel
        let dr = Int(self.r) - Int(base.r)
        let dg = Int(self.g) - Int(base.g)
        let db = Int(self.b) - Int(base.b)

        // Convert to signed 5-bit range (divide by 8)
        var r5 = dr >> 3
        var g5 = dg >> 3
        var b5 = db >> 3

        // Clamp to [-16, +15]
        r5 = max(-16, min(15, r5))
        g5 = max(-16, min(15, g5))
        b5 = max(-16, min(15, b5))

        // Convert to 5-bit two's complement (lower 5 bits)
        let ur5 = Int16(r5 & 0x1F)
        let ug5 = Int16(g5 & 0x1F)
        let ub5 = Int16(b5 & 0x1F)

        return (ur5 << 10) | (ug5 << 5) | ub5
    }

    // ------------------------------------------------------------
    // MARK: - Residual application (decoder side)
    // ------------------------------------------------------------

    /// Apply a **signed** 5-bit per-channel residual to a base.
    /// Input must already be sign-correct (Int16).
    static func applyResidual555_signed(_ res: Int16, to base: Diamond) -> Diamond {

        let r5 = Int((res >> 10) & 0x1F)
        let g5 = Int((res >> 5)  & 0x1F)
        let b5 = Int(res & 0x1F)

        @inline(__always)
        func signExtend5(_ value: Int) -> Int {
            (value & 0x10) != 0 ? (value - 0x20) : value
        }

        let dr = signExtend5(r5)
        let dg = signExtend5(g5)
        let db = signExtend5(b5)

        let finalR = UInt8(clamping: Int(base.r) + (dr << 3))
        let finalG = UInt8(clamping: Int(base.g) + (dg << 3))
        let finalB = UInt8(clamping: Int(base.b) + (db << 3))

        return Diamond(r: finalR, g: finalG, b: finalB)
    }

    /// Decoder helper — accepts **UInt16** and internally sign-extends.
    static func applyResidual555(_ res: UInt16, to base: Diamond) -> Diamond {
        let signed = Int16(bitPattern: res)
        return applyResidual555_signed(signed, to: base)
    }

    /// GPU‑mode residual applier — r5, g5, b5 already sign‑extended Int8 values
    static func applyResidualRGB(r5: Int8, g5: Int8, b5: Int8, to base: Diamond) -> Diamond {
        let dr = Int(r5) << 3
        let dg = Int(g5) << 3
        let db = Int(b5) << 3

        let finalR = UInt8(clamping: Int(base.r) + dr)
        let finalG = UInt8(clamping: Int(base.g) + dg)
        let finalB = UInt8(clamping: Int(base.b) + db)

        return Diamond(r: finalR, g: finalG, b: finalB)
    }
}
