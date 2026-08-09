import Foundation

struct OrderDetailSkuRequest: Codable {
    let skuId: Int
    let skuName: String
    let quantity: Int
}

struct OrderDetailRequest: Codable {
    let productId: Int
    let productName: String
    let categoryId: Int
    let orderDetailSkus: [OrderDetailSkuRequest]
}

struct OrderRequest: Codable {
    let storeServiceTypesId: Int
    let customerName: String
    let customerId: Int
    let remark: String
    let orderDetails: [OrderDetailRequest]
    let discount: String

    init(storeServiceTypesId: Int = 1,
         customerName: String,
         customerId: Int = -1,
         remark: String,
         orderDetails: [OrderDetailRequest],
         discount: String) {
        self.storeServiceTypesId = storeServiceTypesId
        self.customerName = customerName
        self.customerId = customerId
        self.remark = remark
        self.orderDetails = orderDetails
        self.discount = discount
    }
}

struct PaymentRequest: Codable {
    let orderId: Int
    let paymentId: Int
}
