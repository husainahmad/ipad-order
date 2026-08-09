import Foundation

enum CurrencyUtils {

    private static var wholeFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }

    private static var twoDecimalFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }

    static func formatRp(_ value: Double) -> String {
        let rounded = value.rounded()
        let number = NSNumber(value: rounded)
        return "Rp." + (wholeFormatter.string(from: number) ?? "0")
    }

    static func formatRp2(_ value: Double) -> String {
        let number = NSNumber(value: value)
        return "Rp." + (twoDecimalFormatter.string(from: number) ?? "0.00")
    }

    static func formatPlain(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
