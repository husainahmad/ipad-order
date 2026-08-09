import Foundation

struct Settlement: Codable {
    let totalOrders: Int?
    let totalSales: Double?
    let totalDiscounts: Double?
    let totalTax: Double?
    let totalNetSales: Double?
    let paymentBreakdown: [String: Double]?

    var totalOrdersValue: Int { totalOrders ?? 0 }
    var totalSalesValue: Double { totalSales ?? 0 }
    var totalDiscountsValue: Double { totalDiscounts ?? 0 }
    var totalTaxValue: Double { totalTax ?? 0 }
    var totalNetSalesValue: Double { totalNetSales ?? 0 }
}

struct SalesReportRow: Codable, Hashable, Identifiable {
    let categoryName: String?
    let productName: String?
    let quantity: Int?
    let grossSales: Double?
    let discount: Double?
    let netSales: Double?

    var id: String { (categoryName ?? "") + "|" + (productName ?? "") }

    var categoryNameValue: String { categoryName ?? "" }
    var productNameValue: String { productName ?? "" }
    var quantityValue: Int { quantity ?? 0 }
    var grossSalesValue: Double { grossSales ?? 0 }
    var discountValue: Double { discount ?? 0 }
    var netSalesValue: Double { netSales ?? 0 }
}

struct DailyReportRow: Codable, Hashable {
    let date: String?
    let products: [ProductRow]?

    struct ProductRow: Codable, Hashable {
        let productName: String?
        let quantity: Int?
        let netSales: Double?
        let discount: Double?
    }
}

struct OrderVolume: Codable {
    let totalOrders: Int?
    let peakTimeOrders: Int?
    let nonPeakTimeOrders: Int?

    var totalOrdersValue: Int { totalOrders ?? 0 }
    var peakTimeOrdersValue: Int { peakTimeOrders ?? 0 }
    var nonPeakTimeOrdersValue: Int { nonPeakTimeOrders ?? 0 }
}
