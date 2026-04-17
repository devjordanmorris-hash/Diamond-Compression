import Foundation

struct PositionMap {
    static func toIndex(x: UInt16, y: UInt16, width: UInt16) -> Int {
        return Int(y) * Int(width) + Int(x)
    }

    static func fromIndex(_ index: Int, width: UInt16) -> Pos {
        let y = UInt16(index / Int(width))
        let x = UInt16(index % Int(width))
        return Pos(x: x, y: y)
    }

    struct Pos {
        var x: UInt16
        var y: UInt16
    }
    var positions: [Pos]
}
