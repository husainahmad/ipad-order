import SwiftUI

// MARK: - OrderFilterBar — filter chips + clear

struct OrderFilterBar: View {
    @Binding var selectedFilter: OrdersView.OrderFilter
    let orders: [Order]
    var onClear: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            ForEach(OrdersView.OrderFilter.allCases) { f in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { selectedFilter = f }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: f.icon).font(.system(size: 11, weight: .bold))
                        Text(f.rawValue).font(.system(size: 13, weight: .bold))
                        if f != .all {
                            Text("\(count(for: f))")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.white.opacity(selectedFilter == f ? 0.22 : 0.0))
                                .clipShape(Capsule())
                        }
                    }
                    .foregroundColor(selectedFilter == f ? .white : f.color)
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(selectedFilter == f ? f.color : Color.posRowEven)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(f.color.opacity(selectedFilter == f ? 0 : 0.35), lineWidth: 1))
                    .clipShape(Capsule())
                    .shadow(color: selectedFilter == f ? f.color.opacity(0.25) : Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                }.buttonStyle(.plain)
            }
            Spacer()
            if selectedFilter != .all {
                Button("Clear") {
                    withAnimation(.easeOut(duration: 0.2)) { selectedFilter = .all }
                    onClear()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.posTextSecondary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.posSurfaceContainer)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
    }

    private func count(for filter: OrdersView.OrderFilter) -> Int {
        orders.filter { filter.matches($0) }.count
    }
}