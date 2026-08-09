import Foundation

enum JwtUtils {

    static func decodePayload(_ jwt: String) -> String {
        guard !jwt.isEmpty else { return "" }
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return "" }
        var base64 = String(parts[1])
        base64 = base64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func exp(_ jwt: String) -> Int64 {
        let payload = decodePayload(jwt)
        guard !payload.isEmpty else { return 0 }
        guard let range = payload.range(of: "\"exp\"") else { return 0 }
        let after = payload[range.upperBound...]
        guard let colon = after.firstIndex(of: ":") else { return 0 }
        let valueStart = after.index(after: colon)
        var valueEnd = after.endIndex
        if let comma = after[valueStart...].firstIndex(of: ",") {
            valueEnd = comma
        } else if let brace = after[valueStart...].firstIndex(of: "}") {
            valueEnd = brace
        }
        let value = after[valueStart..<valueEnd].trimmingCharacters(in: .whitespaces)
        return Int64(Double(value) ?? 0)
    }
}
