struct DiamondDictionaryEntry {

    var bucketID: UInt8
    var base: Diamond
    var firstPosition: PositionMap.Pos

    // Shared storage for packed signed 5-5-5 residuals.
    // CPU and GPU paths now both reconstruct from the same packed representation.
    var deltaPositions: [(dx: Int16, dy: Int16)]
    var residuals: [UInt16]

    /// Marks whether the entry was built from GPU-preprocessed pixels.
    /// Reconstruction still uses the same packed residual stream.
    var usesGPUResiduals: Bool

    /// Residual bit depth (5 for signed 5-5-5 pipeline)
    var residualBitDepth: UInt8 = 5

    init(base: Diamond, bucketID: UInt8, firstPosition: PositionMap.Pos) {
        self.base = base
        self.bucketID = bucketID
        self.firstPosition = firstPosition

        self.deltaPositions = []
        self.residuals = []
        self.usesGPUResiduals = false
    }
}
