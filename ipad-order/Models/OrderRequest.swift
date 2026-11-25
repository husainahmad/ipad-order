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
    /// Kitchen instruction for this product group. Lines of the same product with
    /// different notes travel as separate groups, because the order service stores
    /// the note on the order detail, not on the SKU line.
    let remark: String?
    let orderDetailSkus: [OrderDetailSkuRequest]

    init(productId: Int, productName: String, categoryId: Int,
         orderDetailSkus: [OrderDetailSkuRequest], remark: String? = nil) {
        self.productId = productId
        self.productName = productName
        self.categoryId = categoryId
        self.orderDetailSkus = orderDetailSkus
        self.remark = remark
    }
}

struct OrderRequest: Codable {
    let storeServiceTypesId: Int
    let customerName: String
    /// The customer service's id, or `-1` for a walk-in. The order service stores
    /// this on `orders.customer_id` and uses it to key customer history, so it is
    /// the part of the customer that actually links a sale to a person.
    let customerId: Int
    /// Repeats the phone onto the order row, which keeps a historic receipt readable
    /// after the customer record is edited or soft-deleted.
    let customerPhone: String
    let remark: String
    let orderDetails: [OrderDetailRequest]
    let discount: String

    init(storeServiceTypesId: Int = 1,
         customerName: String,
         customerId: Int = -1,
         customerPhone: String = "",
         remark: String,
         orderDetails: [OrderDetailRequest],
         discount: String) {
        self.storeServiceTypesId = storeServiceTypesId
        self.customerName = customerName
        self.customerId = customerId
        self.customerPhone = customerPhone
        self.remark = remark
        self.orderDetails = orderDetails
        self.discount = discount
    }
}

struct PaymentRequest: Codable {
    let orderId: Int
    let paymentId: Int
}
