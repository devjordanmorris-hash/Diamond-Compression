class DiamondEncoder {

    var useGPU: Bool = true
    var residualBitDepth: UInt8 = 5

    func encode(pixels: [[Pixel]]) -> [DiamondDictionaryEntry] {

        let height = pixels.count
        let width = pixels[0].count

        precondition(residualBitDepth == 5, "DiamondEncoder: only 5-bit residual mode is wired through encode/decode right now")

        var gpuData: [DiamondMetal.GPUOutput]? = nil

        if useGPU {
            let baseRGB: UInt32 = 0x808080
            gpuData = DiamondMetal.shared.processPixels(
                pixels,
                baseRGB: baseRGB
            )
        }

        // bucketise
        var buckets: [UInt8: [(Diamond, PositionMap.Pos, Int)]] = [:]
        var flatIndex = 0

        for y in 0..<height {
            for x in 0..<width {
                let p = pixels[y][x]
                let d = Diamond(r: p.r, g: p.g, b: p.b)
                let pos = PositionMap.Pos(x: UInt16(x), y: UInt16(y))
                buckets[d.bucketID, default: []].append((d, pos, flatIndex))
                flatIndex += 1
            }
        }

        var dict: [DiamondDictionaryEntry] = []

        for (bucketID, items) in buckets.sorted(by: { $0.key < $1.key }) {

            let sorted = items.sorted {
                $0.1.y == $1.1.y ? $0.1.x < $1.1.x : $0.1.y < $1.1.y
            }

            // For correct delta-chain reconstruction we need one rolling residual stream
            // relative to the evolving base, not absolute residuals relative to a fixed
            // neutral colour. Use the best per-bucket base for now in both CPU and GPU modes.
            let base0 = selectBestBase(sorted.map { $0.0 })

            var entry = DiamondDictionaryEntry(
                base: base0,
                bucketID: bucketID,
                firstPosition: sorted[0].1
            )

            entry.residualBitDepth = residualBitDepth

            // Shared decode path currently expects one packed rolling residual stream.
            // Keep GPU preprocessing available, but do not mark entries as using a
            // distinct GPU residual format.
            entry.usesGPUResiduals = false

            var lastX = sorted[0].1.x
            var lastY = sorted[0].1.y

            var rollingBase = base0

            for i in 0..<sorted.count {
                let (diamond, pos, _) = sorted[i]

                if i > 0 {

                    let deltaX = Int(pos.x) - Int(lastX)
                    let deltaY = Int(pos.y) - Int(lastY)

                    precondition(deltaX >= Int(Int16.min) && deltaX <= Int(Int16.max),
                                 "DiamondEncoder: dx out of Int16 range")
                    precondition(deltaY >= Int(Int16.min) && deltaY <= Int(Int16.max),
                                 "DiamondEncoder: dy out of Int16 range")

                    let dx = Int16(deltaX)
                    let dy = Int16(deltaY)
                    entry.deltaPositions.append((dx, dy))

                    lastX = pos.x
                    lastY = pos.y

                    // Build one shared rolling residual stream for both CPU and GPU modes.
                    // The current Metal preprocess pass produces per-pixel residuals against
                    // a fixed neutral base, which is not compatible with this delta-chain
                    // reconstruction. Recompute the packed residual from the current rolling
                    // base until the GPU path is upgraded to emit chain-compatible residuals.
                    let raw = packResidual(diamond, from: rollingBase, bitDepth: residualBitDepth)
                    entry.residuals.append(raw)
                    rollingBase = Diamond.applyResidual555(raw, to: rollingBase)
                }
            }

            dict.append(entry)
        }

        return dict
    }
    private func packResidual(_ diamond: Diamond, from base: Diamond, bitDepth: UInt8) -> UInt16 {
        switch bitDepth {
        case 5:
            let packed = diamond.residual555_signed(from: base)
            return UInt16(bitPattern: packed)
        default:
            preconditionFailure("DiamondEncoder: unsupported residual bit depth \(bitDepth)")
        }
    }

    private func selectBestBase(_ values: [Diamond]) -> Diamond {
        guard !values.isEmpty else {
            return Diamond(r: 128, g: 128, b: 128)
        }

        var sumR = 0
        var sumG = 0
        var sumB = 0

        for value in values {
            sumR += Int(value.r)
            sumG += Int(value.g)
            sumB += Int(value.b)
        }

        let count = max(1, values.count)
        return Diamond(
            r: UInt8(clamping: sumR / count),
            g: UInt8(clamping: sumG / count),
            b: UInt8(clamping: sumB / count)
        )
    }
}
