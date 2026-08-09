import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: AppSession

    @State private var serverHost = ConfigManager.host
    @State private var serverPort = String(ConfigManager.port)
    @State private var serverStatus = ""

    @State private var printerAddress = PrinterManager.address
    @State private var printerPort = String(PrinterManager.port)
    @State private var printerStatus = ""

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
                Text("Network (TCP/IP)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.posPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.posAccentSoft)
                    .clipShape(Capsule())
            }

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
        .posCard()
    }

    private func saveServer() {
        let port = Int(serverPort) ?? 8080
        ConfigManager.save(host: serverHost, port: port)
        APIClient.shared.reset()
        serverStatus = "Saved. Server: \(ConfigManager.baseOrder)"
    }

    private func savePrinter() {
        let port = Int(printerPort) ?? 9100
        PrinterManager.save(type: PrinterManager.typeNetwork, address: printerAddress, port: port)
        printerStatus = "Printer saved: network"
    }

    private func testPrint() {
        savePrinter()
        printerStatus = "Printing..."
        let text = "KOPI HARMONI\n"
            + "----------------------------\n"
            + "TEST PRINT\n"
            + "Printer: network\n"
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
