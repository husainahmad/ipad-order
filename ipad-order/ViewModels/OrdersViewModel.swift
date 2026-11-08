import Foundation
import Combine

final class OrdersViewModel: ObservableObject {

    @Published var loading = false
    @Published var error: String?
    @Published var orders: [Order] = []

    /// True while the next page is being fetched. Kept separate from `loading` so the list
    /// keeps showing what it has instead of dropping back to skeletons.
    @Published private(set) var loadingMore = false
    /// False once the last page has been read, which stops the list asking again.
    @Published private(set) var hasMore = true

    /// The cursor for the next page: the id of the last order the list holds.
    private var nextCursor: Int?
    /// How many orders a page holds. 50 fills a good deal more than the iPad screen.
    private let pageSize = 50

    /// Loads the first page, replacing whatever is on screen.
    ///
    /// `showLoading` is false for a silent refresh (pull-to-refresh after a payment), where
    /// flicking the whole list back to skeletons would be worse than a brief pause.
    @MainActor
    func loadOrders(showLoading: Bool = true) async {
        if showLoading { loading = true }
        defer { if showLoading { loading = false } }
        do {
            let page = try await APIClient.shared.dailyOrdersPage(limit: pageSize)
            orders = page.orders
            nextCursor = page.nextCursor
            // `hasMore` is the server's answer; a page without a cursor is the last one.
            hasMore = page.hasMore ?? (page.nextCursor != nil)
            error = nil
        } catch let apiError as ApiError {
            if case .http(let code) = apiError {
                self.error = L10n.t("Failed to load orders: HTTP %d", code)
            } else {
                self.error = apiError.localizedDescription
            }
        } catch {
            self.error = L10n.t("Network error: %@", error.localizedDescription)
        }
    }

    /// Appends the next page. A no-op at the end of the list, or while a page is in flight —
    /// the bottom sentinel reappears on every scroll and must not stack requests.
    @MainActor
    func loadMore() async {
        guard hasMore, !loadingMore, !loading, let cursor = nextCursor else { return }
        loadingMore = true
        defer { loadingMore = false }
        do {
            let page = try await APIClient.shared.dailyOrdersPage(limit: pageSize, beforeId: cursor)
            // Guard against a duplicate id arriving from a page overlap or a refresh that
            // landed mid-request: SwiftUI keys the rows by id and would misbehave on a repeat.
            let known = Set(orders.map(\.id))
            orders.append(contentsOf: page.orders.filter { !known.contains($0.id) })
            nextCursor = page.nextCursor
            hasMore = page.hasMore ?? (page.nextCursor != nil)
        } catch {
            // A failed page leaves the list intact and the cursor unadvanced, so scrolling
            // again retries rather than skipping the page.
            self.error = L10n.t("Failed to load more: %@", error.localizedDescription)
        }
    }

    /// Reloads the first page after a change, keeping the current rows on screen.
    @MainActor
    func refresh() async {
        await loadOrders(showLoading: false)
    }

    @MainActor
    func loadSettlement() async -> Settlement? {
        let today = TimeUtils.todayDate()
        let start = today + "T00:00:00"
        let end = today + "T23:59:59"
        do {
            return try await APIClient.shared.settlement(start: start, end: end)
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func voidOrder(_ orderId: Int) async -> Bool {
        do {
            try await APIClient.shared.voidOrder(orderId)
            return true
        } catch {
            return false
        }
    }
}
