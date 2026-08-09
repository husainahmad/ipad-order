import Foundation
import Combine

final class SalesReportViewModel: ObservableObject {

    @Published var loading = false
    @Published var error: String?
    @Published var rows: [SalesReportRow] = []

    @MainActor
    func load(startDate: String, endDate: String) async {
        loading = true
        defer { loading = false }
        let start = startDate + "T00:00:00"
        let end = endDate + "T23:59:59"
        do {
            rows = try await APIClient.shared.salesReport(start: start, end: end)
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
    }

    var totals: (qty: Int, gross: Double, discount: Double, net: Double) {
        var qty = 0
        var gross = 0.0
        var discount = 0.0
        var net = 0.0
        for row in rows {
            qty += row.quantityValue
            gross += row.grossSalesValue
            discount += row.discountValue
            net += row.netSalesValue
        }
        return (qty, gross, discount, net)
    }
}
