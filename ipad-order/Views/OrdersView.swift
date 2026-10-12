import SwiftUI

// MARK: - OrdersView — iPad Scannability Redesign
// Principles: Reduce 7 cols → 6, increase hierarchy, left status accent, right-aligned money,
// 68pt touch row, sticky header, filter chips + search, empty/loading skeletons.

struct OrdersView: View {
    @EnvironmentObject var ordersVM: OrdersViewModel
    @EnvironmentObject var session: AppSession

    @State private var selectedOrder: Order?
    @State private var showSalesReport = false
    @State private var showDailyReport = false
    @State private var showSettings = false
    @State private var showSettlement = false
    @State private var settlement: Settlement?

    @State private var searchText = ""
    @State private var selectedFilter: OrderFilter = .all
    @FocusState private var searchFocused: Bool

    // Scannability: search + filter
    enum OrderFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case paid = "Paid"
        case confirmed = "Confirmed"
        case void = "Void"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .all: return "list.bullet"
            case .paid: return "checkmark.circle.fill"
            case .confirmed: return "clock.fill"
            case .void: return "xmark.circle.fill"
            }
        }
        var color: Color {
            switch self {
            case .all: return .posPrimary
            case .paid: return .posStatusPaid
            case .confirmed: return .posStatusConfirmed
            case .void: return .posStatusVoid
            }
        }
        func matches(_ order: Order) -> Bool {
            switch self {
            case .all: return true
            case .paid: return order.isPaid
            case .confirmed: return order.isConfirmed
            case .void: return order.isVoid
            }
        }
    }

    // 6 cols optimized for iPad scan: Order(identity) | Customer | Payment | Status | Amount | Type
    private let columns: [(title: String, weight: CGFloat, alignment: Alignment)] = [
        ("Order", 2.2, .leading),
        ("Customer", 1.4, .leading),
        ("Payment", 0.8, .leading),
        ("Status", 0.9, .leading),
        ("Amount", 1.1, .trailing),
        ("Type", 0.8, .leading),
    ]

    private var filteredOrders: [Order] {
        ordersVM.orders.filter { order in
            guard selectedFilter.matches(order) else { return false }
            if searchText.isEmpty { return true }
            let q = searchText.lowercased()
            return order.orderNoValue.lowercased().contains(q)
                || order.customerNameValue.lowercased().contains(q)
                || order.paymentName.lowercased().contains(q)
        }
    }

    private var todaysTotal: Double {
        filteredOrders.filter { !$0.isVoid }.reduce(0) { $0 + $1.grandTotalValue }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                ordersHeader
                OrderFilterBar(selectedFilter: $selectedFilter, orders: ordersVM.orders) {
                    searchText = ""
                }
                columnHeader(width: geo.size.width)
                OrderListContent(
                    isLoading: ordersVM.loading && ordersVM.orders.isEmpty,
                    error: ordersVM.error,
                    orders: filteredOrders,
                    searchText: searchText,
                    filterActive: selectedFilter != .all || !searchText.isEmpty,
                    width: geo.size.width,
                    onRetry: { Task { await ordersVM.loadOrders() } },
                    onSelect: { selectedOrder = $0 },
                    onClearFilters: { selectedFilter = .all; searchText = "" }
                )
                footerButtons
            }
            .background(Color.posBgLight)
        }
        .sheet(item: $selectedOrder) { order in
            OrderDetailSheet(order: order)
        }
        .sheet(isPresented: $showSalesReport) { SalesReportView() }
        .sheet(isPresented: $showDailyReport) { DailyReportView() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showSettlement) {
            if let s = settlement { SettlementSheet(settlement: s) }
        }
        .onAppear { Task { await ordersVM.loadOrders() } }
        .dismissKeyboardOnTap()
    }

    // MARK: - Header (brand + summary + search)

    private var ordersHeader: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Orders")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(filteredOrders.count) shown • \(CurrencyUtils.formatRp(todaysTotal)) takings")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(searchFocused ? .posPrimary : .white.opacity(0.85))
                TextField("Search order, customer", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(.posTextPrimary)
                    .tint(.posPrimary)
                    .focused($searchFocused)
                    .submitLabel(.search)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.posTextSecondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(width: 300, height: 36)
            .background(Color.posRowEven.opacity(searchFocused ? 1 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant.opacity(searchFocused ? 0.8 : 0.3), lineWidth: 1))
            .animation(.easeInOut(duration: 0.15), value: searchFocused)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(Color.posPrimaryGradient)
    }

    // MARK: - Sticky column header

    private func columnHeader(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 4)
            ForEach(columns, id: \.title) { col in
                Text(col.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundColor(.posTextSecondary)
                    .frame(maxWidth: .infinity, alignment: col.alignment)
                    .frame(width: rel(col.weight, width: width))
            }
            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(Color.posSurfaceContainerHigh)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack(spacing: 8) {
            footerButton("Daily Report", icon: "calendar", color: .posPrimary) { showDailyReport = true }
            footerButton("Sales Report", icon: "chart.bar.fill", color: .posPrimary) { showSalesReport = true }
            footerButton("Settlement", icon: "banknote.fill", color: .posPrimary) { loadSettlement() }
            Divider().frame(height: 28).opacity(0.4)
            footerButton("Refresh", icon: "arrow.clockwise", color: .posTextPrimary, filled: false) {
                Task { await ordersVM.loadOrders() }
            }
            footerButton("Settings", icon: "gearshape.fill", color: .posTextPrimary, filled: false) { showSettings = true }
            Spacer().frame(width: 4)
            Button { session.logOut() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right").font(.system(size: 13, weight: .bold))
                    Text("Logout").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.posStatusVoid)
                .frame(height: 44).padding(.horizontal, 16)
                .background(Color.posStatusVoid.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posStatusVoid.opacity(0.25), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Color.posSurfaceContainerHigh)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -2)
    }

    private func footerButton(_ title: String, icon: String, color: Color, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(filled ? .white : color)
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(filled ? .white : .posTextPrimary).lineLimit(1)
            }
            .padding(.horizontal, 12).frame(height: 44)
            .background(filled ? AnyShapeStyle(Color.posPrimaryGradient) : AnyShapeStyle(Color.posRowEven))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(filled ? Color.clear : Color.posDivider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: filled ? Color.black.opacity(0.12) : Color.clear, radius: 4, x: 0, y: 2)
        }.buttonStyle(.plain)
    }

    private func rel(_ weight: CGFloat, width: CGFloat) -> CGFloat {
        let available = max(0, width - 40)
        let total: CGFloat = 2.2+1.4+0.8+0.9+1.1+0.8
        return weight / total * available
    }

    private func loadSettlement() {
        Task {
            if let s = await ordersVM.loadSettlement() {
                settlement = s; showSettlement = true
                PrinterManager.print(PrintUtils.buildSettlementPrintText(s)) { _ in }
            }
        }
    }
}

#Preview {
    OrdersView()
        .environmentObject(OrdersViewModel())
        .environmentObject(AppSession())
}