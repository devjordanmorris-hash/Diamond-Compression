//
//  ContentView.swift
//  daimond compression
//
//  Created by Jordan Morris  on 18/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var originalImage: NSImage? = NSImage(named: "test_8x8")
    @State private var displayedSourceImage: NSImage? = NSImage(named: "test_8x8")
    @State private var reconstructedImage: NSImage?
    @State private var compressionRate: Double = 0.0
    @State private var showDebug = false
    @State private var diamondMapImage: NSImage?
    @State private var thermalMode: Bool = false
    @State private var useGPU: Bool = false
    @State private var thermalTestImages: [NSImage] = []
    @State private var thermalMatchScores: [Int] = []
    @State private var queryFingerprintHex: String = ""
    @State private var gpuFingerprintHex: String = ""
    @State private var stagedFingerprintHex: String = ""
    @State private var speedTestSummary: String = ""
    @State private var fingerprintDebugSummary: String = ""
    
    var body: some View {
        VStack {
            Text("Diamond Codec Prototype v0.1")
                .font(.headline)
                .padding(.bottom, 10)
            
            HStack {
                if let img = displayedSourceImage {
                    VStack {
                        ZStack {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                            
                            if showDebug {
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let h = geo.size.height
                                    let step: CGFloat = 8 // grid spacing
                                    
                                    ZStack {
                                        // Border
                                        Rectangle()
                                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                        
                                        // Vertical grid lines
                                        ForEach(0..<Int(w / step), id: \.self) { i in
                                            Path { p in
                                                let x = CGFloat(i) * step
                                                p.move(to: CGPoint(x: x, y: 0))
                                                p.addLine(to: CGPoint(x: x, y: h))
                                            }
                                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                                        }
                                        
                                        // Horizontal grid lines
                                        ForEach(0..<Int(h / step), id: \.self) { j in
                                            Path { p in
                                                let y = CGFloat(j) * step
                                                p.move(to: CGPoint(x: 0, y: y))
                                                p.addLine(to: CGPoint(x: w, y: y))
                                            }
                                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                                        }
                                    }
                                }
                                .frame(width: 150, height: 150)
                            }
                        }
                        Text(thermalMode ? "Encoded Source" : "Original")
                    }
                }
                
                if let mapImg = diamondMapImage {
                    VStack {
                        ZStack {
                            Image(nsImage: mapImg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                            
                            if showDebug {
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let h = geo.size.height
                                    let step: CGFloat = 8 // grid spacing
                                    
                                    ZStack {
                                        Rectangle()
                                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                        
                                        ForEach(0..<Int(w / step), id: \.self) { i in
                                            Path { p in
                                                let x = CGFloat(i) * step
                                                p.move(to: CGPoint(x: x, y: 0))
                                                p.addLine(to: CGPoint(x: x, y: h))
                                            }
                                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                                        }
                                        
                                        ForEach(0..<Int(h / step), id: \.self) { j in
                                            Path { p in
                                                let y = CGFloat(j) * step
                                                p.move(to: CGPoint(x: 0, y: y))
                                                p.addLine(to: CGPoint(x: w, y: y))
                                            }
                                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                                        }
                                    }
                                }
                                .frame(width: 150, height: 150)
                            }
                        }
                        Text("Diamond Map")
                    }
                }
                
                if let img = reconstructedImage {
                    VStack {
                        ZStack {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                            
                            if showDebug {
                                GeometryReader { geo in
                                    let w = geo.size.width
                                    let h = geo.size.height
                                    let step: CGFloat = 8 // grid spacing
                                    
                                    ZStack {
                                        // Border
                                        Rectangle()
                                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                                        
                                        // Vertical grid lines
                                        ForEach(0..<Int(w / step), id: \.self) { i in
                                            Path { p in
                                                let x = CGFloat(i) * step
                                                p.move(to: CGPoint(x: x, y: 0))
                                                p.addLine(to: CGPoint(x: x, y: h))
                                            }
                                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                                        }
                                        
                                        // Horizontal grid lines
                                        ForEach(0..<Int(h / step), id: \.self) { j in
                                            Path { p in
                                                let y = CGFloat(j) * step
                                                p.move(to: CGPoint(x: 0, y: y))
                                                p.addLine(to: CGPoint(x: w, y: y))
                                            }
                                            .stroke(Color.red.opacity(0.3), lineWidth: 0.5)
                                        }
                                    }
                                }
                                .frame(width: 150, height: 150)
                            }
                        }
                        Text("Reconstructed")
                    }
                }
            }
            .padding()
            
            Text(String(format: "Compression Rate: %.2f%%", compressionRate))
                .padding(.top, 5)
            
            Text(useGPU ? "Mode: GPU preprocess" : "Mode: CPU only")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button("Open PNG") {
                openImage()
            }
            .padding(.top, 5)
            
            Button("Run Compression Test") {
                runTest()
            }
            .padding()
            
            Toggle("Use GPU Preprocess", isOn: $useGPU)
                .padding(.horizontal)
            
            Toggle("Show Diamond Debug Overlay", isOn: $showDebug)
                .padding(.horizontal)
            
            Toggle("Thermal Mode", isOn: $thermalMode)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("Generate Thermal Test Set") {
                    generateThermalTestSet()
                }
                
                Button("Match Thermal Test Set") {
                    matchThermalTestSet()
                }
                .disabled(thermalTestImages.isEmpty || originalImage == nil)
                
                Button("Run Speed Test") {
                    runSpeedTest()
                }
                .disabled(originalImage == nil)
                
                Button("Debug Fingerprint") {
                    debugFingerprint()
                }
                .disabled(originalImage == nil)
            }
            .padding(.top, 8)
            
            if !queryFingerprintHex.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU Query Fingerprint: \(queryFingerprintHex)")
                    if !gpuFingerprintHex.isEmpty {
                        Text("GPU Query Fingerprint: \(gpuFingerprintHex)")
                    }
                    if !stagedFingerprintHex.isEmpty {
                        Text("Staged GPU Fingerprint: \(stagedFingerprintHex)")
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            }
            
            if !speedTestSummary.isEmpty {
                Text(speedTestSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.leading)
            }
            
            if !fingerprintDebugSummary.isEmpty {
                Text(fingerprintDebugSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.leading)
            }
            
            if !thermalTestImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 12) {
                        ForEach(Array(thermalTestImages.enumerated()), id: \.offset) { index, img in
                            VStack(spacing: 6) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 80)
                                Text("Thermal \(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if index < thermalMatchScores.count {
                                    Text("Match: \(thermalMatchScores[index])")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 120)
            }
        }
    }
    
    func makeCPUTileDebug(from image: NSImage) -> [(tileAverage: Float, globalAverage: Float, rawNormalized: Float, normalized: Float, band: Int, contrast: Int, direction: Int)] {
        
        let pixels = ImageConverter.imageToPixels(image)
        guard !pixels.isEmpty, !pixels[0].isEmpty else { return [] }

        let height = pixels.count
        let width = pixels[0].count

        var totalLuminance: Float = 0.0
        var sampleCount = 0
        for y in 0..<height {
            for x in 0..<width {
                totalLuminance += cpuLuminance(of: pixels[y][x])
                sampleCount += 1
            }
        }

        let globalAverage: Float = sampleCount > 0 ? totalLuminance / Float(sampleCount) : 0.0
        var out: [(tileAverage: Float, globalAverage: Float, rawNormalized: Float, normalized: Float, band: Int, contrast: Int, direction: Int)] = []
        out.reserveCapacity(16)

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
                        let l = cpuLuminance(of: pixels[y][x])
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

                let band: Int
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

                let contrast = (tileMax - tileMin) > 36.0 ? 1 : 0
                let diagonalBias = topLeftEnergy - bottomRightEnergy
                let horizontalBias = leftEnergy - rightEnergy
                let verticalBias = topEnergy - bottomEnergy
                let axialBias = abs(horizontalBias) > abs(verticalBias) ? horizontalBias : verticalBias
                let dominantBias = abs(diagonalBias) > abs(axialBias) ? diagonalBias : axialBias
                let direction = dominantBias > 0 ? 1 : 0

                out.append((tileAverage, globalAverage, rawNormalized, normalized, band, contrast, direction))
            }
        }

        return out
    }

    func cpuLuminance(of p: Pixel) -> Float {
        0.299 * Float(p.r) + 0.587 * Float(p.g) + 0.114 * Float(p.b)
    }

    
    func runTest() {
        guard let nsImage = originalImage else { return }

        // Use the shared thermal mapper so preview and codec testing follow the same path.
        let sourceImage = thermalMode ? makeThermalImage(from: nsImage) : nsImage
        displayedSourceImage = sourceImage

        // 1. Encode → Diamond Dictionary
        let (dict, width, height) = ImageConverter.encodeToDictionary(sourceImage, useGPU: useGPU)

        // Generate diamond map
        diamondMapImage = makeSimpleDiamondMap(dict: dict, width: width, height: height)

        // 2. Compression calc + stats
        let originalSize = max(1, width * height * 3)

        let totalEntries = dict.count
        var totalDeltas = 0
        var totalResiduals = 0

        let compressedSize = dict.reduce(0) { sum, entry in
            let header = 8
            let posCount = entry.deltaPositions.count
            let resCount = entry.residuals.count

            totalDeltas += posCount
            totalResiduals += resCount

            let pos = posCount * MemoryLayout<Int16>.size * 2
            let res = resCount * MemoryLayout<UInt16>.size
            return sum + header + pos + res
        }

        compressionRate = (1 - Double(compressedSize) / Double(originalSize)) * 100

        // Debug stats
        print("---- Diamond Stats ----")
        print("Entries: \(totalEntries)")
        print("Total Deltas: \(totalDeltas)")
        print("Total Residuals: \(totalResiduals)")
        print("Avg Deltas per Entry: \(totalEntries > 0 ? totalDeltas / totalEntries : 0)")
        print("Avg Residuals per Entry: \(totalEntries > 0 ? totalResiduals / totalEntries : 0)")
        print("Original Size: \(originalSize) bytes")
        print("Estimated Compressed Size: \(compressedSize) bytes")
        print("------------------------")

        // 3. Decode
        reconstructedImage = ImageConverter.decodeFromDictionary(dict, width: width, height: height)
    }
    
    func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png]
        panel.allowsOtherFileTypes = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            if let img = NSImage(contentsOf: url) {
                originalImage = img
                displayedSourceImage = img
                reconstructedImage = nil
                diamondMapImage = nil
                thermalTestImages = []
                thermalMatchScores = []
                queryFingerprintHex = ""
                gpuFingerprintHex = ""
                stagedFingerprintHex = ""
                speedTestSummary = ""
                fingerprintDebugSummary = ""
                compressionRate = 0.0
            }
        }
    }

    func generateThermalTestSet() {
        guard let base = originalImage else { return }

        let thermal = makeThermalImage(from: base)
        let pixels = ImageConverter.imageToPixels(thermal)
        guard !pixels.isEmpty, !pixels[0].isEmpty else {
            thermalTestImages = [thermal]
            thermalMatchScores = []
            queryFingerprintHex = ""
            gpuFingerprintHex = ""
            stagedFingerprintHex = ""
            fingerprintDebugSummary = ""
            return
        }

        func remap(_ pixels: [[Pixel]], scale: Double, bias: Int) -> NSImage {
            var out = pixels
            for y in 0..<out.count {
                for x in 0..<out[y].count {
                    let p = out[y][x]
                    let r = UInt8(clamping: Int(Double(p.r) * scale) + bias)
                    let g = UInt8(clamping: Int(Double(p.g) * scale) + bias)
                    let b = UInt8(clamping: Int(Double(p.b) * scale) + bias)
                    out[y][x] = Pixel(r: r, g: g, b: b)
                }
            }
            return ImageConverter.pixelsToImage(out)
        }

        func hotspot(_ pixels: [[Pixel]], centerX: Int, centerY: Int, radius: Int, boost: Int) -> NSImage {
            var out = pixels
            let radiusSquared = radius * radius
            for y in 0..<out.count {
                for x in 0..<out[y].count {
                    let dx = x - centerX
                    let dy = y - centerY
                    if dx * dx + dy * dy <= radiusSquared {
                        let p = out[y][x]
                        out[y][x] = Pixel(
                            r: UInt8(clamping: Int(p.r) + boost),
                            g: UInt8(clamping: Int(p.g) + boost / 2),
                            b: UInt8(clamping: Int(p.b) - boost / 3)
                        )
                    }
                }
            }
            return ImageConverter.pixelsToImage(out)
        }

        func invertThermal(_ pixels: [[Pixel]]) -> NSImage {
            var out = pixels
            for y in 0..<out.count {
                for x in 0..<out[y].count {
                    let p = out[y][x]
                    out[y][x] = Pixel(
                        r: UInt8(clamping: 255 - Int(p.r)),
                        g: UInt8(clamping: 255 - Int(p.g)),
                        b: UInt8(clamping: 255 - Int(p.b))
                    )
                }
            }
            return ImageConverter.pixelsToImage(out)
        }

        func stripedThermal(width: Int, height: Int) -> NSImage {
            var out = Array(
                repeating: Array(repeating: Pixel(r: 0, g: 0, b: 0), count: width),
                count: height
            )

            for y in 0..<height {
                for x in 0..<width {
                    let stripe = ((x / max(1, width / 8)) % 2 == 0)
                    out[y][x] = stripe
                        ? Pixel(r: 245, g: 210, b: 32)
                        : Pixel(r: 18, g: 24, b: 180)
                }
            }

            return ImageConverter.pixelsToImage(out)
        }

        let width = pixels[0].count
        let height = pixels.count
        let bright = remap(pixels, scale: 1.10, bias: 8)
        let dim = remap(pixels, scale: 0.85, bias: -6)
        let hotspotA = hotspot(pixels, centerX: width / 3, centerY: height / 2, radius: max(6, min(width, height) / 8), boost: 45)
        let hotspotB = hotspot(pixels, centerX: (2 * width) / 3, centerY: height / 3, radius: max(5, min(width, height) / 10), boost: 32)
        let inverse = invertThermal(pixels)
        let stripe = stripedThermal(width: width, height: height)
        let cornerHotspot = hotspot(pixels, centerX: max(4, width / 8), centerY: max(4, height / 8), radius: max(5, min(width, height) / 9), boost: 72)

        thermalTestImages = [thermal, bright, dim, hotspotA, hotspotB, inverse, stripe, cornerHotspot]
        thermalMatchScores = []
        queryFingerprintHex = ""
        gpuFingerprintHex = ""
        stagedFingerprintHex = ""
        fingerprintDebugSummary = ""
    }

    func matchThermalTestSet() {
        guard let base = originalImage, !thermalTestImages.isEmpty else { return }

        let queryThermal = makeThermalImage(from: base)
        let queryFingerprint = ThermalFingerprintBuilder.makeFingerprint(from: queryThermal)
        queryFingerprintHex = ThermalFingerprintBuilder.hexString(queryFingerprint)

        let gpuPackedFingerprint = ThermalCompute.shared.buildFingerprint(from: queryThermal)
        gpuFingerprintHex = String(format: "%016llX", gpuPackedFingerprint)

        let stagedPackedFingerprint = ThermalCompute.shared.buildFingerprintStaged(from: queryThermal)
        stagedFingerprintHex = String(format: "%016llX", stagedPackedFingerprint)

        thermalMatchScores = thermalTestImages.map { candidate in
            let candidateFingerprint = ThermalFingerprintBuilder.makeFingerprint(from: candidate)
            return ThermalFingerprintBuilder.closenessScore(queryFingerprint, candidateFingerprint)
        }

        print("---- Thermal Bucket Match ----")
        print("Query CPU Fingerprint: \(queryFingerprintHex)")
        print("Query GPU Fingerprint: \(gpuFingerprintHex)")
        print("Query Staged GPU Fingerprint: \(stagedFingerprintHex)")
        print("---- CPU/GPU Candidate Parity ----")
        for (index, candidate) in thermalTestImages.enumerated() {
            let cpuCandidate = ThermalFingerprintBuilder.makeFingerprint(from: candidate)
            let gpuCandidate = ThermalCompute.shared.buildFingerprint(from: candidate)
            let stagedCandidate = ThermalCompute.shared.buildFingerprintStaged(from: candidate)
            let cpuHex = ThermalFingerprintBuilder.hexString(cpuCandidate)
            let gpuHex = String(format: "%016llX", gpuCandidate)
            let stagedHex = String(format: "%016llX", stagedCandidate)
            let parity = cpuCandidate.value == gpuCandidate ? "yes" : "no"
            let stagedParity = cpuCandidate.value == stagedCandidate ? "yes" : "no"
            let score = index < thermalMatchScores.count ? thermalMatchScores[index] : -1
            print("Thermal \(index + 1): score = \(score), CPU = \(cpuHex), GPU = \(gpuHex), staged = \(stagedHex), parity = \(parity), stagedParity = \(stagedParity)")
        }
        print("------------------------------")
    }

    func runSpeedTest() {
        guard let base = originalImage else { return }

        let thermalBase = makeThermalImage(from: base)
        let libraryImages = thermalTestImages.isEmpty ? [thermalBase] : thermalTestImages
        let iterations = 100

        let cpuFingerprintStart = CFAbsoluteTimeGetCurrent()
        var lastCPUFingerprint = ThermalFingerprintBuilder.makeFingerprint(from: thermalBase)
        for _ in 0..<iterations {
            lastCPUFingerprint = ThermalFingerprintBuilder.makeFingerprint(from: thermalBase)
        }
        let cpuFingerprintElapsed = CFAbsoluteTimeGetCurrent() - cpuFingerprintStart

        let gpuFingerprintStart = CFAbsoluteTimeGetCurrent()
        var lastGPUFingerprint: UInt64 = 0
        for _ in 0..<iterations {
            lastGPUFingerprint = ThermalCompute.shared.buildFingerprint(from: thermalBase)
        }
        let gpuFingerprintElapsed = CFAbsoluteTimeGetCurrent() - gpuFingerprintStart

        let stagedFingerprintStart = CFAbsoluteTimeGetCurrent()
        var lastStagedFingerprint: UInt64 = 0
        for _ in 0..<iterations {
            lastStagedFingerprint = ThermalCompute.shared.buildFingerprintStaged(from: thermalBase)
        }
        let stagedFingerprintElapsed = CFAbsoluteTimeGetCurrent() - stagedFingerprintStart

        let libraryStart = CFAbsoluteTimeGetCurrent()
        var libraryFingerprints: [ThermalFingerprint] = []
        libraryFingerprints.reserveCapacity(libraryImages.count * iterations)
        for _ in 0..<iterations {
            for image in libraryImages {
                libraryFingerprints.append(ThermalFingerprintBuilder.makeFingerprint(from: image))
            }
        }
        let libraryElapsed = CFAbsoluteTimeGetCurrent() - libraryStart

        let onePassLibrary = Array(libraryFingerprints.prefix(libraryImages.count))
        let matchStart = CFAbsoluteTimeGetCurrent()
        var bestScore = Int.min
        var bestIndex = 0
        for _ in 0..<iterations {
            for (index, candidate) in onePassLibrary.enumerated() {
                let score = ThermalFingerprintBuilder.closenessScore(lastCPUFingerprint, candidate)
                if score > bestScore {
                    bestScore = score
                    bestIndex = index
                }
            }
        }
        let matchElapsed = CFAbsoluteTimeGetCurrent() - matchStart

        let cpuFingerprintPerRunMs = (cpuFingerprintElapsed / Double(iterations)) * 1000.0
        let gpuFingerprintPerRunMs = (gpuFingerprintElapsed / Double(iterations)) * 1000.0
        let stagedFingerprintPerRunMs = (stagedFingerprintElapsed / Double(iterations)) * 1000.0
        let libraryPerImageMs = (libraryElapsed / Double(max(1, libraryImages.count * iterations))) * 1000.0
        let matchPerLibraryPassMs = (matchElapsed / Double(iterations)) * 1000.0
        let packedParity = (lastCPUFingerprint.value == lastGPUFingerprint)
        let stagedParity = (lastCPUFingerprint.value == lastStagedFingerprint)
        let searchingSameQuery = (queryFingerprintHex.isEmpty || queryFingerprintHex == ThermalFingerprintBuilder.hexString(lastCPUFingerprint))

        queryFingerprintHex = ThermalFingerprintBuilder.hexString(lastCPUFingerprint)
        gpuFingerprintHex = String(format: "%016llX", lastGPUFingerprint)
        stagedFingerprintHex = String(format: "%016llX", lastStagedFingerprint)

        speedTestSummary = String(
            format:
                "Speed Test\nCPU Fingerprint: %.3f ms/query\nGPU Fingerprint: %.3f ms/query\nStaged GPU Fingerprint: %.3f ms/query\nPacked Parity: %@\nStaged Parity: %@\nSearching Same Query: %@\nLibrary Build: %.3f ms/image\nCPU Match Pass (%d imgs): %.3f ms\nBest Match Index: %d\nBest Score: %d",
            cpuFingerprintPerRunMs,
            gpuFingerprintPerRunMs,
            stagedFingerprintPerRunMs,
            packedParity ? "yes" : "no",
            stagedParity ? "yes" : "no",
            searchingSameQuery ? "yes" : "no",
            libraryPerImageMs,
            libraryImages.count,
            matchPerLibraryPassMs,
            bestIndex + 1,
            bestScore
        )

        print("---- Thermal Speed Test ----")
        print(speedTestSummary)
        print("----------------------------")
    }



    /// Converts any NSImage into a pseudo-thermal "ironbow" style heatmap.
    func makeThermalImage(from image: NSImage) -> NSImage {
        let mappedPixels = ThermalMapper.colorizeThermal(image)
        guard !mappedPixels.isEmpty, !mappedPixels[0].isEmpty else {
            return image
        }
        return ImageConverter.pixelsToImage(mappedPixels)
    }

    /// Ironbow LUT (blue→purple→red→yellow→white)
    func thermalLUT(_ v: Float) -> (UInt8, UInt8, UInt8) {
        // Legacy local LUT retained temporarily for compatibility while the shared
        // ThermalMapper is the active path used by runTest().
        let x = max(0, min(1, v))

        if x < 0.25 {
            let t = x / 0.25
            return (0, 0, UInt8(t * 255))
        } else if x < 0.50 {
            let t = (x - 0.25) / 0.25
            return (UInt8(t * 255), 0, 255)
        } else if x < 0.75 {
            let t = (x - 0.50) / 0.25
            return (255, 0, UInt8((1 - t) * 255))
        } else {
            let t = (x - 0.75) / 0.25
            return (255, UInt8(t * 255), 0)
        }
    }

    func rgbToNSImage(width: Int, height: Int, rgb: [UInt8]) -> NSImage {
        let bpr = width * 3
        let cf = CFDataCreate(nil, rgb, rgb.count)!
        let provider = CGDataProvider(data: cf)!

        let cg = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bpr,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }

    func makeSimpleDiamondMap(dict: [DiamondDictionaryEntry], width: Int, height: Int) -> NSImage? {

        let img = NSImage(size: NSSize(width: width, height: height))
        img.lockFocus()
        defer { img.unlockFocus() }

        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        var colorCache: [UInt8: NSColor] = [:]

        for entry in dict {
            let bucket = entry.bucketID

            if colorCache[bucket] == nil {
                let r = CGFloat((Int(bucket) * 97) % 255) / 255.0
                let g = CGFloat((Int(bucket) * 53) % 255) / 255.0
                let b = CGFloat((Int(bucket) * 199) % 255) / 255.0
                colorCache[bucket] = NSColor(red: r, green: g, blue: b, alpha: 1)
            }

            guard let color = colorCache[bucket] else { continue }

            var x = Int(entry.firstPosition.x)
            var y = Int(entry.firstPosition.y)

            if x >= 0, y >= 0, x < width, y < height {
                color.setFill()
                NSRect(x: x, y: height - 1 - y, width: 1, height: 1).fill()
            }

            for (dx, dy) in entry.deltaPositions {
                x += Int(dx)
                y += Int(dy)

                if x >= 0, y >= 0, x < width, y < height {
                    color.setFill()
                    NSRect(x: x, y: height - 1 - y, width: 1, height: 1).fill()
                }
            }
        }

        return img
    }
    func debugFingerprint() {
        guard let base = originalImage else { return }

        let queryThermal = makeThermalImage(from: base)
        let cpu = ThermalFingerprintBuilder.makeFingerprint(from: queryThermal)
        let gpu = ThermalCompute.shared.buildFingerprint(from: queryThermal)
        let staged = ThermalCompute.shared.buildFingerprintStaged(from: queryThermal)

        queryFingerprintHex = ThermalFingerprintBuilder.hexString(cpu)
        gpuFingerprintHex = String(format: "%016llX", gpu)
        stagedFingerprintHex = String(format: "%016llX", staged)

        var lines: [String] = []
        lines.append("Fingerprint Debug")
        lines.append("CPU: \(queryFingerprintHex)")
        lines.append("GPU: \(gpuFingerprintHex)")
        lines.append("Staged GPU: \(stagedFingerprintHex)")
        lines.append("Packed parity: \(cpu.value == gpu ? "yes" : "no")")
        lines.append("Staged parity: \(cpu.value == staged ? "yes" : "no")")
        lines.append("Tile nibbles:")
        let cpuTileDebug = makeCPUTileDebug(from: queryThermal)

        for i in 0..<16 {
            let shift = UInt64(i * 4)
            let cpuNibble = Int((cpu.value >> shift) & 0xF)
            let gpuNibble = Int((gpu >> shift) & 0xF)
            let stagedNibble = Int((staged >> shift) & 0xF)
            let cpuBand = cpuNibble & 0x3
            let gpuBand = gpuNibble & 0x3
            let stagedBand = stagedNibble & 0x3
            let cpuContrast = (cpuNibble & 0x4) != 0 ? 1 : 0
            let gpuContrast = (gpuNibble & 0x4) != 0 ? 1 : 0
            let stagedContrast = (stagedNibble & 0x4) != 0 ? 1 : 0
            let cpuDirection = (cpuNibble & 0x8) != 0 ? 1 : 0
            let gpuDirection = (gpuNibble & 0x8) != 0 ? 1 : 0
            let stagedDirection = (stagedNibble & 0x8) != 0 ? 1 : 0
            let parity = cpuNibble == gpuNibble ? "yes" : "no"
            let stagedParity = cpuNibble == stagedNibble ? "yes" : "no"

            let extra: String
            if i < cpuTileDebug.count {
                let t = cpuTileDebug[i]
                extra = String(
                    format: " avg %.2f glob %.2f raw %.2f norm %.2f",
                    t.tileAverage,
                    t.globalAverage,
                    t.rawNormalized,
                    t.normalized
                )
            } else {
                extra = ""
            }

            let line = String(
                format: "T%02d  CPU:%X  GPU:%X  ST:%X  band %d/%d/%d  c %d/%d/%d  d %d/%d/%d",
                i,
                cpuNibble,
                gpuNibble,
                stagedNibble,
                cpuBand,
                gpuBand,
                stagedBand,
                cpuContrast,
                gpuContrast,
                stagedContrast,
                cpuDirection,
                gpuDirection,
                stagedDirection
            )
            lines.append(line + "  parity " + parity + "  staged " + stagedParity + extra)
        }

        fingerprintDebugSummary = lines.joined(separator: "\n")

        print("---- Fingerprint Debug ----")
        print(fingerprintDebugSummary)
        print("---------------------------")
    }
}

#Preview {
    ContentView()
}
