import AppKit

/// Stand-alone renderer for visualising Diamond dictionary entries.
/// Shows clusters by bucket colour, and residual heat overlays.
struct DiamondMapRenderer {

    static func renderMap(
        width: Int,
        height: Int,
        dict: [DiamondDictionaryEntry]
    ) -> NSImage {

        let img = NSImage(size: NSSize(width: width, height: height))
        img.lockFocus()
        defer { img.unlockFocus() }

        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        // -------------------------------------------------------------
        // Deterministic colour per bucket (not per entry)
        // -------------------------------------------------------------
        func bucketColour(_ bucket: UInt8) -> NSColor {
            let r = CGFloat((UInt32(bucket) * 97) % 255) / 255.0
            let g = CGFloat((UInt32(bucket) * 53) % 255) / 255.0
            let b = CGFloat((UInt32(bucket) * 199) % 255) / 255.0
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
        }

        @inline(__always)
        func fillPixel(x: Int, y: Int) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            NSRect(
                x: x,
                y: height - 1 - y,
                width: 1,
                height: 1
            ).fill()
        }

        // -------------------------------------------------------------
        // DRAW EACH ENTRY
        // -------------------------------------------------------------
        for entry in dict {
            let col = bucketColour(entry.bucketID)
            col.setFill()

            var x = Int(entry.firstPosition.x)
            var y = Int(entry.firstPosition.y)

            // Draw the first/base pixel as well as the delta-derived chain.
            fillPixel(x: x, y: y)

            for (dx, dy) in entry.deltaPositions {
                x += Int(dx)
                y += Int(dy)
                fillPixel(x: x, y: y)
            }
        }

        return img
    }
}
