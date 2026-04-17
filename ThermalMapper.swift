import Foundation
import CoreGraphics
import AppKit

/// Simple thermal → colour LUT using “Ironbow”
class ThermalMapper {

    static func colorizeThermal(_ image: NSImage) -> [[Pixel]] {

        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let width = cg.width
        let height = cg.height

        var out = Array(
            repeating: Array(repeating: Pixel(r: 0, g: 0, b: 0), count: width),
            count: height
        )

        guard let data = cg.dataProvider?.data else { return out }
        let ptr = CFDataGetBytePtr(data)!

        // First pass: measure dynamic range so the thermal ramp uses the full palette.
        var minGrey = 255
        var maxGrey = 0
        for y in 0..<height {
            for x in 0..<width {
                let offset = ((y * width) + x) * 4
                let grey = Int(ptr[offset])
                if grey < minGrey { minGrey = grey }
                if grey > maxGrey { maxGrey = grey }
            }
        }

        let range = max(1, maxGrey - minGrey)

        @inline(__always)
        func remap(_ grey: Int) -> Double {
            let normalized = Double(grey - minGrey) / Double(range)
            return min(1.0, max(0.0, normalized))
        }

        @inline(__always)
        func lerp(_ a: Double, _ b: Double, _ t: Double) -> UInt8 {
            UInt8(clamping: Int((a + (b - a) * t).rounded()))
        }

        for y in 0..<height {
            for x in 0..<width {

                let offset = ((y * width) + x) * 4
                let grey = Int(ptr[offset])
                let t = remap(grey)

                // Compression-friendly monotonic thermal ramp.
                // Piecewise interpolation keeps neighbouring temperatures close in RGB space,
                // which helps bucketisation and residual coding behave more smoothly.
                let r: UInt8
                let g: UInt8
                let b: UInt8

                switch t {
                case 0.0..<0.25:
                    let u = t / 0.25
                    r = lerp(0, 32, u)
                    g = lerp(0, 0, u)
                    b = lerp(0, 160, u)
                case 0.25..<0.5:
                    let u = (t - 0.25) / 0.25
                    r = lerp(32, 180, u)
                    g = lerp(0, 32, u)
                    b = lerp(160, 255, u)
                case 0.5..<0.75:
                    let u = (t - 0.5) / 0.25
                    r = lerp(180, 255, u)
                    g = lerp(32, 160, u)
                    b = lerp(255, 64, u)
                default:
                    let u = (t - 0.75) / 0.25
                    r = lerp(255, 255, u)
                    g = lerp(160, 255, u)
                    b = lerp(64, 0, u)
                }

                out[y][x] = Pixel(r: r, g: g, b: b)
            }
        }

        return out
    }
}
