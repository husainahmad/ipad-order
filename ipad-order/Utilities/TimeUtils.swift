import Foundation

enum TimeUtils {

    static let timezone = TimeZone(identifier: "Asia/Jakarta") ?? .current

    static func toJakarta(_ isoUtc: String) -> String {
        guard !isoUtc.isEmpty else { return "" }

        var date: Date?
        let input = isoUtc

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        withFraction.timeZone = TimeZone(identifier: "UTC")

        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        withoutFraction.timeZone = TimeZone(identifier: "UTC")

        let withSpace = DateFormatter()
        withSpace.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        withSpace.timeZone = TimeZone(identifier: "UTC")
        withSpace.locale = Locale(identifier: "en_US_POSIX")

        if let d = withFraction.date(from: input) { date = d }
        else if let d = withoutFraction.date(from: input) { date = d }
        else if let d = withSpace.date(from: input) { date = d }

        guard let date = date else { return isoUtc }

        let out = DateFormatter()
        out.dateFormat = "yyyy-MM-dd HH:mm"
        out.timeZone = timezone
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: date)
    }

    static func todayDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
