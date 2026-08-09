import Foundation
import Network
import CoreBluetooth
import Combine

enum PrinterError: LocalizedError {
    case addressNotSet
    case connectionFailed(String)
    case bluetoothUnsupported
    case bluetoothNotAuthorized
    case bluetoothNotReady
    case peripheralDisconnected
    case writeFailed
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .addressNotSet: return "Printer address not set"
        case .connectionFailed(let message): return message
        case .bluetoothUnsupported: return "Bluetooth is not supported on this device"
        case .bluetoothNotAuthorized: return "Bluetooth access not authorized. Go to Settings > Privacy > Bluetooth."
        case .bluetoothNotReady: return "Bluetooth is not ready. Turn it on and try again."
        case .peripheralDisconnected: return "Printer disconnected unexpectedly"
        case .writeFailed: return "Failed to send data to printer"
        case .notConfigured: return "No Bluetooth printer paired. Configure in Settings."
        }
    }
}

final class PrinterManager: NSObject, ObservableObject {

    static let typeNetwork = "network"
    static let typeBluetooth = "bluetooth"
    static let typeUsb = "usb"

    private static let defaults = UserDefaults.standard
    private static let keyType = "printer_type"
    private static let keyAddress = "printer_address"
    private static let keyPort = "printer_port"
    private static let keyPrinterName = "printer_name"

    private static let defaultNetworkPort = 9100

    // KT6368A dual-mode Bluetooth chip UUIDs (used by VSC TM-58D PRO and similar).
    // Android connects via SPP (Classic Bluetooth), iOS connects via BLE.
    private static let bleServiceUUID = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
    private static let bleWriteUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    private static let bleNotifyUUID = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")

    // MARK: - Published state (for the Settings UI)

    @Published var bluetoothState: CBManagerState = .unknown
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var isScanning = false

    // MARK: - BLE internals

    private var centralManager: CBCentralManager?
    private var writeCharacteristic: CBCharacteristic?
    private var pendingPrintData: Data?
    private var currentPrintCompletion: ((Result<Void, Error>) -> Void)?

    // MARK: - Singleton

    static let shared = PrinterManager()

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Configuration (UserDefaults)

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

    static var savedPrinterName: String {
        defaults.string(forKey: keyPrinterName) ?? ""
    }

    static func save(type: String, address: String, port: Int, name: String = "") {
        defaults.set(type, forKey: keyType)
        defaults.set(address, forKey: keyAddress)
        defaults.set(port <= 0 ? defaultNetworkPort : port, forKey: keyPort)
        defaults.set(name, forKey: keyPrinterName)
    }

    // MARK: - Public print dispatch

    /// Print text using the currently configured printer type (network or Bluetooth LE).
    static func print(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if type == typeBluetooth {
            shared.printViaBLE(text, completion: completion)
        } else {
            printViaNetwork(text, completion: completion)
        }
    }

    // MARK: - Network printing

    private static func printViaNetwork(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
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

    // MARK: - Bluetooth LE printing

    /// Scan for nearby BLE thermal printers.
    func startScan() {
        guard let cm = centralManager, cm.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        cm.scanForPeripherals(withServices: [Self.bleServiceUUID],
                              options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        isScanning = true
    }

    func stopScan() {
        centralManager?.stopScan()
        isScanning = false
    }
    /// Connect to a specific peripheral discovered by the scan.
    func connect(to peripheral: CBPeripheral) {
        guard let cm = centralManager else { return }
        stopScan()
        cm.connect(peripheral, options: nil)
    }

    /// Disconnect from the currently connected printer.
    func disconnect() {
        guard let peripheral = connectedPeripheral, let cm = centralManager else { return }
        cm.cancelPeripheralConnection(peripheral)
        connectedPeripheral = nil
        writeCharacteristic = nil
    }

    private func printViaBLE(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let cm = centralManager else {
            completion(.failure(PrinterError.bluetoothNotReady))
            return
        }
        switch cm.state {
        case .unsupported:
            completion(.failure(PrinterError.bluetoothUnsupported))
            return
        case .unauthorized:
            completion(.failure(PrinterError.bluetoothNotAuthorized))
            return
        case .poweredOff:
            completion(.failure(PrinterError.bluetoothNotReady))
            return
        default:
            break
        }

        let data = Self.buildBytes(text)

        if let peripheral = connectedPeripheral, let writeChar = writeCharacteristic {
            writeData(data, to: writeChar, peripheral: peripheral, completion: completion)
        } else {
            // No active connection. Try to auto-connect to the saved printer.
            let savedName = Self.savedPrinterName
            guard !savedName.isEmpty else {
                completion(.failure(PrinterError.notConfigured))
                return
            }
            pendingPrintData = data
            currentPrintCompletion = completion
            autoConnect(to: savedName)
        }
    }

    private func autoConnect(to name: String) {
        guard let cm = centralManager, cm.state == .poweredOn else {
            currentPrintCompletion?(.failure(PrinterError.bluetoothNotReady))
            currentPrintCompletion = nil
            pendingPrintData = nil
            return
        }
        discoveredPeripherals.removeAll()
        isScanning = true
        cm.scanForPeripherals(withServices: [Self.bleServiceUUID], options: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.writeCharacteristic == nil {
                self.stopScan()
                self.currentPrintCompletion?(.failure(PrinterError.connectionFailed(
                    "Printer '\(name)' not found. Make sure it is turned on and in pairing mode."
                )))
                self.currentPrintCompletion = nil
                self.pendingPrintData = nil
            }
        }
    }

    private func writeData(_ data: Data,
                           to characteristic: CBCharacteristic,
                           peripheral: CBPeripheral,
                           completion: @escaping (Result<Void, Error>) -> Void) {
        // Receipt data is small; write without response is fine and immediate.
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        completion(.success(()))
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

// MARK: - CBCentralManagerDelegate

extension PrinterManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        switch central.state {
        case .poweredOn:
            break
        case .poweredOff:
            connectedPeripheral = nil
            writeCharacteristic = nil
            currentPrintCompletion?(.failure(PrinterError.bluetoothNotReady))
            currentPrintCompletion = nil
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }

        // Auto-connect to the saved printer by advertised/local name.
        let savedName = Self.savedPrinterName
        if !savedName.isEmpty {
            let advName = advertisementData["kCBAdvDataLocalName"] as? String ?? ""
            let matches = advName.contains(savedName) || (peripheral.name?.contains(savedName) ?? false)
            if matches {
                connect(to: peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices([Self.bleServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        stopScan()
        currentPrintCompletion?(.failure(PrinterError.connectionFailed(
            error?.localizedDescription ?? "Failed to connect to printer"
        )))
        currentPrintCompletion = nil
        pendingPrintData = nil
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            writeCharacteristic = nil
        }
    }
}

// MARK: - CBPeripheralDelegate

extension PrinterManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else { return }
        for service in peripheral.services ?? [] where service.uuid == Self.bleServiceUUID {
            peripheral.discoverCharacteristics([Self.bleWriteUUID, Self.bleNotifyUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else { return }
        for char in service.characteristics ?? [] where char.uuid == Self.bleWriteUUID {
            writeCharacteristic = char
        }
        stopScan()

        // If a print was requested while reconnecting, deliver it now.
        if let data = pendingPrintData, let writeChar = writeCharacteristic {
            pendingPrintData = nil
            writeData(data, to: writeChar, peripheral: peripheral) { [weak self] result in
                self?.currentPrintCompletion?(result)
                self?.currentPrintCompletion = nil
            }
        }
    }
}
