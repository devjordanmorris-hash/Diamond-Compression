import AppKit

class ImageLoader {
    static func loadPixels(from image: NSImage) -> [[Pixel]] {
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        
        var pixels = Array(
            repeating: Array(repeating: Pixel(r: 0, g: 0, b: 0), count: width),
            count: height
        )
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
        
        context?.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context?.data else { return pixels }
        let data = buffer.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var offset = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                pixels[y][x] = Pixel(r: r, g: g, b: b)
                offset += 4
            }
        }
        
        return pixels
    }
}
