import Foundation

struct OrderPayment: Codable, Hashable {
    let paymentId: Int?
}

struct OrderDetailSku: Codable, Hashable {
    let skuName: String?
    let quantity: Double?
    let price: Double?
    let amount: Double?
}

struct OrderDetail: Codable, Hashable {
    let productName: String?
    let categoryId: Int?
    let orderDetailSkus: [OrderDetailSku]?
}

struct Order: Codable, Identifiable, Hashable {
    let id: Int
    let orderNo: String?
    let customerName: String?
    let remark: String?
    let status: String?
    let subTotal: Double?
    let discountTotal: Double?
    let grandTotal: Double?
    let createdAt: String?
    let orderPayment: OrderPayment?
    let orderDetails: [OrderDetail]?

    var orderNoValue: String { orderNo ?? "" }
    var customerNameValue: String { customerName ?? "" }
    var remarkValue: String { remark ?? "" }
    var statusValue: String { status ?? "" }
    var subTotalValue: Double { subTotal ?? 0 }
    var discountTotalValue: Double { discountTotal ?? 0 }
    var grandTotalValue: Double { grandTotal ?? 0 }
    var createdAtValue: String { createdAt ?? "" }

    var isConfirmed: Bool { statusValue.lowercased() == "confirmed" }
    var isPaid: Bool { statusValue.lowercased() == "paid" }
    var isVoid: Bool { statusValue.lowercased() == "void" }

    var paymentName: String {
        guard let paymentId = orderPayment?.paymentId else { return "UNPAID" }
        switch paymentId {
        case 1: return "CASH"
        case 2: return "QR"
        case 3: return "CARD"
        default: return "UNPAID"
        }
    }
}
