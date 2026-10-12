import SwiftUI

struct OrderSummaryPopup: View {
    @ObservedObject var tab: OrderTab
    var onClose: () -> Void

    private var grouped: [CartGroup] {
        var groups: [Int: CartGroup] = [:]
        for item in tab.items {
            if var g = groups[item.productId] {
                g.items.append(item)
                groups[item.productId] = g
            } else {
                groups[item.productId] = CartGroup(productId: item.productId, productName: item.productName, items: [item])
            }
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "cart.fill").font(.system(size: 14)).foregroundColor(.white)
                Text("Order Summary").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Spacer()
                Text("\(tab.items.reduce(0){$0+$1.quantity}) items").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Color.white.opacity(0.15)).clipShape(Capsule())
                Button { onClose() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .frame(width: 32, height: 32).background(Color.white.opacity(0.15)).clipShape(Circle())
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).frame(height: 52).background(Color.posPrimaryGradient)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(grouped, id: \.productId) { group in
                        VStack(spacing: 0) {
                            HStack(spacing: 6) {
                                Image(systemName: "circle.fill").font(.system(size: 6)).foregroundColor(.posAccent)
                                Text(group.productName).font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                                Spacer()
                                Text("\(group.items.reduce(0){$0+$1.quantity}) items").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8).background(Color.posAccentSoft)
                            ForEach(group.items) { item in
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.skuName).font(.system(size: 13, weight: .semibold)).foregroundColor(.posTextPrimary).lineLimit(2)
                                        if !item.customizations.isEmpty {
                                            Text(item.customizations.map { $0.displayName }.joined(separator: " • "))
                                                .font(.system(size: 11)).foregroundColor(.posAccent).lineLimit(2)
                                        }
                                        Text("\(CurrencyUtils.formatRp(item.unitPrice)) × \(item.quantity)")
                                            .font(.system(size: 11)).foregroundColor(.posTextSecondary)
                                    }
                                    Spacer()
                                    Text(CurrencyUtils.formatRp(item.lineTotal)).font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color.posRowEven)
                                Divider().opacity(0.5)
                            }
                        }
                        .background(Color.posRowEven)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(12)
            }
            .background(Color.posBgLight)
            VStack(spacing: 6) {
                HStack { Text("Sub Total").font(.system(size: 13)).foregroundColor(.posTextSecondary); Spacer(); Text(CurrencyUtils.formatRp(tab.subtotal)).font(.system(size: 13, weight: .semibold)).foregroundColor(.posTextPrimary) }
                let d = Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0
                if d > 0 { HStack { Text("Discount").font(.system(size: 13)).foregroundColor(.posTextSecondary); Spacer(); Text(CurrencyUtils.formatRp(d)).font(.system(size: 13, weight: .semibold)).foregroundColor(.posStatusVoid) } }
                Divider()
                HStack { Text("Total").font(.system(size: 18, weight: .bold)).foregroundColor(.posPrimary); Spacer(); Text(CurrencyUtils.formatRp(max(0, tab.subtotal - d))).font(.system(size: 18, weight: .bold)).foregroundColor(.posPrimary) }
                if !tab.customer.isEmpty || !tab.remark.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if !tab.customer.isEmpty { HStack(spacing: 6) { Image(systemName: "person.fill").font(.system(size: 10)).foregroundColor(.posTextSecondary); Text(tab.customer).font(.system(size: 12)).foregroundColor(.posTextPrimary).lineLimit(1) } }
                        if !tab.remark.isEmpty { HStack(spacing: 6) { Image(systemName: "note.text").font(.system(size: 10)).foregroundColor(.posTextSecondary); Text(tab.remark).font(.system(size: 12)).foregroundColor(.posTextSecondary).lineLimit(2) } }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8).background(Color.posAccentSoft.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(14)
            .background(Color.posSurface)
            .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)

            Button("Close") { onClose() }
                .buttonStyle(PosButtonStyle(filled: true))
                .padding(12)
                .background(Color.white)
        }
        .frame(width: min(520, UIScreen.main.bounds.width - 32))
        .frame(maxHeight: min(620, UIScreen.main.bounds.height * 0.82))
        .background(Color.posSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
    }
}