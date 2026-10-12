import SwiftUI

// MARK: - CartGroup — logical grouping of CartItems by product

struct CartGroup {
    let productId: Int
    let productName: String
    var items: [CartItem]
}

// MARK: - CartRow — single row in the cart with +/- and trash buttons

struct CartRow: View {
    let item: CartItem
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let isSingle = item.quantity == 1
        return HStack(spacing: 2) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.skuName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.posTextPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !item.customizations.isEmpty {
                    Text(item.customizations.map { $0.displayName }.joined(separator: " • "))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.posAccent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: isSingle ? onDelete : onDecrement) {
                Image(systemName: isSingle ? "trash" : "minus")
                    .font(.system(size: isSingle ? 11 : 12, weight: .bold))
                    .foregroundColor(isSingle ? .white : .posStatusVoid)
                    .frame(width: 28, height: 28)
                    .background(isSingle ? Color.posStatusVoid : Color.posStatusVoid.opacity(0.08))
                    .clipShape(Circle())
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityLabel(isSingle ? "Delete" : "Decrease")

            Text("\(item.quantity)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.posTextPrimary)
                .frame(width: 24)
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: item.quantity)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.posAccent)
                    .clipShape(Circle())
                    .shadow(color: Color.posAccent.opacity(0.3), radius: 3, x: 0, y: 1)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            .accessibilityLabel("Increase")

            Text(CurrencyUtils.formatRp(item.lineTotal))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.posTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: 70, alignment: .trailing)

            if !isSingle {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.posStatusVoid)
                        .clipShape(Circle())
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .accessibilityLabel("Remove")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.001))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}