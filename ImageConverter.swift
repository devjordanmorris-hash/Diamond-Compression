import AppKit

class ImageConverter {

    static func imageToPixels(_ image: NSImage) -> [[Pixel]] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        let width = cgImage.width
        let height = cgImage.height

        var pixels = Array(
            repeating: Array(repeating: Pixel(r: 0, g: 0, b: 0), count: width),
            count: height
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var rawData = [UInt8](repeating: 0, count: Int(bytesPerRow * height))
        rawData.withUnsafeMutableBytes { ptr in
            if let context = CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }

        var offset = 0
        for y in 0..<height {
            for x in 0..<width {
                let r = rawData[offset]
                let g = rawData[offset + 1]
                let b = rawData[offset + 2]
                pixels[y][x] = Pixel(r: r, g: g, b: b)
                offset += 4
            }
        }

        return pixels
    }

    static func encodeToDictionary(
        _ image: NSImage,
        useGPU: Bool = false
    ) -> (dict: [DiamondDictionaryEntry], width: Int, height: Int) {
        let pixels = imageToPixels(image)
        if pixels.isEmpty { return ([], 0, 0) }

        let height = pixels.count
        let width = pixels[0].count

        let encoder = DiamondEncoder()
        encoder.useGPU = useGPU
        let dict = encoder.encode(pixels: pixels)

        return (dict, width, height)
    }

    static func decodeFromDictionary(_ dict: [DiamondDictionaryEntry], width: Int, height: Int) -> NSImage {
        let decoder = DiamondDecoder()
        let pixels = decoder.decode(width: width, height: height, dictionary: dict)
        return pixelsToImage(pixels)
    }

    static func pixelsToImage(_ pixels: [[Pixel]]) -> NSImage {
        guard !pixels.isEmpty, !pixels[0].isEmpty else {
            return NSImage(size: .zero)
        }
        let width = pixels[0].count
        let height = pixels.count

        var data = [UInt8](repeating: 0, count: width * height * 4)
        var offset = 0

        for y in 0..<height {
            for x in 0..<width {
                let p = pixels[y][x]
                data[offset]     = p.r
                data[offset + 1] = p.g
                data[offset + 2] = p.b
                data[offset + 3] = 255
                offset += 4
            }
        }

        let cfData = CFDataCreate(nil, data, data.count)!
        let provider = CGDataProvider(data: cfData)!

        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }

    static func generateDiamondMap(
        _ dict: [DiamondDictionaryEntry],
        width: Int,
        height: Int
    ) -> NSImage? {

        let img = NSImage(size: NSSize(width: width, height: height))
        img.lockFocus()
        defer { img.unlockFocus() }

        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        var colorCache: [Int: NSColor] = [:]

        for (i, entry) in dict.enumerated() {

            if colorCache[i] == nil {
                let r = CGFloat((i * 97) % 255) / 255.0
                let g = CGFloat((i * 53) % 255) / 255.0
                let b = CGFloat((i * 199) % 255) / 255.0
                colorCache[i] = NSColor(red: r, green: g, blue: b, alpha: 1)
            }

            guard let color = colorCache[i] else { continue }

            let baseX = Int(entry.firstPosition.x)
            let baseY = Int(entry.firstPosition.y)

            // Emit first pixel
            color.setFill()
            NSRect(
                x: baseX,
                y: height - 1 - baseY,
                width: 1,
                height: 1
            ).fill()

            // Emit all delta-derived positions
            var curX = baseX
            var curY = baseY

            for d in entry.deltaPositions {
                curX += Int(d.dx)
                curY += Int(d.dy)

                color.setFill()
                NSRect(
                    x: curX,
                    y: height - 1 - curY,
                    width: 1,
                    height: 1
                ).fill()
            }
        }

        return img
    }

    static func generateThermal(_ image: NSImage) -> NSImage {
        let mapped = ThermalMapper.colorizeThermal(image)
        guard !mapped.isEmpty, !mapped[0].isEmpty else { return image }
        return pixelsToImage(mapped)
    }
}
