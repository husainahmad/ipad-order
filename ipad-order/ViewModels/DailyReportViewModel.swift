import Foundation
import Combine

final class DailyReportViewModel: ObservableObject {

    struct Row: Identifiable {
        let id = UUID()
        let date: String
        let productName: String
        let quantity: Int
        let netSales: Double
        let discount: Double
    }

    @Published var loading = false
    @Published var error: String?
    @Published var rows: [Row] = []
    @Published var volume: OrderVolume?

    @MainActor
    func load(startDate: String, endDate: String) async {
        loading = true
        defer { loading = false }
        let start = startDate + "T00:00:00"
        let end = endDate + "T23:59:59"
        do {
            let data = try await APIClient.shared.dailyReport(start: start, end: end)
            rows = Self.flatten(data)
            error = nil
        } catch let apiError as ApiError {
            if case .http(let code) = apiError {
                self.error = "Failed to load report: HTTP \(code)"
            } else {
                self.error = apiError.localizedDescription
            }
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
        }

        if let volume = try? await APIClient.shared.orderVolume(start: start, end: end) {
            self.volume = volume
        }
    }

    private static func flatten(_ data: [DailyReportRow]) -> [Row] {
        var result: [Row] = []
        for row in data {
            if let products = row.products {
                for product in products {
                    result.append(Row(date: row.date ?? "",
                                      productName: product.productName ?? "",
                                      quantity: product.quantity ?? 0,
                                      netSales: product.netSales ?? 0,
                                      discount: product.discount ?? 0))
                }
            }
        }
        return result
    }

    var totals: (qty: Int, net: Double, discount: Double) {
        var qty = 0
        var net = 0.0
        var discount = 0.0
        for row in rows {
            qty += row.quantity
            net += row.netSales
            discount += row.discount
        }
        return (qty, net, discount)
    }
}
