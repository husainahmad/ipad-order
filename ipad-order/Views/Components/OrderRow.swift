import SwiftUI

// MARK: - OrderRow — one scannable row in the Orders list

struct OrderRow: View {
    let order: Order
    let width: CGFloat
    let isEven: Bool

    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(statusColor).frame(width: 4).frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(order.orderNoValue)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.posTextPrimary)
                        .lineLimit(1)
                    if order.isPaid {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundColor(.posStatusPaid)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 10)).foregroundColor(.posTextSecondary)
                    Text(TimeUtils.toJakarta(order.createdAtValue))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.posTextSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: rel(2.2))
            .padding(.leading, 12)

            HStack(spacing: 6) {
                if !order.customerNameValue.isEmpty {
                    ZStack {
                        Circle().fill(Color.posAccentSoft).frame(width: 26, height: 26)
                        Text(String(order.customerNameValue.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.posAccent)
                    }
                } else {
                    ZStack {
                        Circle().fill(Color.posDivider.opacity(0.5)).frame(width: 26, height: 26)
                        Image(systemName: "person.fill").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                    }
                }
                Text(order.customerNameValue.isEmpty ? "—" : order.customerNameValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.posTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: rel(1.4))

            Text(order.paymentName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(paymentColor)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(paymentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(width: rel(0.8))

            HStack(spacing: 5) {
                Image(systemName: statusIcon).font(.system(size: 11, weight: .bold))
                Text(order.statusValue.uppercased()).font(.system(size: 11, weight: .bold)).lineLimit(1)
            }
            .foregroundColor(statusColor)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(statusColor.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(statusColor.opacity(0.22), lineWidth: 1))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: rel(0.9))

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyUtils.formatRp(order.grandTotalValue))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(order.isVoid ? .posTextSecondary : .posPrimary)
                    .strikethrough(order.isVoid)
                if order.discountTotalValue > 0 {
                    Text("-" + CurrencyUtils.formatRp(order.discountTotalValue))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.posStatusVoid)
                } else {
                    Text(CurrencyUtils.formatRp(order.subTotalValue))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.posTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(width: rel(1.1))
            .padding(.trailing, 8)

            HStack(spacing: 4) {
                Image(systemName: order.storeServiceTypesId == 3 ? "takeoutbag.and.cup.and.straw" : "fork.knife")
                    .font(.system(size: 10, weight: .bold))
                Text(order.storeServiceTypesId == 3 ? "TAKE" : "DINE")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(typeColor)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(typeColor.opacity(0.12))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: rel(0.8))

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.posTextSecondary.opacity(0.6))
                .frame(width: 24)
        }
        .frame(height: 68)
        .background(isEven ? Color.posRowEven : Color.posRowOdd)
        .overlay(Rectangle().fill(Color.posDivider.opacity(0.5)).frame(height: 1), alignment: .bottom)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        if order.isPaid { return .posStatusPaid }
        if order.isVoid { return .posStatusVoid }
        return .posStatusConfirmed
    }
    private var statusIcon: String {
        if order.isPaid { return "checkmark.circle.fill" }
        if order.isVoid { return "xmark.circle.fill" }
        return "clock.fill"
    }
    private var paymentColor: Color {
        switch order.paymentName {
        case "CASH": return .posStatusConfirmed
        case "QR": return .posBlueAction
        case "CARD": return .posPrimary
        default: return .posTextSecondary
        }
    }
    private var typeColor: Color {
        order.storeServiceTypesId == 3 ? .posStatusConfirmed : .posPrimary
    }
    private func rel(_ weight: CGFloat) -> CGFloat {
        let total: CGFloat = 2.2+1.4+0.8+0.9+1.1+0.8
        let available = max(0, width - 40)
        return weight / total * available
    }
}

struct OrderRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.posPrimary.opacity(0.08) : Color.clear)
            .scaleEffect(configuration.isPressed ? 0.998 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}