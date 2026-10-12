import Foundation

// MARK: - SelectionType

enum SelectionType: String, Codable, Hashable {
    case single = "SINGLE"
    case multiple = "MULTIPLE"

    var allowsMany: Bool { self == .multiple }
}

// MARK: - CustomizationOptionTierPrice

struct CustomizationOptionTierPrice: Codable, Hashable {
    let id: Int?
    let tierId: Int?
    let price: Double?
    let deleted: Bool?

    var priceValue: Double {
        guard let price, price > 0 else { return 0 }
        return price
    }
}

// MARK: - CustomizationOption

struct CustomizationOption: Codable, Identifiable, Hashable {
    let id: Int
    let customizationId: Int?
    let name: String?
    let tierPrices: [CustomizationOptionTierPrice]?
    let isDeleted: Bool?

    var nameValue: String { name ?? "" }

    /// Client-side estimate of what this option costs, used only so the cart and the
    /// confirm popup can show a total before the line is priced.
    ///
    /// The operator's price tier lives on the store and is not part of any response
    /// this app holds, so the tier rows cannot be matched here — the lowest live row
    /// is used as a stand-in. The order service re-resolves the real amount when it
    /// prices the line, and only the option IDs are ever sent, so this number never
    /// reaches the order.
    var price: Double {
        (tierPrices ?? [])
            .filter { $0.deleted != true }
            .map { $0.priceValue }
            .min() ?? 0
    }
}

// MARK: - ProductCustomization

struct ProductCustomization: Codable, Identifiable, Hashable {
    let id: Int?
    let productId: Int?
    let customizationId: Int
    let name: String?
    let description: String?
    let selectionType: SelectionType?
    let brandId: Int?
    let required: Bool?
    /// Whether an option in this group may carry a quantity greater than one.
    /// Absent (older API responses) means the legacy one-unit-per-option behavior.
    let allowQuantity: Bool?
    let minSelection: Int?
    let maxSelection: Int?
    let sortOrder: Int?
    let options: [CustomizationOption]?

    var nameValue: String { name ?? "" }
    var isRequired: Bool { required == true }
    var allowsMultiple: Bool { selectionType?.allowsMany ?? false }
    /// Quantity steppers are shown only when the catalogue allows quantities;
    /// otherwise an option is either chosen (quantity 1) or not.
    var allowsQuantity: Bool { allowQuantity == true }
    /// A group is only forced when the effective values say so. `minSelection` is
    /// already resolved server-side (per-product override wins), so a group with no
    /// minimum and `required = false` stays optional.
    var minCount: Int { max(0, minSelection ?? (isRequired ? 1 : 0)) }
    var maxCount: Int {
        let declared = maxSelection ?? (allowsMultiple ? (options?.count ?? 0) : 1)
        return allowsMultiple ? max(1, declared) : 1
    }
    var sortedOptions: [CustomizationOption] {
        (options ?? []).filter { $0.isDeleted != true }
    }

    /// Cap for one option's quantity. Quantities are independent of the
    /// min/max option budget, so a repeated option needs its own backstop —
    /// the same ceiling the menu service enforces before pricing a line.
    static let maxUnitsPerOption = 50
}

// MARK: - SelectedCustomization

/// One customization choice the cashier made, kept on the cart line so the cart,
/// the summary, the confirm popup and the kitchen ticket can all name it. Only
/// `optionId` travels to the server — the order service resolves the price and
/// names itself so a client cannot dictate them.
struct SelectedCustomization: Codable, Hashable, Identifiable {
    let customizationId: Int
    let customizationName: String
    let optionId: Int
    let optionName: String
    let price: Double
    /// How many units of the option the customer asked for. Three extra shots is
    /// one choice with `quantity = 3`, not three choices; the id is repeated that
    /// many times on the wire and the line is surcharged once per unit.
    var quantity: Int = 1

    var id: Int { optionId }

    /// The choice as a ticket should name it: the count only appears when more than
    /// one unit was ordered.
    var displayName: String {
        quantity > 1 ? "\(optionName) ×\(quantity)" : optionName
    }

    /// The option repeated once per unit, which is how a group's selections are
    /// counted when deciding whether the group is satisfied and when keying the
    /// line. See `CartItem.customizationOptionIds`.
    var repeatedOptionIds: [Int] {
        Array(repeating: optionId, count: max(1, quantity))
    }
}

extension Array where Element == SelectedCustomization {
    /// Every chosen option with repeats expanded, in the order they were chosen.
    var flatOptionIds: [Int] {
        flatMap { $0.repeatedOptionIds }
    }
}

// MARK: - CustomizationSelection

/// The in-progress answer for every customization group of one product, held by
/// the product detail popup. `selected` maps a customization id to the option ids
/// chosen in that group, with one entry per unit: three extra shots is
/// `[55, 55, 55]`. Unit sums drive quantities and surcharges; the min/max option
/// budget counts *distinct* options instead, matching the menu service.
struct CustomizationSelection: Equatable {
    private(set) var selected: [Int: [Int]] = [:]

    func optionIds(for customizationId: Int) -> [Int] {
        selected[customizationId] ?? []
    }

    /// How many distinct options are chosen in a group. This — not the summed
    /// quantities — is what `minSelection` / `maxSelection` count, matching the
    /// menu service: two units of one topping fill one option slot, not two.
    func distinctCount(in customizationId: Int) -> Int {
        Set(optionIds(for: customizationId)).count
    }

    /// How many units of one option are chosen. Zero means not chosen.
    func count(of optionId: Int, in customizationId: Int) -> Int {
        optionIds(for: customizationId).filter { $0 == optionId }.count
    }

    func isSelected(_ optionId: Int, in customizationId: Int) -> Bool {
        count(of: optionId, in: customizationId) > 0
    }

    /// Adds one unit of an option. A single-choice group replaces whatever it held;
    /// a multiple-choice group appends, unless the group already holds its cap of
    /// *distinct* options, in which case the tap is ignored rather than silently
    /// discarding the answer.
    mutating func add(_ optionId: Int, in customization: ProductCustomization) {
        var ids = optionIds(for: customization.customizationId)
        if customization.allowsMultiple {
            guard Set(ids).count < customization.maxCount else { return }
            ids.append(optionId)
        } else {
            ids = [optionId]
        }
        selected[customization.customizationId] = ids
    }

    /// Removes one unit of an option, clearing the group once its last unit goes.
    mutating func remove(_ optionId: Int, in customization: ProductCustomization) {
        var ids = optionIds(for: customization.customizationId)
        guard let index = ids.firstIndex(of: optionId) else { return }
        ids.remove(at: index)
        if ids.isEmpty { selected.removeValue(forKey: customization.customizationId) }
        else { selected[customization.customizationId] = ids }
    }

    /// A tap on an option: adds it when it is not chosen, otherwise takes one unit
    /// away. For a single-choice group this is select and deselect.
    mutating func toggle(_ optionId: Int, in customization: ProductCustomization) {
        if isSelected(optionId, in: customization.customizationId) {
            remove(optionId, in: customization)
        } else {
            add(optionId, in: customization)
        }
    }

    /// Total units chosen in a group: the sum of option quantities. This is the
    /// number the menu service counts against `minSelection` / `maxSelection`.
    func totalUnits(in customizationId: Int) -> Int {
        optionIds(for: customizationId).count
    }

    /// A tap on an option row. In quantity mode this toggles presence (chosen at
    /// quantity 1, or cleared entirely); the stepper is what adjusts the count.
    /// Outside quantity mode it is the classic radio/checkbox toggle. A
    /// single-choice group stays exclusive in both modes.
    mutating func select(_ optionId: Int, in group: ProductCustomization) {
        guard group.allowsQuantity else {
            toggle(optionId, in: group)
            return
        }
        let id = group.customizationId
        if isSelected(optionId, in: id) {
            selected[id] = selected[id]?.filter { $0 != optionId }
            if selected[id]?.isEmpty == true { selected.removeValue(forKey: id) }
        } else {
            if !group.allowsMultiple { selected[id] = [] }
            guard distinctCount(in: id) < group.maxCount else { return }
            selected[id, default: []].append(optionId)
        }
    }

    /// Stepper `+`: one more unit of an option. Quantity mode only; single-choice
    /// groups stay exclusive by clearing any other option first. Quantities do not
    /// consume the min/max option budget — that counts distinct options — so a
    /// chosen option grows up to the per-option ceiling instead.
    mutating func increment(_ optionId: Int, in group: ProductCustomization) {
        guard group.allowsQuantity else { return }
        let id = group.customizationId
        if isSelected(optionId, in: id) {
            guard count(of: optionId, in: id) < ProductCustomization.maxUnitsPerOption else { return }
            selected[id, default: []].append(optionId)
        } else {
            if !group.allowsMultiple { selected[id] = [] }
            guard distinctCount(in: id) < group.maxCount else { return }
            selected[id, default: []].append(optionId)
        }
    }

    /// Stepper `−`: one fewer unit of an option. Clamped at zero; never negative.
    mutating func decrement(_ optionId: Int, in group: ProductCustomization) {
        guard group.allowsQuantity else { return }
        remove(optionId, in: group)
    }

    /// Whether the stepper `+` may fire for an option: quantity mode, and — for an
    /// already-chosen option — room under the per-option ceiling, or — for a new
    /// option — room under the distinct-option budget (plus exclusivity for
    /// single-choice groups, so at most one option ever has quantity > 0).
    func canIncrement(_ optionId: Int, in group: ProductCustomization) -> Bool {
        guard group.allowsQuantity else { return false }
        let id = group.customizationId
        if isSelected(optionId, in: id) {
            return count(of: optionId, in: id) < ProductCustomization.maxUnitsPerOption
        }
        if !group.allowsMultiple, !(selected[id]?.isEmpty ?? true) { return false }
        return distinctCount(in: id) < group.maxCount
    }

    /// Resolves the selection into cart-ready values, one entry per option carrying
    /// how many units were chosen. Groups short of their minimum *distinct options*
    /// are dropped so the operator gets warned rather than sending a line the menu
    /// service will reject.
    func resolved(from groups: [ProductCustomization]) -> [SelectedCustomization] {
        var result: [SelectedCustomization] = []
        for group in groups {
            let ids = optionIds(for: group.customizationId)
            guard Set(ids).count >= group.minCount else { continue }
            for option in group.sortedOptions {
                let quantity = ids.filter { $0 == option.id }.count
                guard quantity > 0 else { continue }
                result.append(SelectedCustomization(customizationId: group.customizationId,
                                                     customizationName: group.nameValue,
                                                     optionId: option.id,
                                                     optionName: option.nameValue,
                                                     price: option.price,
                                                     quantity: quantity))
            }
        }
        return result
    }

    /// Groups the operator must still resolve before the line can be added.
    /// A group is met once enough *distinct options* are chosen; piling units
    /// onto one option does not satisfy a minimum of two.
    func unmetRequirements(in groups: [ProductCustomization]) -> [ProductCustomization] {
        groups.filter { distinctCount(in: $0.customizationId) < $0.minCount }
    }
}