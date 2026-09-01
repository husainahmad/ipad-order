import UIKit
import CoreText

final class UnicodeTextRenderer {

    /// Render text to monochrome CGImage for ESC/POS raster
    /// - Parameters:
    ///   - text: String to render (single or multi-line)
    ///   - width: target width in dots (pixels), e.g. 384
    ///   - fontSize: font size in points
    ///   - alignment: left/center/right
    ///   - language: language code for font selection (ja, zh-Hans, ko, ar, etc.)
    /// - Returns: CGImage or nil
    static func render(text: String,
                       width: Int,
                       fontSize: CGFloat = 24,
                       alignment: TextAlignment = .left,
                       language: String = "en") -> CGImage? {
        guard !text.isEmpty else { return nil }
        // Use custom font with fallback for CJK/Arabic
        let font = FontLoader.font(for: language, size: fontSize)
        // For Arabic, ensure RTL handling
        let isRTL = containsRTL(text)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment.nsAlignment
        paragraph.lineBreakMode = .byWordWrapping
        if isRTL {
            paragraph.baseWritingDirection = .rightToLeft
            // keep requested alignment (center for footer) — don't force .right
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]

        let attrString = NSAttributedString(string: text, attributes: attrs)

        // Calculate height needed with word wrapping
        let maxSize = CGSize(width: CGFloat(width), height: CGFloat.greatestFiniteMagnitude)
        let rect = attrString.boundingRect(with: maxSize,
                                           options: [.usesLineFragmentOrigin, .usesFontLeading],
                                           context: nil)
        let height = max(ceil(rect.height), fontSize + 8)
        guard height > 0 && width > 0 else { return nil }

        let size = CGSize(width: CGFloat(width), height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            attrString.draw(with: CGRect(origin: .zero, size: size),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil)
        }

        return image.cgImage
    }

    /// Check if text contains RTL characters (Arabic/Hebrew)
    private static func containsRTL(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            // Arabic 0600-06FF, 0750-077F, 08A0-08FF, Hebrew 0590-05FF
            if (0x0590...0x08FF).contains(v) { return true }
        }
        return false
    }

    /// Convert CGImage to 1-bit monochrome data for ESC/POS raster
    /// Returns Data already packed (no ESC/POS header)
    static func monochromeData(from cgImage: CGImage, width: Int) -> Data? {
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0 && h > 0 else { return nil }

        // Create grayscale context
        let bytesPerRow = w
        var rawData = Data(count: w * h)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let result = rawData.withUnsafeMutableBytes { ptr -> CGContext? in
            guard let ctx = CGContext(data: ptr.baseAddress,
                                      width: w,
                                      height: h,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return ctx
        }
        guard result != nil else { return nil }

        // Threshold to 1-bit: black if gray < 128
        var mono = Data()
        mono.reserveCapacity((w + 7) / 8 * h)
        for y in 0..<h {
            for xByte in 0..<(w + 7) / 8 {
                var byte: UInt8 = 0
                for bit in 0..<8 {
                    let x = xByte * 8 + bit
                    if x >= w { break }
                    let idx = y * w + x
                    let gray = rawData[idx]
                    let isBlack = gray < 128
                    if isBlack {
                        byte |= UInt8(1 << (7 - bit))
                    }
                }
                mono.append(byte)
            }
        }
        return mono
    }

    /// Quick check if string needs raster (contains Unicode beyond printer encoding)
    static func needsRaster(_ text: String) -> Bool {
        // If any scalar > 255, needs raster (covers CJK, Arabic, Korean, symbols)
        // Latin-1 0x00-0xFF can be printed via ESC/POS text (if printer supports)
        for scalar in text.unicodeScalars {
            if scalar.value > 255 {
                return true
            }
        }
        return false
    }
}
