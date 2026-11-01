import SwiftUI
import UIKit

// MARK: - OrderConfirmPopup (compact iPad Landscape POS dialog)
// Centered dialog ~920pt wide, two columns, height = content.
// No .sheet, no GeometryReader width, single white surface (no outer cream nesting).

struct OrderConfirmPopup: View {
    @EnvironmentObject var formVM: OrderFormViewModel
    @EnvironmentObject var toastManager: ToastManager
    @ObservedObject var tab: OrderTab
    let existingOrder: Order?
    let onSuccess: (() -> Void)?
    var onClose: () -> Void

    @State private var selectedPayment = 1
    @State private var cashReceived = 0.0
    @State private var statusMessage: String?
    @State private var working = false

    private let denominations: [Double] = [1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000]

    private var isCartMode: Bool { existingOrder == nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 12) {
                                if isCartMode { inputsBox }
                                orderSummaryBox
                                totalsBox
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 12) {
                                paymentSection
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(12)
                    }
                    .background(Color.posSurface)
                    footer
                }
                .disabled(working)
                .opacity(working ? 0.45 : 1)
                .animation(.easeInOut(duration: 0.2), value: working)

                if working {
                    ZStack {
                        Color.posSurface.opacity(0.82)
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .tint(.posAccent)
                            Text("Processing payment...")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.posTextPrimary)
                            Text("Please wait")
                                .font(.system(size: 13))
                                .foregroundColor(.posTextSecondary)
                        }
                        .padding(24)
                        .background(Color.posSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.posDivider, lineWidth: 1))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
        .frame(width: min(920, UIScreen.main.bounds.width - 32))
        .frame(height: min(680, UIScreen.main.bounds.height * 0.86))
        .background(Color.posSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.2), value: working)
        .dismissKeyboardOnTap()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isCartMode ? "Confirm Order & Payment" : "Payment").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text(isCartMode ? "Review your order and choose a payment method" : "Order #\(existingOrder?.orderNoValue ?? "")")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 36, height: 36).background(Color.white.opacity(0.15)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.posPrimaryGradient)
    }

    private var orderSummaryBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Order Summary").font(.system(size: 18, weight: .bold)).foregroundColor(.posPrimary)
                Spacer()
                Text("\(totalItemCount) item(s)").font(.system(size: 14, weight: .bold)).foregroundColor(.posAccent)
            }
            VStack(spacing: 0) {
                ForEach(displayGroups) { group in
                    Text(group.productName).font(.system(size: 14, weight: .bold)).foregroundColor(.posPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 7).background(Color.posRowOdd)
                    ForEach(group.lines) { line in ConfirmLineRow(line: line) }
                }
            }
            .background(Color.posRowEven)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.posDivider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12).background(Color.posBgLight).cornerRadius(8)
    }

    private var totalsBox: some View {
        VStack(spacing: 6) {
            HStack { Text("Sub Total").font(.system(size: 14)).foregroundColor(.posTextPrimary); Spacer()
                Text(CurrencyUtils.formatRp(subTotalValue)).font(.system(size: 14, weight: .bold)).foregroundColor(.posTextPrimary) }
            HStack { Text("Discount").font(.system(size: 14)).foregroundColor(.posTextPrimary); Spacer()
                Text(CurrencyUtils.formatRp2(discountValue)).font(.system(size: 14, weight: .bold)).foregroundColor(.posStatusVoid) }
            Divider()
            HStack { Text("Total").font(.system(size: 20, weight: .bold)).foregroundColor(.posPrimary); Spacer()
                Text(CurrencyUtils.formatRp(totalValue)).font(.system(size: 20, weight: .bold)).foregroundColor(.posPrimary) }
        }.padding(16).background(Color.posBgLight).cornerRadius(8)
    }

    private var inputsBox: some View {
        VStack(spacing: 12) {
            Text("Order Details").font(.system(size: 16, weight: .bold)).foregroundColor(.posPrimary).frame(maxWidth: .infinity, alignment: .leading)
            // 4: Service type cart-primary — read-only badge here, edit in cart
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "fork.knife").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                    Text("Service").font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
                    Spacer()
                    Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onClose() } label: {
                        HStack(spacing: 4) { Image(systemName: "pencil").font(.system(size: 11, weight: .semibold)); Text("Edit in cart").font(.system(size: 11, weight: .semibold)) }.foregroundColor(.posPrimary)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Image(systemName: tab.storeServiceTypesId == 3 ? "takeoutbag.and.cup.and.straw" : "fork.knife").font(.system(size: 13)).foregroundColor(tab.storeServiceTypesId == 3 ? .posStatusConfirmed : .posPrimary)
                    Text(tab.storeServiceTypesId == 3 ? "TAKE AWAY" : "DINE IN").font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.posAccent)
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.posAccentSoft)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posAccent.opacity(0.6), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            // 1: Customer inline primary — read-only preview here
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                    Text("Customer").font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
                    Spacer()
                    Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onClose() } label: {
                        HStack(spacing: 4) { Image(systemName: "pencil").font(.system(size: 11, weight: .semibold)); Text("Edit in cart").font(.system(size: 11, weight: .semibold)) }.foregroundColor(.posPrimary)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Image(systemName: "person.fill").font(.system(size: 13)).foregroundColor(tab.customer.isEmpty ? .posTextSecondary.opacity(0.6) : .posPrimary)
                    Text(tab.customer.isEmpty ? "Walk-in" : tab.customer)
                        .font(.system(size: 13, weight: tab.customer.isEmpty ? .regular : .semibold))
                        .foregroundColor(tab.customer.isEmpty ? .posTextSecondary.opacity(0.7) : .posTextPrimary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.posRowEven)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            // 8: Discount inline primary — read-only preview here
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                    Text("Discount").font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
                    Spacer()
                    Button { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onClose() } label: {
                        HStack(spacing: 4) { Image(systemName: "pencil").font(.system(size: 11, weight: .semibold)); Text("Edit in cart").font(.system(size: 11, weight: .semibold)) }.foregroundColor(.posPrimary)
                    }.buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Text("Rp.").font(.system(size: 14, weight: .semibold)).foregroundColor(.posTextSecondary)
                    Text(discountValue > 0 ? CurrencyUtils.formatRp(discountValue).replacingOccurrences(of: "Rp.", with: "") : "0")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(discountValue > 0 ? .posStatusVoid : .posTextSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.posRowEven)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                if discountValue > 0 {
                    Text("Discount applied from cart").font(.system(size: 11)).foregroundColor(.posStatusVoid)
                }
            }
            // Remark now primary in cart rail (OrderFormView:269) — show read-only preview here
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 11))
                        .foregroundColor(.posTextSecondary)
                    Text("Note").font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onClose()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil").font(.system(size: 11, weight: .semibold))
                            Text("Edit in cart").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.posPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit note in cart")
                }
                HStack(alignment: .top, spacing: 8) {
                    Text(tab.remark.isEmpty ? "No notes" : tab.remark)
                        .font(.system(size: 13, weight: tab.remark.isEmpty ? .regular : .medium))
                        .foregroundColor(tab.remark.isEmpty ? .posTextSecondary.opacity(0.7) : .posTextPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44, alignment: .leading)
                .background(Color.posRowEven)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                Text("Add or edit notes from the cart before confirming").font(.system(size: 11)).foregroundColor(.posTextSecondary)
            }
        }.padding(16).background(Color.posBgLight).cornerRadius(8)
    }

    private func confirmTypeCard(title: String, icon: String, id: Int) -> some View {
        let selected = tab.storeServiceTypesId == id
        return Button { tab.storeServiceTypesId = id } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(selected ? .posAccent : .posGrayButton)
                Text(title).font(.system(size: 14, weight: selected ? .bold : .regular)).foregroundColor(selected ? .posTextPrimary : .posTextSecondary)
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.posAccent) }
            }.padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.posAccentSoft : Color.posBgLight)
                .overlay(RoundedRectangle(cornerRadius: PosShape.cornerMedium).stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
        }.buttonStyle(.plain)
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Payment Method").font(.system(size: 18, weight: .bold)).foregroundColor(.posPrimary)
                Spacer()
                Text("Total : \(CurrencyUtils.formatRp(totalValue))").font(.system(size: 13, weight: .bold)).foregroundColor(.posTextSecondary)
            }
            paymentSelector
            Group {
                if selectedPayment == 1 { cashPanel } else {
                    Color.clear.frame(height: 230).overlay(Text(selectedPayment == 2 ? "Scan QR Code" : "Tap card on reader").font(.system(size: 12)).foregroundColor(.posTextSecondary))
                }
            }.frame(height: 230).animation(.easeInOut(duration: 0.15), value: selectedPayment)
            if let status = statusMessage { Text(status).font(.system(size: 13)).foregroundColor(.posStatusVoid).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(16).background(Color.posBgLight).cornerRadius(8)
    }

    private var paymentSelector: some View {
        HStack(spacing: 12) {
            paymentCard(title: "Scan QR Code", icon: "qrcode", id: 2)
            paymentCard(title: "Pay by Card", icon: "creditcard", id: 3)
            paymentCard(title: "Cash", icon: "banknote", id: 1)
        }
    }

    private func paymentCard(title: String, icon: String, id: Int) -> some View {
        let selected = selectedPayment == id
        return Button { selectedPayment = id; if id == 1 { cashReceived = 0 } } label: {
            VStack(spacing: 8) {
                ZStack { Circle().fill(selected ? Color.posAccentSoft : Color.posBgLight).frame(width: 52, height: 52)
                    Image(systemName: icon).font(.system(size: 24)).foregroundColor(selected ? .posAccent : .posGrayButton) }
                Text(title).font(.system(size: 13, weight: selected ? .bold : .regular)).foregroundColor(selected ? .posPrimaryDark : .posTextSecondary)
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.posAccent) }
            }.frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(selected ? Color.posRowEven : Color.posBgLight)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: selected ? Color.posAccent.opacity(0.2) : Color.clear, radius: 6, x: 0, y: 2)
        }.buttonStyle(.plain)
    }

    private var cashPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(denominations, id: \.self) { amount in
                            Button { cashReceived += amount; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                                Text(CurrencyUtils.formatRp(amount).replacingOccurrences(of: "Rp.", with: "").trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44).background(Color.posRowEven)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posDivider, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 4) {
                        Button("CLEAR") { cashReceived = 0 }.buttonStyle(PosButtonStyle(filled: false, outlineColor: .posStatusVoid))
                        Button("EXACT") { cashReceived = totalValue }.buttonStyle(PosButtonStyle(filled: true))
                    }
                    .padding(.top, 8)
                }.frame(maxWidth: .infinity).frame(minWidth: 260)
                VStack(alignment: .leading, spacing: 6) {
                    Text("UANG DITERIMA").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                    Text(CurrencyUtils.formatRp(cashReceived)).font(.system(size: 14, weight: .bold)).foregroundColor(.posTextPrimary)
                    Text("KEMBALIAN").font(.system(size: 11)).foregroundColor(.posTextSecondary).padding(.top, 8)
                    Text(CurrencyUtils.formatRp(change)).font(.system(size: 14, weight: .bold)).foregroundColor(.posAccent)
                }.frame(width: 120)
            }
        }.padding(10).background(Color.posRowOdd).cornerRadius(8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Cancel") { onClose() }.buttonStyle(PosButtonStyle(filled: false))
            Spacer()
            Button("Pay") { pay() }.buttonStyle(PosButtonStyle(filled: true)).disabled(working)
        }.padding(12).background(Color.posSurface).overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
    }

    private var displayGroups: [DisplayGroup] {
        isCartMode ? cartGroups : orderGroups
    }
    private var cartGroups: [DisplayGroup] {
        var groups: [String: DisplayGroup] = [:]
        for item in tab.items {
            let line = ConfirmLine(id: item.lineKey,
                                   skuName: item.skuName,
                                   options: item.customizations.map { $0.displayName }.joined(separator: " • "),
                                   price: item.unitPrice,
                                   quantity: item.quantity,
                                   lineTotal: item.lineTotal)
            if var g = groups[item.productName] { g.lines.append(line); groups[item.productName] = g }
            else { groups[item.productName] = DisplayGroup(productName: item.productName, lines: [line]) }
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }
    private var orderGroups: [DisplayGroup] {
        var groups: [String: DisplayGroup] = [:]
        for detail in existingOrder?.orderDetails ?? [] {
            let name = detail.productName ?? ""
            var group = groups[name] ?? DisplayGroup(productName: name, lines: [])
            // Choices belong to the product line, so every SKU row under it shows them.
            let options = detail.groupedCustomizationNames
            for sku in detail.orderDetailSkus ?? [] {
                group.lines.append(ConfirmLine(id: "\(name)-\(sku.skuName ?? "")-\(options)",
                                    skuName: sku.skuName ?? "",
                                    options: options,
                                   price: sku.priceValue,
                                   quantity: Int(sku.quantityValue),
                                   lineTotal: sku.amountValue))
            }
            groups[name] = group
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }
    private var totalItemCount: Int {
        isCartMode ? tab.items.reduce(0) { $0 + $1.quantity } : (existingOrder?.orderDetails ?? []).reduce(0) { $0 + ($1.orderDetailSkus ?? []).reduce(0) { $0 + Int($1.quantityValue) } }
    }
    private var subTotalValue: Double { isCartMode ? tab.subtotal : existingOrder?.subTotalValue ?? 0 }
    private var discountValue: Double { isCartMode ? Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0 : existingOrder?.discountTotalValue ?? 0 }
    private var totalValue: Double { isCartMode ? max(0, subTotalValue - discountValue) : existingOrder?.grandTotalValue ?? 0 }
    private var change: Double { max(0, cashReceived - totalValue) }
    private var discountBinding: Binding<String> {
        Binding(get: { tab.discount }, set: { tab.discount = CurrencyUtils.formatWholeInput($0) })
    }

    private func pay() {
        if selectedPayment == 1, cashReceived < totalValue {
            statusMessage = "Insufficient cash entered!"
            toastManager.show("Insufficient cash entered!", style: .error)
            return
        }
        guard let orderToPay = existingOrder ?? formVM.confirmedOrder else {
            statusMessage = "No confirmed order to pay"
            toastManager.show("No confirmed order", style: .error)
            return
        }
        statusMessage = nil
        withAnimation(.easeInOut(duration: 0.2)) { working = true }
        Task {
            do {
                let request = PaymentRequest(orderId: orderToPay.id, paymentId: selectedPayment)
                let paidOrder = try await APIClient.shared.payOrder(request)
                PrinterManager.print(PrintUtils.buildReceiptText(paidOrder)) { _ in }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { working = false }
                    toastManager.show("Payment successful", style: .success)
                    onClose()
                    if isCartMode {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            _ = formVM.removeActiveTab()
                        }
                    } else {
                        onSuccess?()
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { working = false }
                    let msg = "Payment failed: \(error.localizedDescription)"
                    statusMessage = msg
                    toastManager.show(msg, style: .error)
                }
            }
        }
    }
}

private struct ConfirmLineRow: View {
    let line: ConfirmLine
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.skuName).font(.system(size: 13, weight: .semibold)).foregroundColor(.posTextPrimary)
                if !line.options.isEmpty {
                    Text(line.options).font(.system(size: 11)).foregroundColor(.posAccent).lineLimit(1)
                }
                Text(CurrencyUtils.formatRp(line.price)).font(.system(size: 11, weight: .medium)).foregroundColor(.posTextPrimary).opacity(0.85)
            }
            Spacer()
            Text("x\(line.quantity)").font(.system(size: 12, weight: .bold)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3).background(Color.posAccent).cornerRadius(4)
            Text(CurrencyUtils.formatRp(line.lineTotal)).font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary).frame(width: 110, alignment: .trailing)
        }.padding(.horizontal, 16).padding(.vertical, 5)
    }
}
private struct ConfirmLine: Identifiable {
    let id: String
    let skuName: String
    let options: String
    let price: Double
    let quantity: Int
    let lineTotal: Double
}
private struct DisplayGroup: Identifiable { let productName: String; var lines: [ConfirmLine]; var id: String { productName } }

