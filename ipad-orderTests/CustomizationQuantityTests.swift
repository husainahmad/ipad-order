import Foundation
import Testing
@testable import ipad_order

// MARK: - Fixtures

private func makeOption(_ id: Int, groupId: Int, name: String = "Option") -> CustomizationOption {
    CustomizationOption(id: id, customizationId: groupId, name: name, tierPrices: nil, isDeleted: false)
}

private func makeGroup(
    _ customizationId: Int,
    selectionType: SelectionType,
    allowQuantity: Bool? = nil,
    required: Bool = false,
    minSelection: Int? = nil,
    maxSelection: Int? = nil,
    options: [CustomizationOption] = []
) -> ProductCustomization {
    ProductCustomization(
        id: nil, productId: 10, customizationId: customizationId, name: "Group",
        description: nil, selectionType: selectionType, brandId: nil,
        required: required, allowQuantity: allowQuantity,
        minSelection: minSelection, maxSelection: maxSelection,
        sortOrder: nil, options: options)
}

// MARK: - API decoding

struct CustomizationDecodingTests {
    @Test func decodesAllowQuantityTrue() throws {
        let json = """
        {"id":1,"productId":10,"customizationId":5,"name":"Toppings",\
        "selectionType":"MULTIPLE","required":false,"allowQuantity":true,\
        "minSelection":0,"maxSelection":5,"options":[]}
        """.data(using: .utf8)!
        let group = try JSONDecoder().decode(ProductCustomization.self, from: json)
        #expect(group.allowsQuantity == true)
        #expect(group.allowsMultiple == true)
    }

    @Test func missingAllowQuantityMeansLegacyOneUnitBehavior() throws {
        let json = """
        {"id":1,"productId":10,"customizationId":5,"name":"Size",\
        "selectionType":"SINGLE","required":true,"options":[]}
        """.data(using: .utf8)!
        let group = try JSONDecoder().decode(ProductCustomization.self, from: json)
        #expect(group.allowsQuantity == false)
    }
}

// MARK: - SINGLE + allowQuantity=false → radio

struct SingleNoQuantityTests {
    @Test func radioSelectsAndDeselects() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .single, options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.select(11, in: group)
        #expect(selection.isSelected(11, in: 5))
        selection.select(11, in: group)
        #expect(!selection.isSelected(11, in: 5))
    }

    @Test func radioReplacesAndNeverExceedsOneUnit() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .single, options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.select(11, in: group)
        selection.select(12, in: group)
        #expect(!selection.isSelected(11, in: 5))
        #expect(selection.count(of: 12, in: 5) == 1)
        #expect(!selection.canIncrement(12, in: group))
    }
}

// MARK: - SINGLE + allowQuantity=true → exclusive stepper

struct SingleQuantityTests {
    @Test func onlyOneOptionHoldsQuantity() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .single, allowQuantity: true,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.increment(11, in: group)
        selection.increment(12, in: group)
        #expect(selection.count(of: 11, in: 5) == 0)
        #expect(selection.count(of: 12, in: 5) == 1)
    }

    @Test func quantityIgnoresTheDistinctOptionBudget() {
        var selection = CustomizationSelection()
        // Single means one distinct option; its quantity grows to the per-option
        // ceiling instead of stopping at maxCount.
        let group = makeGroup(5, selectionType: .single, allowQuantity: true,
                              options: [makeOption(11, groupId: 5)])

        selection.increment(11, in: group)
        selection.increment(11, in: group)
        selection.increment(11, in: group)
        #expect(selection.count(of: 11, in: 5) == 3)
        #expect(selection.canIncrement(11, in: group))
    }

    @Test func perOptionQuantityIsCapped() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .single, allowQuantity: true,
                              options: [makeOption(11, groupId: 5)])

        for _ in 0 ..< ProductCustomization.maxUnitsPerOption {
            selection.increment(11, in: group)
        }
        #expect(selection.count(of: 11, in: 5) == ProductCustomization.maxUnitsPerOption)
        #expect(!selection.canIncrement(11, in: group))
        selection.increment(11, in: group)
        #expect(selection.count(of: 11, in: 5) == ProductCustomization.maxUnitsPerOption)
    }

    @Test func tappingAnotherOptionSwitchesToIt() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .single, allowQuantity: true,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.increment(11, in: group)
        selection.select(12, in: group)
        #expect(selection.count(of: 11, in: 5) == 0)
        #expect(selection.count(of: 12, in: 5) == 1)
    }
}

// MARK: - MULTIPLE + allowQuantity=false → checkbox

struct MultipleNoQuantityTests {
    @Test func checkboxTogglesWithoutStacking() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, maxSelection: 2,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.select(11, in: group)
        selection.select(11, in: group)
        #expect(!selection.isSelected(11, in: 5))
        selection.select(11, in: group)
        #expect(selection.count(of: 11, in: 5) == 1)
    }

    @Test func checkboxRespectsMaxSelection() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, maxSelection: 2,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5), makeOption(13, groupId: 5)])

        selection.select(11, in: group)
        selection.select(12, in: group)
        selection.select(13, in: group)
        #expect(!selection.isSelected(13, in: 5))
    }

    @Test func noStepperInCheckboxMode() {
        let group = makeGroup(5, selectionType: .multiple, maxSelection: 2,
                              options: [makeOption(11, groupId: 5)])
        var selection = CustomizationSelection()
        selection.select(11, in: group)
        #expect(!selection.canIncrement(11, in: group))
    }
}

// MARK: - MULTIPLE + allowQuantity=true → stepper per option

struct MultipleQuantityTests {
    @Test func stepperAdjustsUnitsAndCountsTheirSum() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, allowQuantity: true, maxSelection: 5,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.increment(11, in: group)
        selection.increment(11, in: group)
        selection.increment(12, in: group)
        #expect(selection.totalUnits(in: 5) == 3)
        selection.decrement(11, in: group)
        #expect(selection.totalUnits(in: 5) == 2)
    }

    @Test func maxSelectionCapsDistinctOptionsNotUnits() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, allowQuantity: true, maxSelection: 2,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5),
                                        makeOption(13, groupId: 5)])

        // Five units of one topping fill one option slot, not the whole budget.
        for _ in 0 ..< 5 { selection.increment(11, in: group) }
        #expect(selection.count(of: 11, in: 5) == 5)
        #expect(selection.canIncrement(11, in: group))
        #expect(selection.canIncrement(12, in: group))

        selection.increment(12, in: group)
        #expect(selection.distinctCount(in: 5) == 2)
        // Budget spent: a third distinct option is refused…
        #expect(!selection.canIncrement(13, in: group))
        selection.increment(13, in: group)
        #expect(!selection.isSelected(13, in: 5))
        // …but quantities on the chosen ones still move.
        #expect(selection.canIncrement(11, in: group))
    }

    @Test func quantityNeverGoesNegative() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, allowQuantity: true, maxSelection: 5,
                              options: [makeOption(11, groupId: 5)])

        selection.decrement(11, in: group)
        selection.decrement(11, in: group)
        #expect(selection.count(of: 11, in: 5) == 0)
        #expect(!selection.isSelected(11, in: 5))
    }

    @Test func tappingSelectedOptionClearsIt() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, allowQuantity: true, maxSelection: 5,
                              options: [makeOption(11, groupId: 5)])

        selection.increment(11, in: group)
        selection.increment(11, in: group)
        selection.select(11, in: group)
        #expect(!selection.isSelected(11, in: 5))
    }
}

// MARK: - Validation (min/max over summed quantities)

struct QuantityValidationTests {
    @Test func minSelectionCountsDistinctOptionsNotUnits() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, allowQuantity: true,
                              required: true, minSelection: 2, maxSelection: 5,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        #expect(!selection.unmetRequirements(in: [group]).isEmpty)
        // Five units of one topping still leave the minimum unmet.
        for _ in 0 ..< 5 { selection.increment(11, in: group) }
        #expect(!selection.unmetRequirements(in: [group]).isEmpty)
        selection.increment(12, in: group)
        #expect(selection.unmetRequirements(in: [group]).isEmpty)
    }

    @Test func resolvedDropsGroupsShortOfMinimum() {
        var selection = CustomizationSelection()
        let group = makeGroup(5, selectionType: .multiple, allowQuantity: true,
                              minSelection: 2, maxSelection: 5,
                              options: [makeOption(11, groupId: 5), makeOption(12, groupId: 5)])

        selection.increment(11, in: group)
        selection.increment(11, in: group)
        selection.increment(11, in: group)
        #expect(selection.resolved(from: [group]).isEmpty)
        selection.increment(12, in: group)
        let resolved = selection.resolved(from: [group])
        #expect(resolved.count == 2)
        #expect(resolved.first(where: { $0.optionId == 11 })?.quantity == 3)
        #expect(resolved.first(where: { $0.optionId == 12 })?.quantity == 1)
    }
}

// MARK: - Order payload

struct CustomizationPayloadTests {
    @Test func groupsOptionsWithQuantities() throws {
        var item = CartItem(productId: 10, productName: "Coffee", categoryId: 3,
                            skuId: 101, skuName: "Large", price: 50, quantity: 2)
        item.customizations = [
            SelectedCustomization(customizationId: 5, customizationName: "Toppings",
                                  optionId: 12, optionName: "Oat", price: 0.8, quantity: 1),
            SelectedCustomization(customizationId: 5, customizationName: "Toppings",
                                  optionId: 11, optionName: "Shot", price: 1.5, quantity: 2),
        ]

        let data = try JSONEncoder().encode(item.customizationRequests)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"customizationId\":5"))
        #expect(json.contains("\"customizationOptionId\":11"))
        #expect(json.contains("\"quantity\":2"))

        struct Option: Decodable { let customizationOptionId: Int; let quantity: Int }
        struct Group: Decodable { let customizationId: Int; let options: [Option] }
        let decoded = try JSONDecoder().decode([Group].self, from: data)
        #expect(decoded.count == 1)
        #expect(decoded[0].options.map(\.customizationOptionId) == [11, 12])
        #expect(decoded[0].options.map(\.quantity) == [2, 1])
    }

    @Test func selectedOptionDefaultsToQuantityOne() throws {
        let item = CartItem(productId: 10, productName: "Coffee", categoryId: 3,
                            skuId: 101, skuName: "Large", price: 50, quantity: 1,
                            customizations: [
                                SelectedCustomization(customizationId: 5, customizationName: "Size",
                                                      optionId: 11, optionName: "Large",
                                                      price: 1.5),
                            ])

        let data = try JSONEncoder().encode(item.customizationRequests)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains("\"quantity\":1"))
    }

    @Test func productQuantityStaysSeparateFromOptionQuantity() {
        var item = CartItem(productId: 10, productName: "Coffee", categoryId: 3,
                            skuId: 101, skuName: "Large", price: 50, quantity: 3)
        item.customizations = [
            SelectedCustomization(customizationId: 5, customizationName: "Toppings",
                                  optionId: 11, optionName: "Shot", price: 1.5, quantity: 2),
        ]

        #expect(item.quantity == 3)
        #expect(item.customizationRequests[0].options[0].quantity == 2)
    }
}
