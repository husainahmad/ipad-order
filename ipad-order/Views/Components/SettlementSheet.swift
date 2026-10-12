import SwiftUI

struct SettlementSheet: View {
    @Environment(\.dismiss) var dismiss
    let settlement: Settlement
    @State private var printStatus: String?
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "banknote.fill").font(.system(size: 18)).foregroundColor(.posPrimary)
                Text("Settlement").font(.system(size: 20, weight: .bold)).foregroundColor(.posTextPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.posTextSecondary)
                        .frame(width: 30, height: 30).background(Color.posBgLight).clipShape(Circle())
                }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text").font(.system(size: 13)).foregroundColor(.posPrimary)
                    Text("Preview").font(.system(size: 14, weight: .bold)).foregroundColor(.posPrimary)
                    Spacer()
                }.padding(12).background(Color.posAccentSoft)
                ScrollView {
                    Text(PrintUtils.buildSettlementDialogText(settlement))
                        .font(.system(size: 14, design: .monospaced)).foregroundColor(.posTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                }
            }
            .background(Color.posSurface).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
            .frame(maxHeight: .infinity)
            if let s = printStatus { Text(s).font(.system(size: 13)).foregroundColor(.posTextSecondary) }
            HStack(spacing: 8) {
                Button("Print") { printSettlement() }.buttonStyle(PosButtonStyle(filled: true))
                Button("Close") { dismiss() }.buttonStyle(PosButtonStyle(filled: false))
            }
        }
        .padding(16).background(Color.posBgLight).frame(minWidth: 560, minHeight: 440)
    }
    private func printSettlement() {
        printStatus = "Printing..."
        PrinterManager.print(PrintUtils.buildSettlementPrintText(settlement)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success: printStatus = "Print sent to printer"
                case .failure(let e): printStatus = "Print failed: \(e.localizedDescription)"
                }
            }
        }
    }
}