import UIKit

final class ESCPosEncoder {

    let configuration: PrinterConfiguration

    init(configuration: PrinterConfiguration = .default) {
        self.configuration = configuration
    }

    /// Detect language from text content for font selection
    static func detectLanguage(_ text: String) -> String {
        var hasHiraganaKatakana = false
        var hasHangul = false
        var hasArabic = false
        var hasHebrew = false
        var hasThai = false
        var hasCJK = false
        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x3040...0x309F).contains(v) || (0x30A0...0x30FF).contains(v) { hasHiraganaKatakana = true }
            if (0xAC00...0xD7AF).contains(v) || (0x1100...0x11FF).contains(v) { hasHangul = true }
            if (0x0600...0x06FF).contains(v) || (0x0750...0x077F).contains(v) || (0x08A0...0x08FF).contains(v) { hasArabic = true }
            if (0x0590...0x05FF).contains(v) { hasHebrew = true }
            if (0x0E00...0x0E7F).contains(v) { hasThai = true }
            if (0x4E00...0x9FFF).contains(v) { hasCJK = true }
        }
        if hasHiraganaKatakana { return "ja" }
        if hasHangul { return "ko" }
        if hasArabic { return "ar" }
        if hasHebrew { return "he" }
        if hasThai { return "th" }
        if hasCJK {
            if text.contains("。") || text.contains("，") || text.contains("、") || text.contains("：") || text.contains("你好") || text.contains("谢谢") || text.contains("咖啡") {
                return "zh-Hans"
            }
            return "ja" // default CJK to ja if no other hint; PingFang vs Hiragino both cover but ja preferred for mixed
        }
        return "en"
    }

    // MARK: - Basic commands

    /// ESC @ — Initialize printer
    func initialize() -> Data {
        Data([0x1B, 0x40])
    }

    /// ESC a n — Alignment
    func align(_ alignment: ESCPosAlignment) -> Data {
        Data([0x1B, 0x61, alignment.rawValue])
    }

    /// ESC E n — Bold
    func bold(_ enabled: Bool) -> Data {
        Data([0x1B, 0x45, enabled ? 1 : 0])
    }

    /// LF — Line break
    func lineBreak(_ count: Int = 1) -> Data {
        var d = Data()
        for _ in 0..<count { d.append(0x0A) }
        return d
    }

    /// ESC d n — Feed n lines
    func feed(_ lines: Int) -> Data {
        Data([0x1B, 0x64, UInt8(min(lines, 255))])
    }

    /// GS V 66 — Cut (partial)
    func cut() -> Data {
        // GS V 66 (or 0x1D 0x56 0x42 0x00) — partial cut
        Data([0x1D, 0x56, 0x42, 0x00])
    }

    // MARK: - Text

    /// Normal ESC/POS text (ASCII/Latin). Uses configured encoding.
    func text(_ text: String) -> Data {
        guard !text.isEmpty else { return Data() }
        // For normal text, use ASCII/UTF8. ESC/POS printers with UTF8 support can handle Latin.
        // We avoid UTF8 for pure ASCII to keep compatible.
        if let data = text.data(using: configuration.encoding) {
            return data
        }
        // Fallback to ascii with replacement
        return text.data(using: .ascii, allowLossyConversion: true) ?? Data()
    }

    func textLine(_ text: String) -> Data {
        var d = self.text(text)
        d.append(0x0A)
        return d
    }

    // MARK: - Unicode raster

    /// Render Unicode string as raster image Data (GS v 0)
    func unicodeText(_ text: String,
                     fontSize: CGFloat? = nil,
                     alignment: TextAlignment = .left) -> Data {
        let size = fontSize ?? configuration.fontSize
        let lang = Self.detectLanguage(text)
        // Trim trailing newline for rendering, will add LF after raster
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return lineBreak() }
        guard let cgImage = UnicodeTextRenderer.render(text: trimmed,
                                                       width: configuration.paperWidthDots,
                                                       fontSize: size,
                                                       alignment: alignment,
                                                       language: lang) else {
            return textLine(trimmed)
        }
        return image(cgImage)
    }

    /// Check if text needs raster
    func needsRaster(_ text: String) -> Bool {
        guard configuration.useRasterForUnicode else { return false }
        return UnicodeTextRenderer.needsRaster(text)
    }

    // MARK: - Image raster (GS v 0)

    /// GS v 0 m xL xH yL yH d...
    /// m=0, x = width bytes, y = height dots
    func image(_ cgImage: CGImage) -> Data {
        let width = cgImage.width
        let height = cgImage.height
        guard let mono = UnicodeTextRenderer.monochromeData(from: cgImage, width: width) else { return Data() }

        let widthBytes = (width + 7) / 8
        let xL = UInt8(widthBytes & 0xFF)
        let xH = UInt8((widthBytes >> 8) & 0xFF)
        let yL = UInt8(height & 0xFF)
        let yH = UInt8((height >> 8) & 0xFF)

        var data = Data()
        // GS v 0 m
        data.append(contentsOf: [0x1D, 0x76, 0x30, 0x00])
        data.append(xL)
        data.append(xH)
        data.append(yL)
        data.append(yH)
        data.append(mono)
        data.append(0x0A) // LF after image
        return data
    }

    // MARK: - Hybrid line encoding

    /// Encode single line with auto detection
    func encodeLine(_ line: String, alignment: TextAlignment = .left) -> Data {
        if line.isEmpty { return lineBreak() }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return lineBreak() }

        // Detect alignment from original padding (for centered lines from PrintUtils.centered)
        // If line was centered (leading spaces), we preserve center alignment for raster
        let isCentered = line.hasPrefix(" ") && line.hasSuffix(" ")
        let align: TextAlignment = isCentered ? .center : alignment

        if needsRaster(line) {
            // For raster, strip padding spaces added by PrintUtils.centered/twoCol and let renderer align
            let content = trimmed
            return unicodeText(content, alignment: align)
        } else {
            // Normal text — keep original line as is (with spaces) + LF
            // If line already has no LF, add one
            var d = text(line)
            if !line.hasSuffix("\n") { d.append(0x0A) }
            return d
        }
    }

    /// Encode entire receipt string (multiple lines) with hybrid mode
    func encodeReceipt(_ receipt: String) -> Data {
        var out = Data()
        out.append(initialize())
        // Split preserving empty lines
        let lines = receipt.components(separatedBy: "\n")
        for line in lines {
            // Preserve last empty split as feed
            if line.isEmpty {
                // Empty line from trailing \n — we already appended LF per line, skip duplicate?
                // For receipt, empty string from components(separatedBy:) last element is trailing \n — feed one line
                continue
            }
            // Detect twoCol lines? They have left/right — for unicode mixed, raster whole line
            out.append(encodeLine(line))
        }
        out.append(feed(4))
        out.append(cut())
        return out
    }

    // MARK: - Debug

    static func debugLog(receipt: String, configuration: PrinterConfiguration) {
        #if DEBUG
        let encoder = ESCPosEncoder(configuration: configuration)
        print("[ESC/POS] Paper width: \(configuration.paperWidthDots) dots, Raster: \(configuration.useRasterForUnicode)")
        for line in receipt.components(separatedBy: "\n") where !line.isEmpty {
            let mode = encoder.needsRaster(line) ? "Raster" : "Text"
            print("[ESC/POS] \(mode): \(line)")
        }
        #endif
    }
}
