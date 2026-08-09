import Foundation

enum PrintUtils {

    static func buildReceiptText(_ order: Order) -> String {
        var sb = ""
        sb += "KOPI HARMONI\n"
        sb += "----------------------------\n"
        sb += "Order  : \(order.orderNoValue)\n"
        sb += "Date   : \(TimeUtils.toJakarta(order.createdAtValue))\n"
        sb += "Cust   : \(order.customerNameValue)\n"
        sb += "----------------------------\n"
        if let details = order.orderDetails {
            for detail in details {
                sb += "\(detail.productName ?? "")\n"
                if let skus = detail.orderDetailSkus {
                    for sku in skus {
                        let line = String(format: "  %@  %.0f x %.0f = %.0f\n",
                                          sku.skuName ?? "",
                                          sku.quantity ?? 0,
                                          sku.price ?? 0,
                                          sku.amount ?? 0)
                        sb += line
                    }
                }
            }
        }
        sb += "----------------------------\n"
        sb += "Sub Total : \(CurrencyUtils.formatRp(order.subTotalValue))\n"
        sb += "Discount  : \(CurrencyUtils.formatRp(order.discountTotalValue))\n"
        sb += "TOTAL     : \(CurrencyUtils.formatRp(order.grandTotalValue))\n"
        sb += "Payment   : \(order.paymentName)\n"
        if !order.remarkValue.isEmpty {
            sb += "Note      : \(order.remarkValue)\n"
        }
        sb += "----------------------------\n"
        sb += "Terima kasih\n"
        return sb
    }

    static func buildKitchenText(_ order: Order) -> String {
        var sb = ""
        sb += "KOPI HARMONI - KP\n"
        sb += "----------------------------\n"
        sb += "Order  : \(order.orderNoValue)\n"
        if let details = order.orderDetails {
            for detail in details {
                sb += "\(detail.productName ?? "")\n"
                if let skus = detail.orderDetailSkus {
                    for sku in skus {
                        sb += String(format: "  %@ x %d\n", sku.skuName ?? "", Int(sku.quantity ?? 0))
                    }
                }
            }
        }
        sb += "----------------------------\n"
        return sb
    }

    static func buildSettlementText(_ settlement: Settlement) -> String {
        var sb = ""
        sb += "KOPI HARMONI\n"
        sb += "SETTLEMENT\n"
        sb += "----------------------------\n"
        sb += "Total Orders   : \(settlement.totalOrdersValue)\n"
        sb += "Total Sales    : \(CurrencyUtils.formatRp2(settlement.totalSalesValue))\n"
        sb += "Total Discount : \(CurrencyUtils.formatRp2(settlement.totalDiscountsValue))\n"
        sb += "Total Tax      : \(CurrencyUtils.formatRp2(settlement.totalTaxValue))\n"
        sb += "Net Sales      : \(CurrencyUtils.formatRp2(settlement.totalNetSalesValue))\n"
        if let breakdown = settlement.paymentBreakdown {
            for (key, value) in breakdown.sorted(by: { $0.key < $1.key }) {
                sb += "\(key) : \(CurrencyUtils.formatRp2(value))\n"
            }
        }
        sb += "----------------------------\n"
        return sb
    }

    static func buildSettlementDialogText(_ settlement: Settlement) -> String {
        var sb = ""
        sb += "Total Orders : \(settlement.totalOrdersValue)\n"
        sb += "Total Sales : \(CurrencyUtils.formatRp2(settlement.totalSalesValue))\n"
        sb += "Total Discounts : \(CurrencyUtils.formatRp2(settlement.totalDiscountsValue))\n"
        sb += "Total Tax : \(CurrencyUtils.formatRp2(settlement.totalTaxValue))\n"
        sb += "Total Net Sales : \(CurrencyUtils.formatRp2(settlement.totalNetSalesValue))\n\n"
        if let breakdown = settlement.paymentBreakdown {
            for (key, value) in breakdown.sorted(by: { $0.key < $1.key }) {
                sb += "\(key) : \(CurrencyUtils.formatRp2(value))\n"
            }
        }
        return sb
    }

    static func buildSettlementPrintText(_ settlement: Settlement) -> String {
        var sb = "== SETTLEMENT REPORT =="
        sb += "\nTotal Orders : \(settlement.totalOrdersValue)"
        sb += "\nTotal Sales : \(CurrencyUtils.formatRp2(settlement.totalSalesValue))"
        sb += "\nTotal Discounts : \(CurrencyUtils.formatRp2(settlement.totalDiscountsValue))"
        sb += "\nTotal Tax : \(CurrencyUtils.formatRp2(settlement.totalTaxValue))"
        sb += "\nTotal Net Sales : \(CurrencyUtils.formatRp2(settlement.totalNetSalesValue))"
        sb += "\n\nPayment Breakdown:"
        if let breakdown = settlement.paymentBreakdown {
            for (key, value) in breakdown.sorted(by: { $0.key < $1.key }) {
                sb += "\n\(key) : \(CurrencyUtils.formatRp2(value))"
            }
        }
        return sb
    }
}
