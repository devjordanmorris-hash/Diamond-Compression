import AppKit

struct ThermalFingerprint {
    let value: UInt64
}

enum ThermalFingerprintBuilder {
    /// Build a 64-bit thermal fingerprint using a 4x4 tile layout.
    ///
    /// Each tile contributes one 4-bit nibble:
    /// - low 2 bits: coarse intensity band relative to the image-wide average
    /// - bit 2: local contrast flag
    /// - bit 3: dominant directional bias flag (diagonal or horizontal/vertical)
    ///
    /// This keeps the compact 64-bit footprint but adds more structural information
    /// than a plain average/contrast encoding.
    static func makeFingerprint(from image: NSImage) -> ThermalFingerprint {
        let pixels = ImageConverter.imageToPixels(image)

        guard !pixels.isEmpty, !pixels[0].isEmpty else {
            return ThermalFingerprint(value: 0)
        }

        let height = pixels.count
        let width = pixels[0].count

        var totalLuminance: Float = 0.0
        var sampleCount = 0

        for y in 0..<height {
            for x in 0..<width {
                totalLuminance += luminance(of: pixels[y][x])
                sampleCount += 1
            }
        }

        let globalAverage: Float = sampleCount > 0 ? totalLuminance / Float(sampleCount) : 0.0

        var fingerprint: UInt64 = 0
        var nibbleIndex: UInt64 = 0

        // 4x4 tiles -> 16 nibbles -> 64 bits.
        for gy in 0..<4 {
            for gx in 0..<4 {
                let x0 = gx * width / 4
                let x1 = max(x0 + 1, (gx + 1) * width / 4)
                let y0 = gy * height / 4
                let y1 = max(y0 + 1, (gy + 1) * height / 4)

                var tileTotal: Float = 0.0
                var tileCount = 0
                var tileMin = Float.greatestFiniteMagnitude
                var tileMax = -Float.greatestFiniteMagnitude
                var topLeftEnergy: Float = 0.0
                var bottomRightEnergy: Float = 0.0
                var leftEnergy: Float = 0.0
                var rightEnergy: Float = 0.0
                var topEnergy: Float = 0.0
                var bottomEnergy: Float = 0.0

                let midX = (x0 + x1) / 2
                let midY = (y0 + y1) / 2

                for y in y0..<y1 {
                    for x in x0..<x1 {
                        let l = luminance(of: pixels[y][x])
                        tileTotal += l
                        tileCount += 1
                        if l < tileMin { tileMin = l }
                        if l > tileMax { tileMax = l }

                        if x < midX && y < midY {
                            topLeftEnergy += l
                        } else if x >= midX && y >= midY {
                            bottomRightEnergy += l
                        }

                        if x < midX {
                            leftEnergy += l
                        } else {
                            rightEnergy += l
                        }

                        if y < midY {
                            topEnergy += l
                        } else {
                            bottomEnergy += l
                        }
                    }
                }

                let tileAverage: Float = tileCount > 0 ? tileTotal / Float(tileCount) : 0.0
                let rawNormalized: Float = tileAverage - globalAverage
                let normalized: Float = floor(rawNormalized / 4.0) * 4.0

                let band: UInt64
                switch normalized {
                case ..<(-32):
                    band = 0
                case ..<0:
                    band = 1
                case ..<32:
                    band = 2
                default:
                    band = 3
                }

                let contrastFlag: UInt64 = (tileMax - tileMin) > 36.0 ? 0b0100 : 0

                // Use the stronger of two simple structural cues:
                // diagonal dominance (top-left vs bottom-right) or axial dominance
                // (left/top vs right/bottom). This keeps one direction bit while making
                // the tile descriptor less forgiving for shifted hotspots and banded decoys.
                let diagonalBias = topLeftEnergy - bottomRightEnergy
                let horizontalBias = leftEnergy - rightEnergy
                let verticalBias = topEnergy - bottomEnergy
                let axialBias = abs(horizontalBias) > abs(verticalBias) ? horizontalBias : verticalBias
                let dominantBias = abs(diagonalBias) > abs(axialBias) ? diagonalBias : axialBias
                let directionFlag: UInt64 = dominantBias > 0 ? 0b1000 : 0

                let nibble = (band & 0b0011) | contrastFlag | directionFlag

                fingerprint |= (nibble << (nibbleIndex * 4))
                nibbleIndex += 1
            }
        }

        return ThermalFingerprint(value: fingerprint)
    }

    /// Higher score means a closer match.
    static func closenessScore(_ a: ThermalFingerprint, _ b: ThermalFingerprint) -> Int {
        var score = 0

        for i in 0..<16 {
            let shift = UInt64(i * 4)
            let lhs = Int((a.value >> shift) & 0xF)
            let rhs = Int((b.value >> shift) & 0xF)

            let lhsBand = lhs & 0x3
            let rhsBand = rhs & 0x3
            let lhsContrast = (lhs & 0x4) != 0
            let rhsContrast = (rhs & 0x4) != 0
            let lhsDirection = (lhs & 0x8) != 0
            let rhsDirection = (rhs & 0x8) != 0

            let bandDelta = abs(lhsBand - rhsBand)
            let bandScore = max(0, 3 - bandDelta)
            let contrastScore = (lhsContrast == rhsContrast) ? 3 : 0
            let directionScore = (lhsDirection == rhsDirection) ? 3 : 0
            score += bandScore + contrastScore + directionScore
        }

        return score
    }

    static func hexString(_ fingerprint: ThermalFingerprint) -> String {
        String(format: "%016llX", fingerprint.value)
    }

    private static func luminance(of p: Pixel) -> Float {
        0.299 * Float(p.r) + 0.587 * Float(p.g) + 0.114 * Float(p.b)
    }
}
