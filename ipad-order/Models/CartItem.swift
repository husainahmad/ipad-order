import Foundation

struct CartItem: Identifiable, Hashable {
    let productId: Int
    let productName: String
    let categoryId: Int
    let skuId: Int
    let skuName: String
    let price: Double
    var quantity: Int

    var id: Int { productId * 100000 + skuId }

    var lineTotal: Double { price * Double(quantity) }

    mutating func addQuantity(_ delta: Int) {
        quantity = max(0, quantity + delta)
    }
}
