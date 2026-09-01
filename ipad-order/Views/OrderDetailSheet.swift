import SwiftUI

struct OrderDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ordersVM: OrdersViewModel
    let order: Order

    @State private var showPayment = false
    @State private var showVoidConfirm = false
    @State private var voiding = false
    @State private var statusMessage: String?
    @State private var previewMode: PreviewMode = .receipt

    enum PreviewMode: String, CaseIterable {
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
                        .frame(width: 220)
                    }
                    .padding(12)
                    .background(Color.posAccentSoft)

                    ScrollView {
                        Text(previewText)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
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
                        printText(PrintUtils.buildKitchenText(order))
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

            if showPayment {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                OrderConfirmPopup(
                    tab: OrderTab(id: -1, label: ""),
                    existingOrder: order,
                    onSuccess: {
                        Task { await ordersVM.loadOrders() }
                        dismiss()
                    },
                    onClose: { showPayment = false }
                )
                .environmentObject(OrderFormViewModel())
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showPayment)
        .alert("Void order?", isPresented: $showVoidConfirm) {
            Button("Void", role: .destructive) {
                voidOrder()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var previewText: String {
        switch previewMode {
        case .receipt: return PrintUtils.buildReceiptText(order)
        case .kitchen: return PrintUtils.buildKitchenText(order)
        }
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
