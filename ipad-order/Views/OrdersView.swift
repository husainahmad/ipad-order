import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var ordersVM: OrdersViewModel
    @EnvironmentObject var session: AppSession

    @State private var selectedOrder: Order?
    @State private var showSalesReport = false
    @State private var showDailyReport = false
    @State private var showSettings = false
    @State private var showSettlement = false
    @State private var settlement: Settlement?

    private let columns: [(String, CGFloat)] = [
        ("Order No", 1.2),
        ("Date", 1.3),
        ("Customer", 1.2),
        ("Payment", 0.7),
        ("Status", 0.8),
        ("Sub Total", 0.9),
        ("Discount", 0.8),
        ("Total", 1.0),
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ordersHeader
                headerRow(width: geo.size.width)
                if ordersVM.loading {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = ordersVM.error, !error.isEmpty, ordersVM.orders.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.posStatusVoid)
                        Text(error)
                            .foregroundColor(.posStatusVoid)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    orderList(width: geo.size.width)
                }
                footerButtons
            }
            .background(Color.posBgLight)
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailSheet(order: order)
        }
        .sheet(isPresented: $showSalesReport) {
            SalesReportView()
        }
        .sheet(isPresented: $showDailyReport) {
            DailyReportView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSettlement) {
            if let settlement = settlement {
                SettlementSheet(settlement: settlement)
            }
        }
        .onAppear {
            Task { await ordersVM.loadOrders() }
        }
    }

    private var ordersHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            Text("Orders")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Text("\(ordersVM.orders.count) orders")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.posPrimaryGradient)
    }

    private func headerRow(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(columns, id: \.0) { column in
                Text(column.0)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(width: relativeWidth(column.1, of: width))
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 46)
        .background(Color.posSurfaceContainer)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
    }

    private func orderList(width: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(ordersVM.orders.enumerated()), id: \.element.id) { index, order in
                    Button {
                        selectedOrder = order
                    } label: {
                        OrderRow(order: order, isEven: index % 2 == 0, width: width)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 10) {
            footerButton("Daily Report", icon: "calendar") { showDailyReport = true }
            footerButton("Sales Report", icon: "chart.bar.fill") { showSalesReport = true }
            footerButton("Settlement", icon: "banknote") { loadSettlement() }
            footerButton("Refresh", icon: "arrow.clockwise") {
                Task { await ordersVM.loadOrders() }
            }
            footerButton("Settings", icon: "gearshape.fill") { showSettings = true }
            footerButton("Logout", icon: "rectangle.portrait.and.arrow.right", destructive: true) { session.logOut() }
        }
        .padding(12)
        .background(Color.posSurfaceContainerHigh)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -2)
    }

    private func footerButton(_ title: String, icon: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(destructive ? .posStatusVoid : .posPrimary)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(destructive ? .posStatusVoid : .posTextPrimary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(destructive ? Color.posStatusVoid.opacity(0.06) : Color.posBgLight)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(destructive ? Color.posStatusVoid.opacity(0.35) : Color.posDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func relativeWidth(_ weight: CGFloat, of width: CGFloat) -> CGFloat {
        let total = columns.reduce(0) { $0 + $1.1 }
        return weight / total * width
    }

    private func loadSettlement() {
        Task {
            settlement = await ordersVM.loadSettlement()
            showSettlement = settlement != nil
        }
    }
}

private struct OrderRow: View {
    let order: Order
    let isEven: Bool
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text(order.orderNoValue)
                .fontWeight(.semibold)
                .foregroundColor(.posPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(1.2))
            Text(TimeUtils.toJakarta(order.createdAtValue))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(1.3))
            Text(order.customerNameValue.isEmpty ? "-" : order.customerNameValue)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(1.2))
            Text(order.paymentName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(0.7))
            Text(order.statusValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(0.8))
            Text(CurrencyUtils.formatRp(order.subTotalValue))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(0.9))
            Text(CurrencyUtils.formatRp(order.discountTotalValue))
                .foregroundColor(.posStatusVoid)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(0.8))
            Text(CurrencyUtils.formatRp(order.grandTotalValue))
                .fontWeight(.bold)
                .foregroundColor(.posPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(1.0))
        }
        .font(.system(size: 13))
        .foregroundColor(.posTextPrimary)
        .padding(.horizontal, 8)
        .frame(height: 56)
        .background(isEven ? Color.white : Color.posRowOdd)
    }

    private var statusColor: Color {
        if order.isPaid { return .posStatusPaid }
        if order.isVoid { return .posStatusVoid }
        return .posStatusConfirmed
    }

    private func rel(_ weight: CGFloat) -> CGFloat {
        weight / 7.9 * width
    }
}

struct SettlementSheet: View {
    @Environment(\.dismiss) var dismiss
    let settlement: Settlement

    @State private var printStatus: String?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.posPrimary)
                Text("Settlement")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                        .foregroundColor(.posPrimary)
                    Text("Preview")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.posPrimary)
                    Spacer()
                }
                .padding(12)
                .background(Color.posAccentSoft)

                ScrollView {
                    Text(PrintUtils.buildSettlementDialogText(settlement))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.posTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
            .frame(maxHeight: .infinity)

            if let status = printStatus {
                Text(status)
                    .font(.system(size: 13))
                    .foregroundColor(.posTextSecondary)
            }

            HStack(spacing: 8) {
                Button("Print") {
                    printSettlement()
                }
                .buttonStyle(PosButtonStyle(filled: true))

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(PosButtonStyle(filled: false))
            }
        }
        .padding(16)
        .background(Color.posBgLight)
        .frame(minWidth: 600, minHeight: 460)
    }

    private func printSettlement() {
        printStatus = "Printing..."
        PrinterManager.print(PrintUtils.buildSettlementPrintText(settlement)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    printStatus = "Print sent to printer"
                case .failure(let error):
                    printStatus = "Print failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct PosButtonStyle: ButtonStyle {
    let filled: Bool
    var outlineColor: Color = .posGrayButton

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(filled ? .white : .posTextPrimary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(filled ? AnyShapeStyle(Color.posAccentGradient) : AnyShapeStyle(Color.posSurfaceContainerHigh))
            .overlay(
                RoundedRectangle(cornerRadius: PosShape.cornerMedium)
                    .stroke(filled ? Color.clear : outlineColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
            .shadow(color: filled ? Color.posAccent.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    OrdersView()
        .environmentObject(OrdersViewModel())
        .environmentObject(AppSession())
}
