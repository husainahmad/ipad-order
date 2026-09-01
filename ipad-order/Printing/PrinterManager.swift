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
    // SM58 often advertises generic SPP or FFE0, so we support both specific and generic.
    private static let bleServiceUUID = CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455")
    private static let bleWriteUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    private static let bleNotifyUUID = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
    private static let genericServiceUUIDs: [CBUUID] = [
        CBUUID(string: "FFE0"), CBUUID(string: "FF00"), CBUUID(string: "18F0")
    ]

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

    // MARK: - Public print dispatch (hybrid ESC/POS)

    /// Print text using the currently configured printer type (network or Bluetooth LE).
    /// Hybrid: ASCII/Latin → ESC/POS text, Unicode → raster via iPad rendering
    static func print(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let data = encodeForPrinter(text)
        printData(data, completion: completion)
    }

    /// Direct Data print (already ESC/POS encoded)
    static func printData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        if type == typeBluetooth {
            shared.printViaBLEData(data, completion: completion)
        } else {
            printViaNetworkData(data, completion: completion)
        }
    }

    /// Hybrid encoder — keeps public String API but internally converts to ESC/POS Data
    static func encodeForPrinter(_ text: String) -> Data {
        let config = PrinterConfiguration.default
        let encoder = ESCPosEncoder(configuration: config)
        // Debug logging
        ESCPosEncoder.debugLog(receipt: text, configuration: config)
        return encoder.encodeReceipt(text)
    }

    /// Unicode test (58mm) — prints multilingual sample for SM58
    static func printUnicodeTest(completion: @escaping (Result<Void, Error>) -> Void = { _ in }) {
        var sb = ""
        sb += "HARMONI POS - UNICODE TEST\n"
        sb += "--------------------------------\n"
        sb += "1. English: Hello World\n"
        sb += "2. Indonesian: Terima kasih\n"
        sb += "3. Japanese: こんにちは / ありがとうございます / コーヒー\n"
        sb += "4. Chinese: 你好 / 谢谢 / 咖啡\n"
        sb += "5. Korean: 안녕하세요 / 감사합니다 / 커피\n"
        sb += "6. Arabic: مرحبا / شكراً\n"
        sb += "7. Mixed: Coffee / コーヒー / 咖啡 / 커피\n"
        sb += "8. Currency: Rp 17.000 / Rp 125.000\n"
        sb += "9. Symbols: ★ ☆ ✓ ×\n"
        sb += "--------------------------------\n"
        sb += "Receipt demo:\n"
        sb += "Coffee Latte              18.000\n"
        sb += "Kopi Gula Aren            17.000\n"
        sb += "商品名: コーヒー\n"
        sb += "数量: 2\n"
        sb += "商品名称: 咖啡\n"
        sb += "수량: 2\n"
        sb += "شكراً\n"
        sb += "--------------------------------\n"
        print(sb, completion: completion)
    }

    // MARK: - Network printing (hybrid: Data already ESC/POS encoded)

    private static func printViaNetwork(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        printViaNetworkData(encodeForPrinter(text), completion: completion)
    }

    private static func printViaNetworkData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
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
    /// SM58 often not advertising 49535343, so scan generic (nil) + specific to catch both.
    func startScan() {
        guard let cm = centralManager, cm.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        // nil = generic scan to catch SM58 / RP58 / M58 / generic FFE0
        cm.scanForPeripherals(withServices: nil,
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
        printViaBLEData(Self.encodeForPrinter(text), completion: completion)
    }

    private func printViaBLEData(_ data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
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

        if let peripheral = connectedPeripheral, let writeChar = writeCharacteristic {
            writeDataInChunks(data, to: writeChar, peripheral: peripheral, completion: completion)
        } else {
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
        cm.scanForPeripherals(withServices: nil, options: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.writeCharacteristic == nil {
                self.stopScan()
                self.currentPrintCompletion?(.failure(PrinterError.connectionFailed(
                    "Printer '\(name)' not found. Make sure it is turned on and in pairing mode. For SM58 hold power + feed."
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
        writeDataInChunks(data, to: characteristic, peripheral: peripheral, completion: completion)
    }

    private func writeDataInChunks(_ data: Data,
                                   to characteristic: CBCharacteristic,
                                   peripheral: CBPeripheral,
                                   completion: @escaping (Result<Void, Error>) -> Void,
                                   chunkSize: Int = 64) {
        // BLE MTU ~ 185, use small chunks + longer delay for SM58 raster (GS v 0) stability
        // 10ms was too fast -> printer drops bytes, GS header lost -> binary printed as garbled text
        let chunkDelay: TimeInterval = data.count > 2048 ? 0.04 : 0.03
        // Use withResponse if available for reliability
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        if data.count <= chunkSize {
            peripheral.writeValue(data, for: characteristic, type: writeType)
            if writeType == .withoutResponse {
                DispatchQueue.main.asyncAfter(deadline: .now() + chunkDelay) { completion(.success(())) }
            } else {
                // withResponse will call delegate, but we complete optimistically after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { completion(.success(())) }
            }
            return
        }
        var offset = 0
        func sendNext() {
            guard offset < data.count else {
                // Extra flush delay for printer to finish raster
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { completion(.success(())) }
                return
            }
            let end = min(offset + chunkSize, data.count)
            let chunk = data[offset..<end]
            peripheral.writeValue(Data(chunk), for: characteristic, type: writeType)
            offset = end
            DispatchQueue.main.asyncAfter(deadline: .now() + chunkDelay) {
                sendNext()
            }
        }
        sendNext()
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
        // Filter for SM58-relevant names to reduce noise, but keep generic thermal names
        let name = peripheral.name ?? advertisementData["kCBAdvDataLocalName"] as? String ?? ""
        let lower = name.lowercased()
        let isThermal = lower.contains("m58") || lower.contains("sm58") || lower.contains("rp58") || lower.contains("thermal") || lower.contains("printer") || lower.contains("pos") || name.isEmpty
        // Keep all if no name yet (SM58 often advertises empty local name initially)
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            // Add SM58-like first, but keep others for debugging
            if isThermal || discoveredPeripherals.count < 8 {
                discoveredPeripherals.append(peripheral)
            }
        }

        // Auto-connect to the saved printer by advertised/local name.
        let savedName = Self.savedPrinterName
        if !savedName.isEmpty {
            let advName = advertisementData["kCBAdvDataLocalName"] as? String ?? ""
            let matches = advName.contains(savedName) || (peripheral.name?.contains(savedName) ?? false)
            if matches {
                connect(to: peripheral)
            }
        } else if lower.contains("sm58") || lower.contains("m58") {
            // Auto-prioritize SM58 if no saved name yet
            // Do not auto-connect without save, just surface in list
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        // Discover all services — VSC uses 49535343, SM58 uses FFE0/FF00
        peripheral.discoverServices(nil)
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
        // Try specific VSC service first, then generic fallback for SM58
        var foundSpecific = false
        for service in peripheral.services ?? [] where service.uuid == Self.bleServiceUUID {
            peripheral.discoverCharacteristics([Self.bleWriteUUID, Self.bleNotifyUUID], for: service)
            foundSpecific = true
        }
        if !foundSpecific {
            // SM58 generic: FFE0 / FF00 / 18F0 — discover all characteristics
            for service in peripheral.services ?? [] {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else { return }
        // Prefer specific VSC characteristic, fallback to any writable for SM58 (FFE1 etc)
        for char in service.characteristics ?? [] where char.uuid == Self.bleWriteUUID {
            writeCharacteristic = char
        }
        if writeCharacteristic == nil {
            // Generic SM58: first characteristic with .write or .writeWithoutResponse
            for char in service.characteristics ?? [] {
                if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                    writeCharacteristic = char
                    break
                }
            }
        }
        if writeCharacteristic != nil {
            stopScan()
        }

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
