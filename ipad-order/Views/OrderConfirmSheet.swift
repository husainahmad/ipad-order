import SwiftUI

struct OrderConfirmSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var formVM: OrderFormViewModel

    @ObservedObject var tab: OrderTab
    let existingOrder: Order?
    let onSuccess: (() -> Void)?

    @State private var selectedPayment = 1 // CASH
    @State private var cashReceived = 0.0
    @State private var statusMessage: String?
    @State private var working = false

    private let denominations: [Double] = [1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000]

    init(tab: OrderTab) {
        self.tab = tab
        self.existingOrder = nil
        self.onSuccess = nil
    }

    init(existingOrder: Order, onSuccess: @escaping () -> Void) {
        self.tab = OrderTab(id: -1, label: "")
        self.existingOrder = existingOrder
        self.onSuccess = onSuccess
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if working {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
                footer
            }
        }
        .background(Color.white)
        .frame(minWidth: 860, minHeight: 680)
        .onAppear {
            if isCartMode {
                formVM.resetConfirmedOrder()
            }
        }
    }

    private var isCartMode: Bool {
        existingOrder == nil
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(isCartMode ? "Confirm Order & Payment" : "Payment")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text(isCartMode ? "Review your order and choose a payment method"
                                : "Order #\(existingOrder?.orderNoValue ?? "")")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(14)
        .background(Color.posPrimaryGradient)
    }

    private var content: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    if isCartMode {
                        inputsBox
                    }
                    orderSummaryBox
                    totalsBox
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    paymentSection
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
        }
    }

    private var orderSummaryBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Order Summary")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.posPrimary)
                Spacer()
                Text("\(totalItemCount) item(s)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.posAccent)
            }

            VStack(spacing: 0) {
                ForEach(displayGroups) { group in
                    Text(group.productName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.posPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.posRowOdd)

                    ForEach(group.lines) { line in
                        ConfirmLineRow(line: line)
                    }
                }
            }
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.posDivider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Color.posBgLight)
        .cornerRadius(8)
    }

    private var totalsBox: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Sub Total")
                    .font(.system(size: 14))
                    .foregroundColor(.posTextPrimary)
                Spacer()
                Text(CurrencyUtils.formatRp(subTotalValue))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.posTextPrimary)
            }
            HStack {
                Text("Discount")
                    .font(.system(size: 14))
                    .foregroundColor(.posTextPrimary)
                Spacer()
                Text(CurrencyUtils.formatRp2(discountValue))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.posStatusVoid)
            }
            Divider()
            HStack {
                Text("Total")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.posPrimary)
                Spacer()
                Text(CurrencyUtils.formatRp(totalValue))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.posPrimary)
            }
        }
        .padding(16)
        .background(Color.posBgLight)
        .cornerRadius(8)
    }

    private var inputsBox: some View {
        VStack(spacing: 12) {
            Text("Order Details")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.posPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                confirmTypeCard(title: "DINE IN", icon: "fork.knife", id: 1)
                confirmTypeCard(title: "TAKE AWAY", icon: "takeoutbag.and.cup.and.straw", id: 3)
            }

            TextField("Customer Name", text: $tab.customer)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            TextField("Discount", text: discountBinding)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)

            TextField("Additional notes...", text: $tab.remark)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(16)
        .background(Color.posBgLight)
        .cornerRadius(8)
    }

    private func confirmTypeCard(title: String, icon: String, id: Int) -> some View {
        let selected = tab.storeServiceTypesId == id
        return Button {
            tab.storeServiceTypesId = id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(selected ? .posPrimaryDark : .posGrayButton)
                Text(title)
                    .font(.system(size: 14, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? .posPrimaryDark : .posTextSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.posAccent)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? Color.posAccentSoft : Color.posBgLight)
            .overlay(
                RoundedRectangle(cornerRadius: PosShape.cornerMedium)
                    .stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
        }
        .buttonStyle(.plain)
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Payment Method")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.posPrimary)
                Spacer()
                Text("Total : \(CurrencyUtils.formatRp(totalValue))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.posTextSecondary)
            }

            paymentSelector

            if selectedPayment == 1 {
                cashPanel
            }

            if let status = statusMessage {
                Text(status)
                    .font(.system(size: 13))
                    .foregroundColor(.posStatusVoid)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color.posBgLight)
        .cornerRadius(8)
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
        return Button {
            selectedPayment = id
            if id == 1 { cashReceived = 0 }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(selected ? Color.posAccentSoft : Color.posBgLight)
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(selected ? .posAccent : .posGrayButton)
                }
                Text(title)
                    .font(.system(size: 13, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? .posPrimaryDark : .posTextSecondary)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.posAccent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.white : Color.posBgLight)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: selected ? Color.posAccent.opacity(0.2) : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var cashPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CASH PAYMENT")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.posPrimary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL")
                        .font(.system(size: 12))
                        .foregroundColor(.posTextSecondary)
                    Text(CurrencyUtils.formatRp(totalValue))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.posTextPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                        ForEach(denominations, id: \.self) { amount in
                            Button {
                                cashReceived += amount
                            } label: {
                                Text(CurrencyUtils.formatRp(amount))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.posPrimaryDark)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Color.white)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.posDivider, lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 4) {
                        Button("CLEAR") {
                            cashReceived = 0
                        }
                        .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posStatusVoid))

                        Button("EXACT") {
                            cashReceived = totalValue
                        }
                        .buttonStyle(PosButtonStyle(filled: true))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minWidth: 260)

                VStack(alignment: .leading, spacing: 8) {
                    Text("UANG DITERIMA")
                        .font(.system(size: 12))
                        .foregroundColor(.posTextSecondary)
                    Text(CurrencyUtils.formatRp(cashReceived))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.posTextPrimary)

                    Text("KEMBALIAN")
                        .font(.system(size: 12))
                        .foregroundColor(.posTextSecondary)
                        .padding(.top, 12)
                    Text(CurrencyUtils.formatRp(change))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.posAccent)
                }
                .frame(width: 120)
            }
        }
        .padding(12)
        .background(Color.posRowOdd)
        .cornerRadius(8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(PosButtonStyle(filled: false))

            Spacer()

            Button("Pay") {
                pay()
            }
            .buttonStyle(PosButtonStyle(filled: true))
            .disabled(working)
        }
        .padding(8)
    }

    // MARK: - Display data

    private var displayGroups: [DisplayGroup] {
        if isCartMode {
            return cartGroups
        }
        return orderGroups
    }

    private var cartGroups: [DisplayGroup] {
        var groups: [String: DisplayGroup] = [:]
        for item in tab.items {
            let line = ConfirmLine(id: "\(item.productId)-\(item.skuId)",
                                   skuName: item.skuName,
                                   price: item.price,
                                   quantity: item.quantity,
                                   lineTotal: item.lineTotal)
            if var group = groups[item.productName] {
                group.lines.append(line)
                groups[item.productName] = group
            } else {
                groups[item.productName] = DisplayGroup(productName: item.productName, lines: [line])
            }
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }

    private var orderGroups: [DisplayGroup] {
        var groups: [String: DisplayGroup] = [:]
        for detail in existingOrder?.orderDetails ?? [] {
            let name = detail.productName ?? ""
            var group = groups[name] ?? DisplayGroup(productName: name, lines: [])
            for sku in detail.orderDetailSkus ?? [] {
                group.lines.append(ConfirmLine(id: "\(name)-\(sku.skuName ?? "")",
                                               skuName: sku.skuName ?? "",
                                               price: sku.price ?? 0,
                                               quantity: Int(sku.quantity ?? 0),
                                               lineTotal: sku.amount ?? 0))
            }
            groups[name] = group
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }

    private var totalItemCount: Int {
        if isCartMode {
            return tab.items.reduce(0) { $0 + $1.quantity }
        }
        return (existingOrder?.orderDetails ?? []).reduce(0) { sum, detail in
            sum + (detail.orderDetailSkus ?? []).reduce(0) { $0 + Int($1.quantity ?? 0) }
        }
    }

    private var subTotalValue: Double {
        if isCartMode {
            return tab.subtotal
        }
        return existingOrder?.subTotalValue ?? 0
    }

    private var discountValue: Double {
        if isCartMode {
            return Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0
        }
        return existingOrder?.discountTotalValue ?? 0
    }

    private var totalValue: Double {
        if isCartMode {
            return max(0, subTotalValue - discountValue)
        }
        return existingOrder?.grandTotalValue ?? 0
    }

    private var change: Double {
        max(0, cashReceived - totalValue)
    }

    private var discountBinding: Binding<String> {
        Binding(
            get: { tab.discount },
            set: { newValue in
                tab.discount = CurrencyUtils.formatWholeInput(newValue)
            }
        )
    }

    // MARK: - Actions

    private func pay() {
        if selectedPayment == 1, cashReceived < totalValue {
            statusMessage = "Insufficient cash entered!"
            return
        }
        statusMessage = nil
        working = true
        Task {
            defer { working = false }
            do {
                let orderToPay: Order
                if isCartMode {
                    let success = await formVM.confirmOrder(customerName: tab.customer,
                                                            discount: CurrencyUtils.digitsOnly(tab.discount),
                                                            remark: tab.remark)
                    guard success, let order = formVM.confirmedOrder else {
                        statusMessage = formVM.error ?? "Failed to confirm order"
                        return
                    }
                    orderToPay = order
                } else if let order = existingOrder {
                    orderToPay = order
                } else {
                    return
                }

                let request = PaymentRequest(orderId: orderToPay.id, paymentId: selectedPayment)
                let paidOrder = try await APIClient.shared.payOrder(request)
                printReceipt(paidOrder)
                if isCartMode {
                    _ = formVM.removeActiveTab()
                } else {
                    onSuccess?()
                }
                dismiss()
            } catch {
                statusMessage = "Payment failed: \(error.localizedDescription)"
            }
        }
    }

    private func printReceipt(_ paidOrder: Order) {
        PrinterManager.print(PrintUtils.buildReceiptText(paidOrder)) { _ in }
    }
}

private struct ConfirmLine: Identifiable {
    let id: String
    let skuName: String
    let price: Double
    let quantity: Int
    let lineTotal: Double
}

private struct DisplayGroup: Identifiable {
    let productName: String
    var lines: [ConfirmLine]

    var id: String { productName }
}

private struct ConfirmLineRow: View {
    let line: ConfirmLine

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.skuName)
                    .font(.system(size: 13))
                    .foregroundColor(.posTextPrimary)
                Text(CurrencyUtils.formatRp(line.price))
                    .font(.system(size: 11))
                    .foregroundColor(.posTextSecondary)
            }
            Spacer()

            Text("x\(line.quantity)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.posAccent)
                .cornerRadius(4)

            Text(CurrencyUtils.formatRp(line.lineTotal))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.posTextPrimary)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}

#Preview {
    OrderConfirmSheet(tab: OrderTab(id: 1, label: "#001"))
        .environmentObject(OrderFormViewModel())
}
