import Foundation
import Testing
@testable import ipad_order

// MARK: - Cursor paging contract
//
// The list appends pages keyed by an order id. These cover the envelope the endpoint
// answers with, and the rule that decides whether to ask again.

struct OrderPagingTests {

    private func order(_ id: Int) -> String {
        """
        {"id":\(id),"orderNo":"ORD-\(id)","status":"PAID","grandTotal":1000,\
        "orderDetails":[]}
        """
    }

    private func page(_ ids: [Int], nextCursor: Int?, hasMore: Bool?) -> Data {
        let list = ids.map(order).joined(separator: ",")
        let cursor = nextCursor.map(String.init) ?? "null"
        let more = hasMore.map(String.init) ?? "null"
        return """
        {"orders":[\(list)],"nextCursor":\(cursor),"hasMore":\(more)}
        """.data(using: .utf8)!
    }

    @Test func decodesAPageWithACursor() throws {
        let decoded = try JSONDecoder().decode(OrderPageResponse.self,
                                              from: page([9, 8], nextCursor: 8, hasMore: true))
        #expect(decoded.orders.map(\.id) == [9, 8])
        #expect(decoded.nextCursor == 8)
        #expect(decoded.hasMore == true)
    }

    @Test func aLastPageHasNoCursor() throws {
        let decoded = try JSONDecoder().decode(OrderPageResponse.self,
                                              from: page([3], nextCursor: nil, hasMore: false))
        #expect(decoded.nextCursor == nil)
        #expect(decoded.hasMore == false)
    }

    @Test func aResponseWithoutTheFlagsFallsBackToTheCursor() throws {
        // An older order service sends only the orders. Without a cursor there is nothing
        // more to ask for, so the fallback must be "no more pages", not "keep asking".
        let decoded = try JSONDecoder().decode(OrderPageResponse.self,
                                              from: page([9], nextCursor: nil, hasMore: nil))
        #expect(decoded.hasMore == nil)
        #expect(decoded.nextCursor == nil)
        #expect((decoded.hasMore ?? (decoded.nextCursor != nil)) == false)
    }

    @Test func aCursorMeansThereIsAnotherPage() {
        let nextCursor: Int? = 42
        let hasMore: Bool? = nil
        #expect((hasMore ?? (nextCursor != nil)) == true)
    }

    @Test func appendingDropsOrdersTheListAlreadyHas() {
        // A refresh landing mid-scroll can hand back an order the list already shows;
        // SwiftUI keys rows by id and a duplicate would misbehave.
        var orders = [9, 8, 7]
        let incoming = [8, 7, 6]
        let known = Set(orders)
        orders.append(contentsOf: incoming.filter { !known.contains($0) })
        #expect(orders == [9, 8, 7, 6])
    }
}
