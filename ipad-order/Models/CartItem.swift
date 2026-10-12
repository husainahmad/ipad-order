import Foundation

struct CartItem: Identifiable, Hashable {
    let productId: Int
    let productName: String
    let categoryId: Int
    let skuId: Int
    let skuName: String
    let price: Double
    var quantity: Int
    var customizations: [SelectedCustomization] = []

    /// Identity of the line, not of the product. Two lines of the same SKU with
    /// different customization choices are different lines and must never merge.
    var id: String { lineKey }

    var lineKey: String {
        Self.lineKey(productId: productId, skuId: skuId, optionIds: customizationOptionIds)
    }

    /// Sorted, with each choice repeated once per unit, so that picking the same
    /// options in a different order resolves to the same line.
    var customizationOptionIds: [Int] {
        customizations.flatOptionIds.sorted()
    }

    /// The chosen options in the shape the order request carries them: grouped by
    /// customization, one entry per option carrying how many units of it were
    /// chosen. An option chosen without a quantity travels as 1. Names and prices
    /// are left behind on purpose — the order service resolves them itself.
    /// The line `quantity` is untouched: product units and option units are
    /// independent (two coffees with double shots stays quantity 2 + shots 2).
    var customizationRequests: [OrderCustomizationGroupRequest] {
        Dictionary(grouping: customizations, by: { $0.customizationId })
            .sorted(by: { $0.key < $1.key })
            .map { groupId, choices in
                OrderCustomizationGroupRequest(
                    customizationId: groupId,
                    options: choices
                        .sorted(by: { $0.optionId < $1.optionId })
                        .map {
                            OrderCustomizationRequest(customizationOptionId: $0.optionId,
                                                      quantity: max(1, $0.quantity))
                        })
            }
    }

    static func lineKey(productId: Int, skuId: Int, optionIds: [Int]) -> String {
        let options = optionIds.sorted().map(String.init)
        return options.isEmpty
            ? "\(productId)-\(skuId)"
            : "\(productId)-\(skuId)-\(options.joined(separator: "_"))"
    }

    /// Display-only surcharge. The client cannot know the operator's price tier, so this
    /// is an estimate — the order service re-resolves option prices from the
    /// catalogue and only the option ids are ever sent. See
    /// `OrderDetailSkuRequest.customizations`.
    var unitSurcharge: Double {
        customizations.reduce(0) { $0 + $1.price * Double(max(1, $1.quantity)) }
    }

    var unitPrice: Double { price + unitSurcharge }

    var lineTotal: Double { unitPrice * Double(quantity) }

    mutating func addQuantity(_ delta: Int) {
        quantity = max(0, quantity + delta)
    }
}