import Foundation
import Combine

final class OrdersViewModel: ObservableObject {

    @Published var loading = false
    @Published var error: String?
    @Published var orders: [Order] = []

    @MainActor
    func loadOrders() async {
        loading = true
        defer { loading = false }
        do {
            orders = try await APIClient.shared.dailyOrders()
            error = nil
        } catch let apiError as ApiError {
            if case .http(let code) = apiError {
                self.error = "Failed to load orders: HTTP \(code)"
            } else {
                self.error = apiError.localizedDescription
            }
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
        }
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
