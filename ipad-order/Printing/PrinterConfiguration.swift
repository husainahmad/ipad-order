import Foundation
import UIKit

struct PrinterConfiguration {
    let paperWidthDots: Int
    let useRasterForUnicode: Bool
    let fontSize: CGFloat
    let encoding: String.Encoding

    static let `default` = PrinterConfiguration(
        paperWidthDots: 384,
        useRasterForUnicode: true,
        fontSize: 24,
        encoding: .ascii
    )

    static let mm80 = PrinterConfiguration(
        paperWidthDots: 576,
        useRasterForUnicode: true,
        fontSize: 24,
        encoding: .ascii
    )

    // SM58 58mm @203dpi = 384 dots, 80mm = 576 dots
    init(paperWidthDots: Int = 384,
         useRasterForUnicode: Bool = true,
         fontSize: CGFloat = 24,
         encoding: String.Encoding = .ascii) {
        self.paperWidthDots = paperWidthDots
        self.useRasterForUnicode = useRasterForUnicode
        self.fontSize = fontSize
        self.encoding = encoding
    }
}

enum ESCPosAlignment: UInt8 {
    case left = 0
    case center = 1
    case right = 2
}

enum TextAlignment {
    case left, center, right

    var escPos: ESCPosAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}
