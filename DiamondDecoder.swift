class DiamondDecoder {

    func decode(width: Int, height: Int, dictionary: [DiamondDictionaryEntry]) -> [[Pixel]] {

        var output = Array(
            repeating: Array(repeating: Pixel(r: 0, g: 0, b: 0), count: width),
            count: height
        )

        for entry in dictionary {

            var base = entry.base

            let bitDepth = entry.residualBitDepth
            precondition(bitDepth == 5, "DiamondDecoder: only 5-bit residual mode is supported right now")

            // CPU and GPU entries now both reconstruct from the same packed residual stream.
            // These counts should match exactly; if they do not, keep decoding safely but surface it.
            if entry.deltaPositions.count != entry.residuals.count {
                assertionFailure("DiamondDecoder: delta/residual count mismatch")
            }
            let count = min(entry.deltaPositions.count, entry.residuals.count)

            var x = Int(entry.firstPosition.x)
            var y = Int(entry.firstPosition.y)

            if x >= 0, y >= 0, x < width, y < height {
                output[y][x] = Pixel(r: base.r, g: base.g, b: base.b)
            }

            for i in 0..<count {

                let (dx, dy) = entry.deltaPositions[i]
                x += Int(dx)
                y += Int(dy)

                let raw = entry.residuals[i]
                let decoded: Diamond
                switch bitDepth {
                case 5:
                    // Use the same helper as encoder wrapper for consistency
                    decoded = Diamond.applyResidual555(raw, to: base)
                default:
                    preconditionFailure("DiamondDecoder: unsupported residual bit depth \(bitDepth)")
                }

                // GPU and CPU paths share the same packed signed 5-5-5 reconstruction now.
                // Advance the rolling base only after decoding the current pixel.
                base = decoded

                if x >= 0, y >= 0, x < width, y < height {
                    output[y][x] = Pixel(r: decoded.r, g: decoded.g, b: decoded.b)
                }
            }
        }

        return output
    }
}
