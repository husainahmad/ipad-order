import Foundation

struct OrderPayment: Codable, Hashable {
    let paymentId: Int?
}

// MARK: - Customization shapes

/// One customization option chosen under a group, as the order service stores it.
///
/// The order service splits a line's choices into a group row
/// (`order_detail_customizations`) and its option rows
/// (`order_detail_customization_options`). This is the option row.
struct OrderCustomizationOption: Codable, Hashable {
    let customizationOptionsId: Int?
    let customizationOptionName: String?
    let quantity: Int?
    let price: Double?
    let amount: Double?

    /// Some responses (and older payloads) name the field without the plural "s".
    let id: Int?
    let name: String?

    var optionNameValue: String {
        let direct = (customizationOptionName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !direct.isEmpty { return direct }
        return (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
}

/// One customization group chosen on an order line, with the options picked in it.
///
/// Absent on lines with nothing to customise.
struct OrderDetailCustomization: Codable, Hashable {
    let customizationId: Int?
    let customizationName: String?
    let options: [OrderCustomizationOption]?

    var customizationNameValue: String {
        (customizationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var items: [OrderCustomizationOption] {
        (options ?? []).filter { !$0.optionNameValue.isEmpty }
    }
}

/// A single chosen option, flattened out of its group for display.
///
/// The order service stores groups and options; the views want one row per choice,
/// carrying the group's name so a receipt can say "Sugar: Less Sugar". This is that
/// flattened view, and it is what the receipt and detail screens have always rendered.
struct OrderDetailSkuCustomization: Codable, Hashable {
    let customizationName: String?
    let optionName: String?
    let price: Double?
    let quantity: Int?
    let amount: Double?

    init(customizationName: String?, optionName: String?, price: Double?, quantity: Int?, amount: Double?) {
        self.customizationName = customizationName
        self.optionName = optionName
        self.price = price
        self.quantity = quantity
        self.amount = amount
    }

    init(group: OrderDetailCustomization, option: OrderCustomizationOption) {
        self.customizationName = group.customizationNameValue
        self.optionName = option.optionNameValue
        self.price = option.priceValue
        self.quantity = option.quantityValue
        self.amount = option.amountValue
    }

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

    var quantityValue: Double { quantity ?? 0 }
    var priceValue: Double { price ?? 0 }
    var amountValue: Double { amount ?? 0 }
}

struct OrderDetail: Codable, Hashable {
    let productName: String?
    let categoryId: Int?
    let orderDetailSkus: [OrderDetailSku]?
    /// The customization groups chosen on this line, each with its options.
    /// Absent when nothing was chosen.
    let customizations: [OrderDetailCustomization]?

    /// Every chosen option on the line, flattened out of its group and keeping the
    /// group's name, which is the shape the detail screen, the confirm popup and the
    /// receipt printer all render.
    var allCustomizations: [OrderDetailSkuCustomization] {
        (customizations ?? []).flatMap { group in
            group.items.map { OrderDetailSkuCustomization(group: group, option: $0) }
        }
    }

    /// The chosen options grouped by their group name, preserving backend order.
    var customizationsByGroup: [(name: String, items: [OrderDetailSkuCustomization])] {
        let list = allCustomizations
        var order: [String] = []
        var buckets: [String: [OrderDetailSkuCustomization]] = [:]
        for c in list {
            let key = c.customizationNameValue
            if buckets[key] == nil { order.append(key); buckets[key] = [] }
            buckets[key]?.append(c)
        }
        return order.map { (name: $0, items: buckets[$0] ?? []) }
    }

    /// One line per group, e.g. "Sugar: Less • Milk: Oat".
    var groupedCustomizationNames: String {
        allCustomizations.map { $0.groupedDisplayName }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    var hasCustomizations: Bool { !allCustomizations.isEmpty }
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

    /// Whether any line in the order carries customization choices.
    var hasCustomizations: Bool {
        (orderDetails ?? []).contains { $0.hasCustomizations }
    }

    /// A one-line description of what was ordered, with each product's choices in
    /// brackets, e.g. `Kopi Tubruk (Size: Large, Milk: Oat) • Americano`.
    /// Used by the order list, where a row has room for a single line.
    var itemsSummary: String {
        (orderDetails ?? []).compactMap { detail -> String? in
            let product = (detail.productName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !product.isEmpty else { return nil }
            let choices = detail.allCustomizations
                .map { $0.groupedDisplayName }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            return choices.isEmpty ? product : "\(product) (\(choices))"
        }
        .joined(separator: " • ")
    }

    /// Just the choices across the order, e.g. `Size: Large, Milk: Oat`.
    var customizationSummary: String {
        (orderDetails ?? []).flatMap { $0.allCustomizations }
            .map { $0.groupedDisplayName }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

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
