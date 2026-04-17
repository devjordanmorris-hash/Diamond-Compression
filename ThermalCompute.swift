import Metal
import AppKit

class ThermalCompute {

    static let shared = ThermalCompute()

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let matchPipeline: MTLComputePipelineState
    private let fingerprintPipeline: MTLComputePipelineState
    private let globalReducePipeline: MTLComputePipelineState
    private let tileStatsPipeline: MTLComputePipelineState
    private let fingerprintPackPipeline: MTLComputePipelineState

    private init() {
        device = MTLCreateSystemDefaultDevice()!
        queue = device.makeCommandQueue()!

        let library = try! device.makeDefaultLibrary(bundle: .main)

        let matchFunction = library.makeFunction(name: "thermalXorMatchKernel")!
        matchPipeline = try! device.makeComputePipelineState(function: matchFunction)

        let fingerprintFunction = library.makeFunction(name: "thermalFingerprintKernel")!
        fingerprintPipeline = try! device.makeComputePipelineState(function: fingerprintFunction)

        let globalReduceFunction = library.makeFunction(name: "thermalGlobalReduceKernel")!
        globalReducePipeline = try! device.makeComputePipelineState(function: globalReduceFunction)

        let tileStatsFunction = library.makeFunction(name: "thermalTileStatsKernel")!
        tileStatsPipeline = try! device.makeComputePipelineState(function: tileStatsFunction)

        let fingerprintPackFunction = library.makeFunction(name: "thermalFingerprintPackKernel")!
        fingerprintPackPipeline = try! device.makeComputePipelineState(function: fingerprintPackFunction)
    }

    struct Params {
        var queryCount: UInt32
        var libraryCount: UInt32
    }

    struct Result {
        var bestIndex: UInt32
        var bestScore: UInt32
    }

    struct FingerprintParams {
        var width: UInt32
        var height: UInt32
    }

    struct RGBA8 {
        var r: UInt8
        var g: UInt8
        var b: UInt8
        var a: UInt8
    }

    struct GlobalReduceParams {
        var width: UInt32
        var height: UInt32
        var totalPixels: UInt32
        var groupCount: UInt32
    }

    struct TileStatsParams {
        var width: UInt32
        var height: UInt32
    }

    struct FingerprintPackParams {
        var globalAverage: Float
    }

    struct ThermalTileStats {
        var tileTotal: Float
        var tileMin: Float
        var tileMax: Float
        var topLeftEnergy: Float
        var bottomRightEnergy: Float
        var leftEnergy: Float
        var rightEnergy: Float
        var topEnergy: Float
        var bottomEnergy: Float
        var tileCount: UInt32
    }

    func match(
        query: [UInt64],
        library: [UInt64]
    ) -> [Result] {

        let queryCount = query.count
        let libraryCount = library.count

        var params = Params(
            queryCount: UInt32(queryCount),
            libraryCount: UInt32(libraryCount)
        )

        let queryBuffer = device.makeBuffer(
            bytes: query,
            length: MemoryLayout<UInt64>.size * queryCount
        )!

        let libraryBuffer = device.makeBuffer(
            bytes: library,
            length: MemoryLayout<UInt64>.size * libraryCount
        )!

        let resultBuffer = device.makeBuffer(
            length: MemoryLayout<Result>.size * queryCount
        )!

        let paramsBuffer = device.makeBuffer(
            bytes: &params,
            length: MemoryLayout<Params>.size
        )!

        let command = queue.makeCommandBuffer()!
        let encoder = command.makeComputeCommandEncoder()!

        encoder.setComputePipelineState(matchPipeline)
        encoder.setBuffer(queryBuffer, offset: 0, index: 0)
        encoder.setBuffer(libraryBuffer, offset: 0, index: 1)
        encoder.setBuffer(resultBuffer, offset: 0, index: 2)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 3)

        let threadsPerGroup = MTLSize(width: max(1, matchPipeline.threadExecutionWidth), height: 1, depth: 1)
        let groups = MTLSize(
            width: (queryCount + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        command.commit()
        command.waitUntilCompleted()

        let ptr = resultBuffer.contents().bindMemory(to: Result.self, capacity: queryCount)
        return Array(UnsafeBufferPointer(start: ptr, count: queryCount))
    }
    private func makeRGBABuffer(from image: NSImage) -> (rgbaPixels: [RGBA8], width: Int, height: Int)? {
        let pixels = ImageConverter.imageToPixels(image)
        guard !pixels.isEmpty, !pixels[0].isEmpty else {
            return nil
        }

        let height = pixels.count
        let width = pixels[0].count

        var rgbaPixels = [RGBA8]()
        rgbaPixels.reserveCapacity(width * height)

        for row in pixels {
            for p in row {
                rgbaPixels.append(RGBA8(r: p.r, g: p.g, b: p.b, a: 255))
            }
        }

        return (rgbaPixels, width, height)
    }

    func buildFingerprint(from image: NSImage) -> UInt64 {
        guard let prepared = makeRGBABuffer(from: image) else {
            return 0
        }

        let rgbaPixels = prepared.rgbaPixels
        let width = prepared.width
        let height = prepared.height

        let inputBuffer = device.makeBuffer(
            bytes: rgbaPixels,
            length: MemoryLayout<RGBA8>.stride * rgbaPixels.count
        )!

        let outputBuffer = device.makeBuffer(
            length: MemoryLayout<UInt64>.stride,
            options: .storageModeShared
        )!

        var params = FingerprintParams(width: UInt32(width), height: UInt32(height))
        let paramsBuffer = device.makeBuffer(
            bytes: &params,
            length: MemoryLayout<FingerprintParams>.stride
        )!

        guard let command = queue.makeCommandBuffer(),
              let encoder = command.makeComputeCommandEncoder() else {
            return 0
        }

        encoder.setComputePipelineState(fingerprintPipeline)
        encoder.setBuffer(inputBuffer, offset: 0, index: 0)
        encoder.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder.setBuffer(paramsBuffer, offset: 0, index: 2)

        let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(width: 1, height: 1, depth: 1)
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        command.commit()
        command.waitUntilCompleted()

        if command.status != .completed {
            return 0
        }

        let ptr = outputBuffer.contents().bindMemory(to: UInt64.self, capacity: 1)
        return ptr.pointee
    }

    func buildFingerprintStaged(from image: NSImage) -> UInt64 {
        guard let prepared = makeRGBABuffer(from: image) else {
            return 0
        }

        let rgbaPixels = prepared.rgbaPixels
        let width = prepared.width
        let height = prepared.height
        let totalPixels = width * height
        guard totalPixels > 0 else { return 0 }

        let inputBuffer = device.makeBuffer(
            bytes: rgbaPixels,
            length: MemoryLayout<RGBA8>.stride * rgbaPixels.count,
            options: .storageModeShared
        )!

        // Stage 1: global reduce -> partial sums
        let reduceThreads = 256
        let reduceThreadsPerGroup = MTLSize(width: reduceThreads, height: 1, depth: 1)
        let reduceGroupCount = max(1, (totalPixels + reduceThreads - 1) / reduceThreads)
        let reduceGroups = MTLSize(width: reduceGroupCount, height: 1, depth: 1)

        let partialSumsBuffer = device.makeBuffer(
            length: MemoryLayout<Float>.stride * reduceGroupCount,
            options: .storageModeShared
        )!

        var reduceParams = GlobalReduceParams(
            width: UInt32(width),
            height: UInt32(height),
            totalPixels: UInt32(totalPixels),
            groupCount: UInt32(reduceGroupCount)
        )
        let reduceParamsBuffer = device.makeBuffer(
            bytes: &reduceParams,
            length: MemoryLayout<GlobalReduceParams>.stride,
            options: .storageModeShared
        )!

        guard let reduceCommand = queue.makeCommandBuffer(),
              let reduceEncoder = reduceCommand.makeComputeCommandEncoder() else {
            return 0
        }

        reduceEncoder.setComputePipelineState(globalReducePipeline)
        reduceEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        reduceEncoder.setBuffer(partialSumsBuffer, offset: 0, index: 1)
        reduceEncoder.setBuffer(reduceParamsBuffer, offset: 0, index: 2)
        reduceEncoder.dispatchThreadgroups(reduceGroups, threadsPerThreadgroup: reduceThreadsPerGroup)
        reduceEncoder.endEncoding()

        reduceCommand.commit()
        reduceCommand.waitUntilCompleted()
        if reduceCommand.status != .completed {
            return 0
        }

        let partialPtr = partialSumsBuffer.contents().bindMemory(to: Float.self, capacity: reduceGroupCount)
        let partialSums = UnsafeBufferPointer(start: partialPtr, count: reduceGroupCount)
        let totalLuminance = partialSums.reduce(Float(0), +)
        let globalAverage: Float = totalPixels > 0 ? totalLuminance / Float(totalPixels) : 0

        // Stage 2: tile stats -> 16 outputs
        let tileStatsBuffer = device.makeBuffer(
            length: MemoryLayout<ThermalTileStats>.stride * 16,
            options: .storageModeShared
        )!

        var tileParams = TileStatsParams(width: UInt32(width), height: UInt32(height))
        let tileParamsBuffer = device.makeBuffer(
            bytes: &tileParams,
            length: MemoryLayout<TileStatsParams>.stride,
            options: .storageModeShared
        )!

        let tileThreads = 256
        let tileThreadsPerGroup = MTLSize(width: tileThreads, height: 1, depth: 1)
        let tileGroups = MTLSize(width: 16, height: 1, depth: 1)

        guard let tileCommand = queue.makeCommandBuffer(),
              let tileEncoder = tileCommand.makeComputeCommandEncoder() else {
            return 0
        }

        tileEncoder.setComputePipelineState(tileStatsPipeline)
        tileEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        tileEncoder.setBuffer(tileStatsBuffer, offset: 0, index: 1)
        tileEncoder.setBuffer(tileParamsBuffer, offset: 0, index: 2)
        tileEncoder.dispatchThreadgroups(tileGroups, threadsPerThreadgroup: tileThreadsPerGroup)
        tileEncoder.endEncoding()

        tileCommand.commit()
        tileCommand.waitUntilCompleted()
        if tileCommand.status != .completed {
            return 0
        }

        // Stage 3: pack tile stats + global average -> fingerprint
        let fingerprintBuffer = device.makeBuffer(
            length: MemoryLayout<UInt64>.stride,
            options: .storageModeShared
        )!

        var packParams = FingerprintPackParams(globalAverage: globalAverage)
        let packParamsBuffer = device.makeBuffer(
            bytes: &packParams,
            length: MemoryLayout<FingerprintPackParams>.stride,
            options: .storageModeShared
        )!

        let packThreadsPerGroup = MTLSize(width: 16, height: 1, depth: 1)
        let packGroups = MTLSize(width: 1, height: 1, depth: 1)

        guard globalReducePipeline.maxTotalThreadsPerThreadgroup >= reduceThreads,
              tileStatsPipeline.maxTotalThreadsPerThreadgroup >= tileThreads,
              fingerprintPackPipeline.maxTotalThreadsPerThreadgroup >= 16 else {
            assertionFailure("ThermalCompute: invalid staged pipeline threadgroup capacity")
            return 0
        }

        guard let packCommand = queue.makeCommandBuffer(),
              let packEncoder = packCommand.makeComputeCommandEncoder() else {
            return 0
        }

        packEncoder.setComputePipelineState(fingerprintPackPipeline)
        packEncoder.setBuffer(tileStatsBuffer, offset: 0, index: 0)
        packEncoder.setBuffer(fingerprintBuffer, offset: 0, index: 1)
        packEncoder.setBuffer(packParamsBuffer, offset: 0, index: 2)
        packEncoder.dispatchThreadgroups(packGroups, threadsPerThreadgroup: packThreadsPerGroup)
        packEncoder.endEncoding()

        packCommand.commit()
        packCommand.waitUntilCompleted()
        if packCommand.status != .completed {
            return 0
        }

        let fingerprintPtr = fingerprintBuffer.contents().bindMemory(to: UInt64.self, capacity: 1)
        return fingerprintPtr.pointee
    }
}
