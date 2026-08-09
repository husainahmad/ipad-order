import SwiftUI

struct OrderDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var ordersVM: OrdersViewModel
    let order: Order

    @State private var showPayment = false
    @State private var showVoidConfirm = false
    @State private var voiding = false
    @State private var statusMessage: String?

    var body: some View {
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
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "printer")
                        .font(.system(size: 13))
                        .foregroundColor(.posPrimary)
                    Text("Receipt Preview")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.posPrimary)
                    Spacer()
                }
                .padding(12)
                .background(Color.posAccentSoft)

                ScrollView {
                    Text(PrintUtils.buildReceiptText(order))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.posTextPrimary)
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
        .frame(minWidth: 700, minHeight: 520)
        .sheet(isPresented: $showPayment) {
            OrderConfirmSheet(existingOrder: order) {
                Task { await ordersVM.loadOrders() }
                dismiss()
            }
        }
        .alert("Void order?", isPresented: $showVoidConfirm) {
            Button("Void", role: .destructive) {
                voidOrder()
            }
            Button("Cancel", role: .cancel) {}
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
                                  status: "CONFIRMED", subTotal: 10000, discountTotal: 0,
                                  grandTotal: 10000, createdAt: "", orderPayment: nil,
                                  orderDetails: nil))
        .environmentObject(OrdersViewModel())
}
