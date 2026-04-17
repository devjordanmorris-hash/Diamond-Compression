class DiamondMerger {

    func merge(_ entries: [DiamondDictionaryEntry]) -> [DiamondDictionaryEntry] {

        var used = Array(repeating: false, count: entries.count)
        var result: [DiamondDictionaryEntry] = []

        for i in 0..<entries.count {
            if used[i] { continue }

            // Start merged result with entry[i]
            var baseEntry = entries[i]
            used[i] = true

            // Helper: reconstruct absolute pixel list (positions + Diamond colours)
            func reconstructPixels(_ e: DiamondDictionaryEntry) -> [(pos: PositionMap.Pos, pix: Diamond)] {
                var out: [(PositionMap.Pos, Diamond)] = []

                var curPos = e.firstPosition
                var curBase = e.base
                out.append((curPos, curBase))

                for (index, d) in e.deltaPositions.enumerated() {
                    let nx = UInt16(Int(curPos.x) + Int(d.dx))
                    let ny = UInt16(Int(curPos.y) + Int(d.dy))
                    curPos = PositionMap.Pos(x: nx, y: ny)

                    // residual
                    let packed = Int16(bitPattern: e.residuals[index])
                    let decoded = Diamond.applyResidual555_signed(packed, to: curBase)
                    curBase = decoded
                    out.append((curPos, decoded))
                }
                return out
            }

            // Reconstruct pixels for the base entry
            var combined = reconstructPixels(baseEntry)

            // Try to absorb all compatible entries
            for j in (i + 1)..<entries.count {
                if used[j] { continue }

                let other = entries[j]

                guard baseEntry.bucketID == other.bucketID else { continue }
                guard baseEntry.base.rgbValue() == other.base.rgbValue() else { continue }

                // Reconstruct, append
                let otherPixels = reconstructPixels(other)
                combined.append(contentsOf: otherPixels)
                used[j] = true
            }

            // Re-sort combined pixel chain for stable ordering
            combined.sort {
                if $0.pos.y == $1.pos.y { return $0.pos.x < $1.pos.x }
                return $0.pos.y < $1.pos.y
            }

            // Now rebuild deltaPositions + residuals using rolling base
            if combined.isEmpty {
                result.append(baseEntry)
                continue
            }

            let newFirst = combined[0].pos
            var newDeltas: [(Int16, Int16)] = []
            var newResiduals: [UInt16] = []

            var lastPos = newFirst
            var rollingBase = baseEntry.base  // same canonical base

            for idx in 1..<combined.count {
                let (pos, pix) = combined[idx]

                // delta
                let deltaX = Int(pos.x) - Int(lastPos.x)
                let deltaY = Int(pos.y) - Int(lastPos.y)

                precondition(deltaX >= Int(Int16.min) && deltaX <= Int(Int16.max),
                             "DiamondMerger: dx out of Int16 range")
                precondition(deltaY >= Int(Int16.min) && deltaY <= Int(Int16.max),
                             "DiamondMerger: dy out of Int16 range")

                let dx = Int16(deltaX)
                let dy = Int16(deltaY)
                newDeltas.append((dx, dy))
                lastPos = pos

                // residual
                let signed = pix.residual555_signed(from: rollingBase)
                let unsigned = UInt16(bitPattern: signed)
                newResiduals.append(unsigned)

                // update rolling base
                rollingBase = Diamond.applyResidual555(unsigned, to: rollingBase)
            }

            baseEntry.firstPosition = newFirst
            baseEntry.deltaPositions = newDeltas
            baseEntry.residuals = newResiduals

            result.append(baseEntry)
        }

        return result
    }
}
