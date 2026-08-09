import Foundation

enum ConfigManager {

    private static let defaults = UserDefaults.standard
    private static let keyHost = "server_host"
    private static let keyPort = "server_port"

    private static let defaultHost = "localhost"
    private static let defaultPort = 8080

    static var host: String {
        defaults.string(forKey: keyHost) ?? defaultHost
    }

    static var port: Int {
        let p = defaults.integer(forKey: keyPort)
        return p > 0 ? p : defaultPort
    }

    static func save(host: String, port: Int) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(trimmed.isEmpty ? defaultHost : trimmed, forKey: keyHost)
        defaults.set(port <= 0 ? defaultPort : port, forKey: keyPort)
    }

    static var baseAuth: String { "http://\(host):\(port)/" }
    static var baseMenu: String { "http://\(host):\(port)/" }
    static var baseOrder: String { "http://\(host):\(port)/" }
}
