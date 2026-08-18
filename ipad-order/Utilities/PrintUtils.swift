import Foundation

enum PrintUtils {

    static let lineWidth = 32

    static func buildReceiptText(_ order: Order) -> String {
        var sb = ""
        sb += centered("KOPI HARMONI")
        sb += separator()
        sb += row("Order", order.orderNoValue)
        sb += row("Date", TimeUtils.toJakarta(order.createdAtValue))
        sb += row("Type", order.storeServiceName)
        sb += row("Cust", order.customerNameValue)
        sb += separator()
        if let details = order.orderDetails {
            for detail in details {
                sb += "\(detail.productName ?? "")\n"
                if let skus = detail.orderDetailSkus {
                    for sku in skus {
                        let left = "  \(sku.skuName ?? "") x\(Int(sku.quantity ?? 0))"
                        let right = CurrencyUtils.formatRp(sku.amount ?? 0)
                        sb += twoCol(left: left, right: right)
                        if (sku.price ?? 0) > 0 {
                            sb += twoCol(left: "  @ \(CurrencyUtils.formatRp(sku.price ?? 0))", right: "")
                        }
                    }
                }
            }
        }
        sb += separator()
        sb += twoCol(left: "Sub Total", right: CurrencyUtils.formatRp(order.subTotalValue))
        sb += twoCol(left: "Discount", right: CurrencyUtils.formatRp(order.discountTotalValue))
        sb += twoCol(left: "TOTAL", right: CurrencyUtils.formatRp(order.grandTotalValue))
        sb += twoCol(left: "Payment", right: order.paymentName)
        if !order.remarkValue.isEmpty {
            sb += twoCol(left: "Note", right: order.remarkValue)
        }
        sb += separator()
        sb += centered("Terima kasih")
        sb += centered("Sampai jumpa kembali!")
        return sb
    }

    static func buildKitchenText(_ order: Order) -> String {
        var sb = ""
        sb += centered("KOPI HARMONI - KP")
        sb += separator()
        sb += row("Order", order.orderNoValue)
        sb += row("Type", order.storeServiceName)
        sb += separator()
        if let details = order.orderDetails {
            for detail in details {
                sb += "\(detail.productName ?? "")\n"
                if let skus = detail.orderDetailSkus {
                    for sku in skus {
                        sb += twoCol(left: "  \(sku.skuName ?? "") x\(Int(sku.quantity ?? 0))", right: "")
                    }
                }
            }
        }
        sb += separator()
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

    // MARK: - Layout helpers

    static func separator() -> String {
        String(repeating: "-", count: lineWidth) + "\n"
    }

    static func centered(_ text: String, width: Int = lineWidth) -> String {
        let count = text.count
        if count >= width { return text + "\n" }
        let totalPad = width - count
        let leftPad = totalPad / 2
        let rightPad = totalPad - leftPad
        return String(repeating: " ", count: leftPad) + text
            + String(repeating: " ", count: rightPad) + "\n"
    }

    static func row(_ label: String, _ value: String, width: Int = lineWidth) -> String {
        twoCol(left: "\(label):", right: value, width: width)
    }

    static func twoCol(left: String, right: String, width: Int = lineWidth) -> String {
        var leftText = left
        var rightText = right
        let spaceNeeded = width - leftText.count - rightText.count
        if spaceNeeded < 1 {
            if rightText.isEmpty {
                leftText = String(leftText.prefix(width))
            } else {
                let maxLeft = max(4, width - rightText.count - 1)
                leftText = String(leftText.prefix(maxLeft))
            }
            return leftText + " " + rightText + "\n"
        }
        let padding = String(repeating: " ", count: spaceNeeded)
        return leftText + padding + rightText + "\n"
    }
}
