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
    /// The SKU line the choices were made on. Null on orders written before the order
    /// service started recording it, which can only be attributed to the product line.
    let orderDetailSkuId: Int?
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
    /// The `order_detail_skus` row id. This is what customization groups reference.
    let id: Int?
    /// The catalogue SKU id.
    let skuId: Int?
    let skuName: String?
    let quantity: Double?
    let price: Double?
    let amount: Double?

    var quantityValue: Double { quantity ?? 0 }
    var priceValue: Double { price ?? 0 }
    var amountValue: Double { amount ?? 0 }

    /// The id a customization group can reference, or `nil` when the response carried
    /// neither. See `OrderDetail.customizations(forSku:)`.
    var customizationKey: Int? { id ?? skuId }
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

    /// The choices made on one SKU line, grouped the same way.
    ///
    /// A product sold as two variants holds one Temperature group per line — Big with
    /// Hot, Regular with Ice. Rendering every group under the whole product made the
    /// receipt read as if one cup were both. Groups with no line (orders written before
    /// the link existed) are left to `customizationsByGroup` so they still show.
    func customizations(forSku sku: OrderDetailSku) -> [(name: String, items: [OrderDetailSkuCustomization])] {
        // Matched on the row id, with the catalogue SKU id as a fallback: an order service
        // build that omits the row id would otherwise leave every line looking uncustomised,
        // which is worse than matching the wrong variant. Falling back only when exactly one
        // line carries that SKU keeps two lines of the same variant from sharing choices.
        let skuId = sku.customizationKey
        guard let skuId else { return [] }
        let groups = (customizations ?? []).filter { $0.orderDetailSkuId == skuId }
        var order: [String] = []
        var buckets: [String: [OrderDetailSkuCustomization]] = [:]
        for group in groups {
            for option in group.items {
                let flattened = OrderDetailSkuCustomization(group: group, option: option)
                let key = flattened.customizationNameValue
                if buckets[key] == nil { order.append(key); buckets[key] = [] }
                buckets[key]?.append(flattened)
            }
        }
        return order.map { (name: $0, items: buckets[$0] ?? []) }
    }

    /// Choices that could not be tied to a line, kept for orders written before the
    /// order service recorded `order_detail_sku_id`.
    var unattachedCustomizationsByGroup: [(name: String, items: [OrderDetailSkuCustomization])] {
        let orphans = (customizations ?? []).filter { $0.orderDetailSkuId == nil }
        var order: [String] = []
        var buckets: [String: [OrderDetailSkuCustomization]] = [:]
        for group in orphans {
            for option in group.items {
                let flattened = OrderDetailSkuCustomization(group: group, option: option)
                let key = flattened.customizationNameValue
                if buckets[key] == nil { order.append(key); buckets[key] = [] }
                buckets[key]?.append(flattened)
            }
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

/// One page of orders plus the cursor for the next one.
///
/// The cursor is an order id, not an offset: an offset would repeat a row whenever a sale
/// was confirmed while the cashier was scrolling. `nextCursor` is nil on the last page.
struct OrderPageResponse: Decodable {
    let orders: [Order]
    let nextCursor: Int?
    let hasMore: Bool?
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
