import Foundation
import Testing
@testable import ipad_order

// MARK: - Choices belong to a SKU line
//
// A product sold as two variants keeps one customization group per line: Big ordered Hot,
// Regular ordered Ice. Rendering every group under the product made a receipt read as if a
// single cup were both hot and iced.

struct SkuAttachedCustomizationTests {

    private func option(_ name: String, id: Int = 1, quantity: Int = 1,
                        price: Double = 0, amount: Double = 0) -> OrderCustomizationOption {
        OrderCustomizationOption(customizationOptionsId: id, customizationOptionName: name,
                                 quantity: quantity, price: price, amount: amount,
                                 id: nil, name: nil)
    }

    private func group(_ name: String, skuId: Int?, options: [OrderCustomizationOption]) -> OrderDetailCustomization {
        OrderDetailCustomization(customizationId: 5, customizationName: name,
                                 orderDetailSkuId: skuId, options: options)
    }

    private func detail(customizations: [OrderDetailCustomization]) -> OrderDetail {
        OrderDetail(productName: "Caramel Macchiato", categoryId: 1,
                    orderDetailSkus: [
                        OrderDetailSku(id: 9001, skuId: 100, skuName: "Big", quantity: 1, price: 50_000, amount: 50_000),
                        OrderDetailSku(id: 9002, skuId: 200, skuName: "Regular", quantity: 1, price: 40_000, amount: 40_000)
                    ],
                    customizations: customizations)
    }

    @Test func eachVariantShowsOnlyItsOwnChoices() {
        let detail = detail(customizations: [
            group("Temperature", skuId: 9001, options: [option("Hot")]),
            group("Temperature", skuId: 9002, options: [option("Ice")])
        ])
        let big = detail.orderDetailSkus![0]
        let regular = detail.orderDetailSkus![1]

        #expect(detail.customizations(forSku: big).flatMap { $0.items }.map(\.optionNameValue) == ["Hot"])
        #expect(detail.customizations(forSku: regular).flatMap { $0.items }.map(\.optionNameValue) == ["Ice"])
        #expect(detail.unattachedCustomizationsByGroup.isEmpty)
    }

    @Test func aVariantWithNoChoicesShowsNone() {
        let detail = detail(customizations: [
            group("Temperature", skuId: 9001, options: [option("Hot")])
        ])
        let regular = detail.orderDetailSkus![1]

        #expect(detail.customizations(forSku: regular).isEmpty)
    }

    @Test func choicesStillMatchWhenTheResponseOmitsTheRowId() throws {
        // The order service's SKU result map once aliased the row id as skuId and dropped
        // id entirely, which left every line looking uncustomised. The catalogue id is the
        // fallback so such a response still renders its choices.
        let json = """
        {"productName":"Latte","categoryId":1,"orderDetailSkus":[        {"skuId":22820,"skuName":"Big","quantity":1}],        "customizations":[{"customizationId":5,"customizationName":"Temperature",        "orderDetailSkuId":22820,"options":[{"customizationOptionName":"Hot"}]}]}
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(OrderDetail.self, from: json)
        let groups = detail.customizations(forSku: detail.orderDetailSkus!.first!)
        #expect(groups.flatMap { $0.items }.map(\.optionNameValue) == ["Hot"])
    }

    @Test func choicesWithNoLineAreKeptAsUnattached() {
        // Rows written before the order service recorded the line id.
        let detail = detail(customizations: [
            group("Temperature", skuId: nil, options: [option("Ice")])
        ])

        #expect(detail.customizations(forSku: detail.orderDetailSkus![0]).isEmpty)
        #expect(detail.unattachedCustomizationsByGroup.flatMap { $0.items }.map(\.optionNameValue) == ["Ice"])
    }

    @Test func theReceiptPrintsChoicesUnderTheirOwnVariant() throws {
        let order = Order(id: 1, orderNo: "ORD-1", customerName: "Ada", remark: "",
                          status: "PAID", storeServiceTypesId: 1,
                          subTotal: 90_000, discountTotal: 0, grandTotal: 90_000,
                          createdAt: "", orderPayment: nil,
                          orderDetails: [detail(customizations: [
                              group("Temperature", skuId: 9001, options: [option("Hot")]),
                              group("Temperature", skuId: 9002, options: [option("Ice")])
                          ])])

        let text = PrintUtils.buildReceiptText(order)
        let bigIndex = try #require(text.range(of: "Big"))
        let regularIndex = try #require(text.range(of: "Regular"))
        let hotIndex = try #require(text.range(of: "Hot"))
        let iceIndex = try #require(text.range(of: "Ice"))

        // Hot must fall between Big and Regular; Ice after Regular.
        #expect(bigIndex.lowerBound < hotIndex.lowerBound)
        #expect(hotIndex.lowerBound < regularIndex.lowerBound)
        #expect(regularIndex.lowerBound < iceIndex.lowerBound)
    }

    @Test func theSkuIdIsDecodedSoChoicesCanBeAttached() throws {
        let json = """
        {"productName":"Latte","categoryId":1,"orderDetailSkus":[\
        {"id":9001,"skuName":"Big","quantity":1,"price":50000,"amount":50000}],\
        "customizations":[{"customizationId":5,"customizationName":"Temperature",\
        "orderDetailSkuId":9001,"options":[{"customizationOptionsId":12,\
        "customizationOptionName":"Hot","quantity":1,"price":0,"amount":0}]}]}
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(OrderDetail.self, from: json)
        #expect(detail.orderDetailSkus?.first?.id == 9001)
        #expect(detail.customizations?.first?.orderDetailSkuId == 9001)
        #expect(detail.customizations(forSku: detail.orderDetailSkus!.first!)
            .flatMap { $0.items }.map(\.optionNameValue) == ["Hot"])
    }

    @Test func anOrderWithoutTheLineIdStillDecodes() throws {
        // Older responses carry no orderDetailSkuId at all.
        let json = """
        {"productName":"Latte","categoryId":1,"orderDetailSkus":[{"skuName":"Big"}],\
        "customizations":[{"customizationId":5,"customizationName":"Temperature",\
        "options":[{"customizationOptionName":"Hot"}]}]}
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(OrderDetail.self, from: json)
        #expect(detail.customizations?.first?.orderDetailSkuId == nil)
        #expect(detail.unattachedCustomizationsByGroup.flatMap { $0.items }.map(\.optionNameValue) == ["Hot"])
    }
}
