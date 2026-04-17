//
//  DiamondMetal.swift
//  daimond compression
//
//  Created by Jordan Morris on 18/11/2025.
//

import Foundation
import Metal
import MetalKit

/// GPU-accelerated helper for per-pixel preprocessing.
/// In the current shader contract, the GPU returns:
/// - bucketID
/// - one packed signed 5-5-5 residual against a fixed neutral base (128,128,128)
/// CPU code then performs dictionary building and chain reconstruction.
class DiamondMetal {

    static let shared = DiamondMetal()

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let library: MTLLibrary
    private let pipeline: MTLComputePipelineState

    private init() {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal not supported on this device")
        }
        device = dev
        queue = device.makeCommandQueue()!

        // Load Metal shader from DiamondMetal.metal
        library = try! device.makeDefaultLibrary(bundle: .main)
        pipeline = try! device.makeComputePipelineState(
            function: library.makeFunction(name: "diamond_preprocess")!
        )
    }

    struct GPUOutput {
        var bucketID: UInt8
        var _padding: UInt8 = 0
        var signedResidual: UInt16
    }

    /// Run the Metal kernel on the given pixel array.
    /// - Parameters:
    ///   - pixels: 2D pixel array
    ///   - baseRGB: retained for call-site compatibility; GPU mode ignores it and uses a fixed neutral base
    /// - Returns: Flat array mapped 1:1 to input pixels
    func processPixels(_ pixels: [[Pixel]], baseRGB: UInt32) -> [GPUOutput] {

        let height = pixels.count
        guard height > 0 else { return [] }
        let width = pixels[0].count
        guard width > 0 else { return [] }
        let total = width * height

        // Temporary safety fallback: if the compute pipeline reports an unusable launch shape,
        // skip GPU preprocessing and let the encoder use the CPU path instead.
        if pipeline.maxTotalThreadsPerThreadgroup <= 0 || pipeline.threadExecutionWidth <= 0 {
            assertionFailure("DiamondMetal: invalid compute pipeline launch configuration")
            return []
        }

        // Flatten input pixels into a byte buffer
        var flatPixels = [UInt32](repeating: 0, count: total)
        var idx = 0
        for y in 0..<height {
            for x in 0..<width {
                let p = pixels[y][x]
                flatPixels[idx] =
                    (UInt32(p.r) << 16) |
                    (UInt32(p.g) << 8)  |
                    UInt32(p.b)
                idx += 1
            }
        }

        // Buffers
        let inBuffer = device.makeBuffer(
            bytes: flatPixels,
            length: MemoryLayout<UInt32>.size * total
        )!

        var baseColor = baseRGB // retained for compatibility with existing call sites
        let baseBuffer = device.makeBuffer(
            bytes: &baseColor,
            length: MemoryLayout<UInt32>.size
        )!

        var totalCount = UInt32(total)
        let countBuffer = device.makeBuffer(
            bytes: &totalCount,
            length: MemoryLayout<UInt32>.size
        )!

        let outBuffer = device.makeBuffer(
            length: MemoryLayout<GPUOutput>.stride * total,
            options: .storageModeShared
        )!

        guard let command = queue.makeCommandBuffer() else {
            assertionFailure("DiamondMetal: failed to create command buffer")
            return []
        }
        guard let encoder = command.makeComputeCommandEncoder() else {
            assertionFailure("DiamondMetal: failed to create compute encoder")
            return []
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inBuffer, offset: 0, index: 0)
        encoder.setBuffer(baseBuffer, offset: 0, index: 1)
        encoder.setBuffer(outBuffer, offset: 0, index: 2)
        encoder.setBuffer(countBuffer, offset: 0, index: 3)
        encoder.label = "Diamond preprocess encoder"

        // Fall back to a conservative, uniform 1D launch.
        // This avoids non-uniform tail behaviour and keeps the last partial group
        // inside the shader's explicit `tid >= totalCount` guard.
        let groupWidth = min(max(1, pipeline.threadExecutionWidth), total)
        let threadsPerThreadgroup = MTLSize(width: groupWidth, height: 1, depth: 1)
        let threadgroupsPerGrid = MTLSize(
            width: (total + groupWidth - 1) / groupWidth,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadgroupsPerGrid,
                                     threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()

        if let error = command.error {
            print("DiamondMetal command buffer error: \(error)")
        }

        guard command.status == .completed else {
            print("DiamondMetal command buffer did not complete successfully: \(command.status.rawValue)")
            return []
        }

        let stride = MemoryLayout<GPUOutput>.stride
        guard outBuffer.length >= stride * total else {
            assertionFailure("DiamondMetal: output buffer smaller than expected")
            return []
        }

        // The Metal shader packs a signed 5-5-5 residual into `signedResidual`.
        // `baseRGB` is still forwarded to preserve the current host/shader binding shape,
        // but GPU mode reconstruction now assumes a fixed neutral base.
        // Read results
        let rawPtr = outBuffer.contents().bindMemory(to: GPUOutput.self,
                                                     capacity: total)
        let bufferPointer = UnsafeBufferPointer(start: rawPtr, count: total)
        return Array(bufferPointer)
    }
}
