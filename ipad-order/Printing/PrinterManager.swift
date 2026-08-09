import Foundation
import Network

enum PrinterError: LocalizedError {
    case addressNotSet
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .addressNotSet: return "Printer address not set"
        case .connectionFailed(let message): return message
        }
    }
}

final class PrinterManager {

    static let typeNetwork = "network"
    static let typeBluetooth = "bluetooth"
    static let typeUsb = "usb"

    private static let defaults = UserDefaults.standard
    private static let keyType = "printer_type"
    private static let keyAddress = "printer_address"
    private static let keyPort = "printer_port"

    private static let defaultNetworkPort = 9100

    private init() {}

    // On iOS, only network (TCP/IP) printing is supported by the system.
    // Bluetooth classic (SPP) and USB host printers are not supported.
    static var type: String {
        defaults.string(forKey: keyType) ?? typeNetwork
    }

    static var address: String {
        defaults.string(forKey: keyAddress) ?? ""
    }

    static var port: Int {
        let p = defaults.integer(forKey: keyPort)
        return p > 0 ? p : defaultNetworkPort
    }

    static func save(type: String, address: String, port: Int) {
        defaults.set(type, forKey: keyType)
        defaults.set(address, forKey: keyAddress)
        defaults.set(port <= 0 ? defaultNetworkPort : port, forKey: keyPort)
    }

    static func print(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let targetAddress = address
        guard !targetAddress.trimmingCharacters(in: .whitespaces).isEmpty else {
            completion(.failure(PrinterError.addressNotSet))
            return
        }
        let host = NWEndpoint.Host(targetAddress)
        guard let portValue = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(.failure(PrinterError.connectionFailed("Invalid port \(port)")))
            return
        }

        let connection = NWConnection(host: host, port: portValue, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let data = buildBytes(text)
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        completion(.failure(PrinterError.connectionFailed(error.localizedDescription)))
                    } else {
                        completion(.success(()))
                    }
                    connection.cancel()
                })
            case .failed(let error):
                completion(.failure(PrinterError.connectionFailed(error.localizedDescription)))
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - ESC/POS bytes

    static func buildBytes(_ text: String) -> Data {
        var data = Data()
        data.append(contentsOf: [0x1B, 0x40])                 // initialize
        if let textData = text.data(using: .utf8) {
            data.append(textData)
        }
        data.append(contentsOf: [0x1B, 0x64, 0x04])           // feed 4 lines
        data.append(contentsOf: [0x1D, 0x56, 0x42])           // cut
        return data
    }
}
