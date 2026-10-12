import SwiftUI

// MARK: - OrderListContent — loading / error / empty / list states for OrdersView

struct OrderListContent: View {
    let isLoading: Bool
    let error: String?
    let orders: [Order]
    let searchText: String
    let filterActive: Bool
    let width: CGFloat
    let onRetry: () -> Void
    let onSelect: (Order) -> Void
    let onClearFilters: () -> Void

    var body: some View {
        Group {
            if isLoading {
                skeletonList(width: width)
            } else if let error = error, !error.isEmpty {
                errorState(error: error)
            } else if orders.isEmpty {
                emptyState
            } else {
                orderList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.posBgLight)
    }

    private var orderList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(Array(orders.enumerated()), id: \.element.id) { index, order in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(order)
                    } label: {
                        OrderRow(order: order, width: width, isEven: index % 2 == 0)
                    }
                    .buttonStyle(OrderRowButtonStyle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(order.orderNoValue), \(order.statusValue), \(CurrencyUtils.formatRp(order.grandTotalValue))")
                    .accessibilityHint("Tap to view details")
                    .contextMenu {
                        Button { onSelect(order) } label: { Label("View Detail", systemImage: "eye") }
                        Button { UIPasteboard.general.string = order.orderNoValue } label: { Label("Copy Order No", systemImage: "doc.on.doc") }
                    }
                }
            }
            .padding(.vertical, 4)
            .animation(.easeOut(duration: 0.2), value: orders.count)
        }
        .refreshable { onRetry() }
    }

    private func skeletonList(width: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { i in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.posDivider.opacity(0.5)).frame(width: 4, height: 68)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.6)).frame(width: 120, height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.35)).frame(width: 90, height: 11)
                        }.frame(width: rel(2.2, width: width), alignment: .leading).padding(.leading, 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.4)).frame(width: 80, height: 12).frame(width: rel(1.4, width: width), alignment: .leading)
                        RoundedRectangle(cornerRadius: 6).fill(Color.posDivider.opacity(0.3)).frame(width: 60, height: 20).frame(width: rel(0.8, width: width), alignment: .leading)
                        RoundedRectangle(cornerRadius: 20).fill(Color.posDivider.opacity(0.3)).frame(width: 70, height: 22).frame(width: rel(0.9, width: width), alignment: .leading)
                        VStack(alignment: .trailing, spacing: 4) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.5)).frame(width: 90, height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.3)).frame(width: 60, height: 10)
                        }.frame(width: rel(1.1, width: width), alignment: .trailing).padding(.trailing, 8)
                        RoundedRectangle(cornerRadius: 20).fill(Color.posDivider.opacity(0.3)).frame(width: 70, height: 22).frame(width: rel(0.8, width: width), alignment: .leading)
                    }
                    .frame(height: 68)
                    .background(i % 2 == 0 ? Color.posRowEven : Color.posRowOdd)
                    .redacted(reason: .placeholder)
                }
            }
        }
    }

    private func errorState(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 32)).foregroundColor(.posStatusVoid)
            Text(error).font(.system(size: 14)).foregroundColor(.posTextSecondary).multilineTextAlignment(.center).padding(.horizontal, 24)
            Button("Retry") { onRetry() }
                .buttonStyle(PosButtonStyle(filled: true))
                .frame(width: 160)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.posAccentSoft).frame(width: 72, height: 72)
                Image(systemName: searchText.isEmpty && filterActive ? "tray" : "magnifyingglass")
                    .font(.system(size: 28)).foregroundColor(.posAccent)
            }
            Text(searchText.isEmpty && filterActive ? "No orders yet" : "No matching orders")
                .font(.system(size: 16, weight: .bold)).foregroundColor(.posTextPrimary)
            Text(searchText.isEmpty && filterActive ? "Orders for today will appear here" : "Try a different search or filter")
                .font(.system(size: 13)).foregroundColor(.posTextSecondary)
            if filterActive {
                Button("Clear filters") { onClearFilters() }
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.posPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.posBgLight)
    }

    private func rel(_ weight: CGFloat, width: CGFloat) -> CGFloat {
        let available = max(0, width - 40)
        let total: CGFloat = 2.2+1.4+0.8+0.9+1.1+0.8
        return weight / total * available
    }
}