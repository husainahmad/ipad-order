import Foundation

struct OrderPayment: Codable, Hashable {
    let paymentId: Int?
}

struct OrderDetailSkuCustomization: Codable, Hashable {
    let customizationName: String?
    let optionName: String?
    let price: Double?
    let quantity: Int?
    let amount: Double?

    var customizationNameValue: String { (customizationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var optionNameValue: String { (optionName ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var quantityValue: Int { max(1, quantity ?? 1) }
    var priceValue: Double { price ?? 0 }
    var amountValue: Double { amount ?? (priceValue * Double(quantityValue)) }

    /// The option as a receipt should name it. A repeated choice is shown once with
    /// its count, so "Extra Shot ×3" rather than the option listed three times.
    var displayName: String {
        let name = optionNameValue
        guard quantityValue > 1 else { return name }
        return "\(name) ×\(quantityValue)"
    }

    /// Full line with its group, e.g. "Sugar: Less Sugar ×2". Falls back to just
    /// the option when the backend did not send a group name.
    var groupedDisplayName: String {
        guard !customizationNameValue.isEmpty, !optionNameValue.isEmpty else { return displayName }
        return "\(customizationNameValue): \(displayName)"
    }
}

struct OrderDetailSku: Codable, Hashable {
    let skuName: String?
    let quantity: Double?
    let price: Double?
    let amount: Double?
    /// Snapshot of the options chosen on this line, already priced by the menu
    /// service. Absent on lines with nothing to customise.
    let customizations: [OrderDetailSkuCustomization]?

    var customizationNames: String {
        (customizations ?? []).map { $0.displayName }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    /// Same options but prefixed with their group, e.g. "Sugar: Less • Milk: Oat".
    var groupedCustomizationNames: String {
        (customizations ?? []).map { $0.groupedDisplayName }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    /// Customizations grouped by their group name, preserving backend order.
    /// Entries without a group name fall under "" and render as bare options.
    var customizationsByGroup: [(name: String, items: [OrderDetailSkuCustomization])] {
        let list = (customizations ?? []).filter { !$0.optionNameValue.isEmpty }
        var order: [String] = []
        var buckets: [String: [OrderDetailSkuCustomization]] = [:]
        for c in list {
            let key = c.customizationNameValue
            if buckets[key] == nil { order.append(key); buckets[key] = [] }
            buckets[key]?.append(c)
        }
        return order.map { (name: $0, items: buckets[$0] ?? []) }
    }

    var hasCustomizations: Bool { !(customizations ?? []).isEmpty }
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
    let storeServiceTypesId: Int?
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

    var storeServiceName: String {
        switch storeServiceTypesId {
        case 1: return "DINEIN"
        case 3: return "TAKEWAY"
        default: return "-"
        }
    }

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
