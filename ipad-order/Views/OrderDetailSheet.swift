import SwiftUI

struct OrderDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ordersVM: OrdersViewModel
    let order: Order

    @State private var showPayment = false
    @State private var showVoidConfirm = false
    @State private var voiding = false
    @State private var statusMessage: String?
    @State private var previewMode: PreviewMode = .items

    enum PreviewMode: String, CaseIterable {
        case items = "Items"
        case receipt = "Receipt Preview"
        case kitchen = "Kitchen Print"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18))
                        .foregroundColor(.posPrimary)
                    Text("Order Detail")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.posTextPrimary)
                    Spacer()
                    Text(order.orderNoValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.posPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.posAccentSoft)
                        .clipShape(Capsule())
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.posTextSecondary)
                            .frame(width: 30, height: 30)
                            .background(Color.posBgLight)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if !order.customerNameValue.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.posPrimary)
                        Text(order.customerNameValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.posTextPrimary)
                        Spacer()
                        Text(order.storeServiceName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.posPrimaryDark)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.posAccentSoft)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posDivider, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "printer")
                            .font(.system(size: 13))
                            .foregroundColor(.posPrimary)
                        Text(previewMode.rawValue)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.posPrimary)
                        Spacer()
                        Picker("Preview", selection: $previewMode) {
                            ForEach(PreviewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 320)
                    }
                    .padding(12)
                    .background(Color.posAccentSoft)

                    ScrollView {
                        if previewMode == .items {
                            itemsListView
                        } else {
                            Text(previewText)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
                .frame(minHeight: 340)

                if let status = statusMessage {
                    Text(status)
                        .font(.system(size: 13))
                        .foregroundColor(.posTextSecondary)
                }

                HStack(spacing: 8) {
                    Button("Print") {
                        printText(PrintUtils.buildReceiptText(order))
                    }
                    .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posBlueAction))

                    Button("Kitchen Print") {
                        printKitchenTexts()
                    }
                    .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posBlueAction))

                    if order.isConfirmed {
                        Button("Pay") {
                            showPayment = true
                        }
                        .buttonStyle(PosButtonStyle(filled: true))
                    }

                    if order.isConfirmed || order.isPaid {
                        Button("Void") {
                            showVoidConfirm = true
                        }
                        .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posStatusVoid))
                    }

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(PosButtonStyle(filled: false))
                }
            }
            .padding(16)
            .background(Color.posBgLight)
            .frame(minWidth: 640, minHeight: 500)
        }
        .animation(.easeOut(duration: 0.2), value: showVoidConfirm)
        .alert("Void order?", isPresented: $showVoidConfirm) {
            Button("Void", role: .destructive) {
                voidOrder()
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showPayment) {
            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { showPayment = false }
                OrderConfirmPopup(
                    tab: OrderTab(id: -1, label: ""),
                    existingOrder: order,
                    onSuccess: {
                        Task { await ordersVM.loadOrders() }
                        showPayment = false
                        dismiss()
                    },
                    onClose: { showPayment = false }
                )
                .environmentObject(OrderFormViewModel())
            }
        }
    }

    private var previewText: String {
        switch previewMode {
        case .items: return ""
        case .receipt: return PrintUtils.buildReceiptText(order)
        case .kitchen: return PrintUtils.buildKitchenText(order)
        }
    }

    // MARK: - Items breakdown with customizations

    /// The choices made on one product line, grouped by their customization and with
    /// the surcharge each option carried.
    private func customizationView(_ detail: OrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(detail.customizationsByGroup.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 3) {
                    if !group.name.isEmpty {
                        Text(group.name.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.posTextSecondary)
                            .tracking(0.4)
                    }
                    ForEach(Array(group.items.enumerated()), id: \.offset) { _, opt in
                        HStack(spacing: 6) {
                            Text("• \(opt.displayName)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.posTextPrimary)
                            Spacer()
                            if opt.priceValue > 0 {
                                Text("+\(CurrencyUtils.formatRp(opt.amountValue))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.posAccent)
                            }
                        }
                        .padding(.leading, group.name.isEmpty ? 0 : 8)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.posAccentSoft.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var itemsListView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let details = order.orderDetails, !details.isEmpty {
                ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(detail.productName ?? "Item")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.posPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.posRowOdd)
                        ForEach(Array((detail.orderDetailSkus ?? []).enumerated()), id: \.offset) { _, sku in
                            HStack(spacing: 8) {
                                Text(sku.skuName ?? "")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.posTextPrimary)
                                Spacer()
                                Text("x\(Int(sku.quantityValue))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.posAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(CurrencyUtils.formatRp(sku.amountValue))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.posTextPrimary)
                                    .frame(minWidth: 90, alignment: .trailing)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            Divider().opacity(0.5)
                        }
                        // Choices are stored against the product line, not the SKU, so they
                        // render once beneath it however many SKUs it carries.
                        if detail.hasCustomizations {
                            customizationView(detail)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posDivider, lineWidth: 1))
                }
            } else {
                Text("No items")
                    .font(.system(size: 13))
                    .foregroundColor(.posTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(20)
            }

            VStack(spacing: 4) {
                HStack {
                    Text("Sub Total").font(.system(size: 13)).foregroundColor(.posTextSecondary)
                    Spacer()
                    Text(CurrencyUtils.formatRp(order.subTotalValue)).font(.system(size: 13, weight: .semibold)).foregroundColor(.posTextPrimary)
                }
                if order.discountTotalValue > 0 {
                    HStack {
                        Text("Discount").font(.system(size: 13)).foregroundColor(.posTextSecondary)
                        Spacer()
                        Text(CurrencyUtils.formatRp(order.discountTotalValue)).font(.system(size: 13, weight: .semibold)).foregroundColor(.posStatusVoid)
                    }
                }
                Divider()
                HStack {
                    Text("Total").font(.system(size: 16, weight: .bold)).foregroundColor(.posPrimary)
                    Spacer()
                    Text(CurrencyUtils.formatRp(order.grandTotalValue)).font(.system(size: 16, weight: .bold)).foregroundColor(.posPrimary)
                }
                if !order.remarkValue.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                        Text(order.remarkValue).font(.system(size: 12)).foregroundColor(.posTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posDivider, lineWidth: 1))
        }
        .padding(12)
    }

    private func printText(_ text: String) {
        statusMessage = "Printing..."
        PrinterManager.print(text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    statusMessage = "Print sent to printer"
                case .failure(let error):
                    statusMessage = "Print failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func printKitchenTexts() {
        let texts = PrintUtils.buildKitchenTexts(order)
        guard !texts.isEmpty else {
            statusMessage = "Nothing to print"
            return
        }
        statusMessage = "Printing..."
        var index = 0
        func printNext() {
            guard index < texts.count else {
                statusMessage = "Print sent to printer"
                return
            }
            PrinterManager.print(texts[index]) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        index += 1
                        printNext()
                    case .failure(let error):
                        statusMessage = "Print failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        printNext()
    }

    private func voidOrder() {
        voiding = true
        Task {
            defer { voiding = false }
            let success = await ordersVM.voidOrder(order.id)
            if success {
                await ordersVM.loadOrders()
                dismiss()
            } else {
                statusMessage = "Void failed"
            }
        }
    }
}

#Preview {
    OrderDetailSheet(order: Order(id: 1, orderNo: "ORD-1", customerName: "", remark: "",
                                  status: "CONFIRMED", storeServiceTypesId: 1, subTotal: 10000, discountTotal: 0,
                                  grandTotal: 10000, createdAt: "", orderPayment: nil,
                                  orderDetails: nil))
        .environmentObject(OrdersViewModel())
}
