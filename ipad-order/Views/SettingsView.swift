import SwiftUI
import CoreBluetooth

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: AppSession

    @State private var serverHost = ConfigManager.host
    @State private var serverPort = String(ConfigManager.port)
    @State private var serverStatus = ""

    @State private var printerType = PrinterManager.type
    @State private var printerAddress = PrinterManager.address
    @State private var printerPort = String(PrinterManager.port)
    @State private var printerStatus = ""

    @ObservedObject private var printerManager = PrinterManager.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    userInfo

                    serverCard
                    printerCard

                    Button {
                        session.logOut()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                        }
                        .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posStatusVoid))
                }
                .padding(16)
            }
        }
        .background(Color.posBgLight)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                Text("Settings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.posPrimaryGradient)
    }

    private var userInfo: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.posPrimaryGradient)
                    .frame(width: 52, height: 52)
                Text(String(TokenManager.username.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(TokenManager.username)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                Text("Store : \(TokenManager.storeName)")
                    .font(.system(size: 14))
                    .foregroundColor(.posTextSecondary)
                Text("Brand : \(TokenManager.brandName)")
                    .font(.system(size: 14))
                    .foregroundColor(.posTextSecondary)
            }
            Spacer()
        }
        .posCard()
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.system(size: 16))
                    .foregroundColor(.posPrimary)
                Text("Server")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.posPrimary)
            }

            HStack(spacing: 10) {
                Image(systemName: "network")
                    .font(.system(size: 14))
                    .foregroundColor(.posTextSecondary)
                TextField("Host (e.g. 103.150.197.7)", text: $serverHost)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.posBgLight)
            .cornerRadius(10)

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .font(.system(size: 14))
                    .foregroundColor(.posTextSecondary)
                TextField("Port (default 8080)", text: $serverPort)
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Color.posBgLight)
            .cornerRadius(10)

            Button("Save Server") {
                saveServer()
            }
            .buttonStyle(PosButtonStyle(filled: true))

            if !serverStatus.isEmpty {
                Text(serverStatus)
                    .font(.system(size: 13))
                    .foregroundColor(.posStatusPaid)
            }
        }
        .posCard()
    }

    private var printerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.posPrimary)
                Text("Printer")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.posPrimary)
                Spacer()
                Picker("", selection: $printerType) {
                    Text("Network").tag(PrinterManager.typeNetwork)
                    Text("Bluetooth").tag(PrinterManager.typeBluetooth)
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            if printerType == PrinterManager.typeBluetooth {
                bluetoothPrinterContent
            } else {
                networkPrinterContent
            }
        }
        .posCard()
        .onAppear {
            printerType = PrinterManager.type
        }
        .onChange(of: printerType) { newType in
            PrinterManager.save(type: newType,
                                address: PrinterManager.address,
                                port: PrinterManager.port,
                                name: PrinterManager.savedPrinterName)
        }
    }

    @ViewBuilder
    private var bluetoothPrinterContent: some View {
        // Bluetooth state / status row
        HStack(spacing: 8) {
            Circle()
                .fill(bluetoothStateColor)
                .frame(width: 10, height: 10)
            Text(bluetoothStateText)
                .font(.system(size: 13))
                .foregroundColor(.posTextSecondary)
            Spacer()
        }

        if let peripheral = printerManager.connectedPeripheral {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.posStatusPaid)
                Text(peripheral.name ?? "Printer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.posTextPrimary)
                Spacer()
                Button("Disconnect") {
                    printerManager.disconnect()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.posStatusVoid)
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.posBgLight)
            .cornerRadius(10)
        }

        if printerManager.isScanning {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning for printers...")
                    .font(.system(size: 13))
                    .foregroundColor(.posTextSecondary)
            }
        }

        if !printerManager.discoveredPeripherals.isEmpty {
            VStack(spacing: 8) {
                ForEach(printerManager.discoveredPeripherals, id: \.identifier) { peripheral in
                    Button {
                        connectBluetooth(to: peripheral)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.posPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(peripheral.name ?? "Unknown printer")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.posTextPrimary)
                                Text(peripheral.identifier.uuidString)
                                    .font(.system(size: 11))
                                    .foregroundColor(.posTextSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if printerManager.connectedPeripheral?.identifier == peripheral.identifier {
                                Image(systemName: "link")
                                    .font(.system(size: 13))
                                    .foregroundColor(.posStatusPaid)
                            }
                        }
                        .padding(12)
                        .background(Color.posBgLight)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        HStack(spacing: 10) {
            Button {
                if printerManager.isScanning {
                    printerManager.stopScan()
                } else {
                    printerManager.startScan()
                }
            } label: {
                Text(printerManager.isScanning ? "Stop Scan" : "Scan for Printers")
            }
            .buttonStyle(PosButtonStyle(filled: true))

            Button("Test Print") {
                testPrint()
            }
            .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posBlueAction))
        }

        if !printerStatus.isEmpty {
            Text(printerStatus)
                .font(.system(size: 13))
                .foregroundColor(.posStatusPaid)
        }

        Label("Bluetooth mode works with ESC/POS thermal printers that expose a BLE service (e.g. VSC TM-58D PRO).",
              systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundColor(.posTextSecondary)
    }

    @ViewBuilder
    private var networkPrinterContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundColor(.posTextSecondary)
            TextField("Address (IP)", text: $printerAddress)
                .keyboardType(.numbersAndPunctuation)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.posBgLight)
        .cornerRadius(10)

        HStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 14))
                .foregroundColor(.posTextSecondary)
            TextField("Port (network, default 9100)", text: $printerPort)
                .keyboardType(.numberPad)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Color.posBgLight)
        .cornerRadius(10)

        HStack(spacing: 10) {
            Button("Save Printer") {
                savePrinter()
            }
            .buttonStyle(PosButtonStyle(filled: true))

            Button("Test Print") {
                testPrint()
            }
            .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posBlueAction))
        }

        if !printerStatus.isEmpty {
            Text(printerStatus)
                .font(.system(size: 13))
                .foregroundColor(.posStatusPaid)
        }

        Label("On iPad, only network (TCP/IP) ESC/POS thermal printers are supported.",
              systemImage: "info.circle")
            .font(.system(size: 12))
            .foregroundColor(.posTextSecondary)
    }

    private var bluetoothStateColor: Color {
        switch printerManager.bluetoothState {
        case .poweredOn: return .posStatusPaid
        case .poweredOff, .unsupported: return .posStatusVoid
        default: return .posStatusConfirmed
        }
    }

    private var bluetoothStateText: String {
        switch printerManager.bluetoothState {
        case .poweredOn:
            return printerManager.connectedPeripheral != nil
                ? "Bluetooth ready"
                : "Bluetooth ready - scan to pair"
        case .poweredOff:
            return "Bluetooth is off. Turn it on in Settings."
        case .unauthorized:
            return "Bluetooth access denied. Allow in Settings > Privacy."
        case .unsupported:
            return "Bluetooth is not supported on this device."
        default:
            return "Bluetooth unavailable"
        }
    }

    private func connectBluetooth(to peripheral: CBPeripheral) {
        printerStatus = "Connecting to \(peripheral.name ?? "printer")..."
        printerManager.connect(to: peripheral)
        PrinterManager.save(type: PrinterManager.typeBluetooth,
                            address: PrinterManager.address,
                            port: PrinterManager.port,
                            name: peripheral.name ?? "")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if printerManager.connectedPeripheral?.identifier == peripheral.identifier {
                printerStatus = "Connected to \(peripheral.name ?? "printer")"
            } else {
                printerStatus = "Connecting... (make sure printer is on)"
            }
        }
    }

    private func saveServer() {
        let port = Int(serverPort) ?? 8080
        ConfigManager.save(host: serverHost, port: port)
        APIClient.shared.reset()
        serverStatus = "Saved. Server: \(ConfigManager.baseOrder)"
    }

    private func savePrinter() {
        let port = Int(printerPort) ?? 9100
        PrinterManager.save(type: printerType,
                            address: printerAddress,
                            port: port,
                            name: PrinterManager.savedPrinterName)
        printerStatus = printerType == PrinterManager.typeBluetooth
            ? "Bluetooth printer saved"
            : "Printer saved: network"
    }

    private func testPrint() {
        savePrinter()
        printerStatus = "Printing..."
        let text = "KOPI HARMONI\n"
            + "----------------------------\n"
            + "TEST PRINT\n"
            + "Printer: \(printerType)\n"
            + "----------------------------\n"
            + "Terima kasih\n"
        PrinterManager.print(text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    printerStatus = "Print sent successfully"
                case .failure(let error):
                    printerStatus = "Print failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSession())
}
