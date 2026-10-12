import Foundation

/// One customization choice on a line. Three extra shots is a single entry with
/// `quantity = 3`, not three entries. Only the option id travels: the menu service
/// resolves the names and prices at the operator's tier, so a client cannot name
/// its own price for a customised item.
struct OrderCustomizationRequest: Codable {
    let customizationOptionId: Int
    let quantity: Int

    init(customizationOptionId: Int, quantity: Int) {
        self.customizationOptionId = customizationOptionId
        self.quantity = quantity
    }
}

/// One customization group on a line, matching the order service shape:
/// `{ "customizationId": 5, "options": [{ "customizationOptionId": 11, "quantity": 1 }] }`.
/// The group id is required — the menu service refuses an option sent under a
/// group it does not belong to.
struct OrderCustomizationGroupRequest: Codable {
    let customizationId: Int
    let options: [OrderCustomizationRequest]

    init(customizationId: Int, options: [OrderCustomizationRequest]) {
        self.customizationId = customizationId
        self.options = options
    }
}

struct OrderDetailSkuRequest: Codable {
    let skuId: Int
    let skuName: String
    let quantity: Int
    let customizations: [OrderCustomizationGroupRequest]

    init(skuId: Int, skuName: String, quantity: Int,
         customizations: [OrderCustomizationGroupRequest] = []) {
        self.skuId = skuId
        self.skuName = skuName
        self.quantity = quantity
        self.customizations = customizations
    }
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
