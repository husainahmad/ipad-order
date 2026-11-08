import Foundation
import Combine
import SwiftUI

final class OrderTab: ObservableObject, Identifiable {
    let id: Int
    let label: String
    @Published var items: [CartItem]
    @Published var customer: String
    /// The registered customer this order belongs to, when the cashier picked one
    /// from a search. `nil` means a walk-in and the order travels with `customerId`
    /// `-1`, which is what the order service has always used for that case.
    @Published var customerRecord: Customer?
    @Published var discount: String
    @Published var remark: String
    @Published var storeServiceTypesId: Int = 1
    @Published var categories: [Category] = []
    @Published var products: [Product] = []
    @Published var selectedCategoryId: Int?
    @Published var loadingCategories = false
    @Published var loadingProducts = false
    /// Cursor for the next product page; nil on a fresh category or the last page.
    @Published var productsNextCursor: Int?
    @Published var productsHasMore = true
    @Published var loadingMoreProducts = false
    @Published var error: String?
    @Published var confirmedOrder: Order?
    @Published private(set) var idempotencyKey: String

    init(id: Int, label: String) {
        self.id = id
        self.label = label
        self.items = []
        self.customer = ""
        self.customerRecord = nil
        self.discount = "0"
        self.remark = ""
        self.idempotencyKey = UUID().uuidString
    }

    func rotateIdempotencyKey() {
        idempotencyKey = UUID().uuidString
        confirmedOrder = nil
    }

    var subtotal: Double {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    /// The registered customer this order can be filed under, given the name the
    /// till currently shows. Returns `nil` when the name was edited after picking
    /// someone — sending the stale id then would credit the sale to the wrong person.
    /// A customer with no name is matched by phone instead, which is what the cart
    /// displays for such a record.
    func linkedCustomer(typedName: String) -> Customer? {
        guard let record = customerRecord else { return nil }
        let typed = typedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let stillNamed = !record.nameValue.isEmpty && record.nameValue == typed
        let identifiedByPhone = record.nameValue.isEmpty && record.phoneValue == typed
        return (stillNamed || identifiedByPhone) ? record : nil
    }
}

final class OrderFormViewModel: ObservableObject {

    @Published private(set) var tabs: [OrderTab] = []
    @Published var selectedPage: Int = 0
    @Published var submitting = false
    @Published var error: String?
    @Published var confirmedOrder: Order?

    /// Customization groups per product, held for the session. A product's
    /// customizations decide whether it can be added straight to the cart or needs
    /// the option picker, so they are resolved once on first tap and reused.
    @Published private(set) var customizationsByProductId: [Int: [ProductCustomization]] = [:]
    @Published private(set) var loadingCustomizationProductId: Int?

    private var sequence = 0

    var activeTab: OrderTab? {
        tabs.first { $0.id == selectedPage }
    }

    var cart: [CartItem] {
        activeTab?.items ?? []
    }

    var activeDiscount: Double {
        guard let tab = activeTab else { return 0 }
        return Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0
    }

    var subtotal: Double {
        activeTab?.subtotal ?? 0
    }

    func handlePageSelection(_ page: Int) {
        selectedPage = page
        if page > 0 {
            error = ""
        }
    }

    @discardableResult
    func createNewTab() -> Int {
        sequence += 1
        let tab = OrderTab(id: sequence, label: String(format: "Order #%03d", sequence))
        tabs.append(tab)
        error = nil
        selectedPage = tab.id
        return tab.id
    }

    func tab(_ id: Int) -> OrderTab? {
        tabs.first { $0.id == id }
    }

    func setCustomer(_ value: String) {
        guard let tab = activeTab, tab.customer != value else { return }
        tab.customer = value
        // Typing a name by hand detaches the order from a registered customer: the
        // id would otherwise point at someone the cashier just renamed over.
        if tab.customerRecord?.nameValue != value {
            tab.customerRecord = nil
        }
        invalidatePendingOrder(tab)
    }

    /// Binds a registered customer to the order. The name travels with the id so a
    /// receipt and the order row stay readable without a second lookup.
    func selectCustomer(_ customer: Customer) {
        guard let tab = activeTab else { return }
        tab.customerRecord = customer
        tab.customer = customer.nameValue.isEmpty ? customer.phoneValue : customer.nameValue
        invalidatePendingOrder(tab)
    }

    /// Returns the order to a walk-in: no id, no name.
    func clearCustomer() {
        guard let tab = activeTab else { return }
        tab.customerRecord = nil
        tab.customer = ""
        invalidatePendingOrder(tab)
    }

    func setDiscount(_ value: String) {
        guard let tab = activeTab, tab.discount != value else { return }
        tab.discount = value
        invalidatePendingOrder(tab)
    }

    func setRemark(_ value: String) {
        guard let tab = activeTab, tab.remark != value else { return }
        tab.remark = value
        invalidatePendingOrder(tab)
    }

    func setStoreServiceType(_ id: Int) {
        guard let tab = activeTab, tab.storeServiceTypesId != id else { return }
        tab.storeServiceTypesId = id
        invalidatePendingOrder(tab)
    }

    func customizations(for productId: Int) -> [ProductCustomization] {
        customizationsByProductId[productId] ?? []
    }

    /// Resolves and memoises a product's customizations. Returns the groups so the
    /// caller can decide the tap behaviour without a second lookup.
    @discardableResult
    func loadCustomizations(productId: Int) async -> [ProductCustomization] {
        if let cached = customizationsByProductId[productId] { return cached }
        loadingCustomizationProductId = productId
        defer { if loadingCustomizationProductId == productId { loadingCustomizationProductId = nil } }
        do {
            let groups = try await APIClient.shared.productCustomizations(productId)
            customizationsByProductId[productId] = groups
            return groups
        } catch let apiError as ApiError {
            error = apiError.localizedDescription
            customizationsByProductId[productId] = []
            return []
        } catch {
            self.error = L10n.t("Network error: %@", error.localizedDescription)
            customizationsByProductId[productId] = []
            return []
        }
    }

    func addToCart(product: Product, sku: Sku, customizations: [SelectedCustomization] = [],
                   quantity: Int = 1) {
        guard let tab = activeTab else { return }
        let qty = max(1, quantity)
        let key = CartItem.lineKey(productId: product.id, skuId: sku.id,
                                   optionIds: customizations.flatOptionIds)
        if let index = tab.items.firstIndex(where: { $0.lineKey == key }) {
            tab.items[index].addQuantity(qty)
        } else {
            tab.items.append(CartItem(productId: product.id,
                                      productName: product.nameValue,
                                      categoryId: product.categoryId ?? 0,
                                      skuId: sku.id,
                                      skuName: sku.name ?? "",
                                      price: sku.price,
                                      quantity: qty,
                                      customizations: customizations))
        }
        invalidatePendingOrder(tab)
    }

    func increment(lineKey: String) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.lineKey == lineKey }) else { return }
        tab.items[index].addQuantity(1)
        invalidatePendingOrder(tab)
    }

    func decrement(lineKey: String) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.lineKey == lineKey }) else { return }
        tab.items[index].addQuantity(-1)
        if tab.items[index].quantity <= 0 {
            tab.items.remove(at: index)
        }
        invalidatePendingOrder(tab)
    }

    func removeItem(lineKey: String) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.lineKey == lineKey }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            tab.items.remove(at: index)
        }
        invalidatePendingOrder(tab)
    }

    /// Called whenever any order-affecting input changes. Clears the known
    /// confirmed order and rotates the idempotency key so a re-confirm with
    /// a changed cart is treated as a brand-new request.
    private func invalidatePendingOrder(_ tab: OrderTab) {
        tab.rotateIdempotencyKey()
        // The payment dialog reads `confirmedOrder` to decide which order to pay. An
        // edit leaves the old order stale on the server, so it is dropped here too —
        // otherwise a cashier who changes the customer and taps Pay would pay the
        // order as it was before the edit.
        if tab.id == activeTab?.id {
            confirmedOrder = nil
        }
    }

    @discardableResult
    func removeActiveTab() -> Int {
        removeTab(selectedPage)
    }

    @discardableResult
    func removeTab(_ id: Int) -> Int {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return -1 }
        tabs.remove(at: index)
        confirmedOrder = nil
        error = nil
        if tabs.isEmpty {
            selectedPage = 0
            return -1
        }
        let nextIndex = min(index, tabs.count - 1)
        let nextId = tabs[nextIndex].id
        selectedPage = nextId
        return nextId
    }

    

    func reset() {
        tabs.removeAll()
        selectedPage = 0
        submitting = false
        error = nil
        confirmedOrder = nil
        customizationsByProductId = [:]
        loadingCustomizationProductId = nil
        sequence = 0
    }

    func confirmOrder(customerName: String, discount: String, remark: String) async -> Bool {
        guard let tab = activeTab, !tab.items.isEmpty else {
            error = "Cart is empty"
            return false
        }
        error = nil

        // Idempotency: this cart was already confirmed (user closed the payment
        // screen without paying). Reuse the existing order instead of creating
        // a duplicate. invalidatePendingOrder() clears this on any cart change.
        if let existing = tab.confirmedOrder {
            confirmedOrder = existing
            return true
        }

        submitting = true
        defer { submitting = false }

        let request = buildRequest(tab: tab, customerName: customerName,
                                   discount: discount, remark: remark)
        do {
            let order = try await APIClient.shared.confirmOrder(request, idempotencyKey: tab.idempotencyKey)
            tab.confirmedOrder = order
            confirmedOrder = order
            return true
        } catch let apiError as ApiError {
            if case .http(let code) = apiError {
                error = L10n.t("Confirm order failed: HTTP %d", code)
            } else {
                error = apiError.localizedDescription
            }
            return false
        } catch {
            self.error = L10n.t("Network error: %@", error.localizedDescription)
            return false
        }
    }

    private func buildRequest(tab: OrderTab, customerName: String,
                              discount: String, remark: String) -> OrderRequest {
        var grouped: [Int: [CartItem]] = [:]
        for item in tab.items {
            grouped[item.productId, default: []].append(item)
        }
        var details: [OrderDetailRequest] = []
        for group in grouped.values.sorted(by: { $0.first?.productName ?? "" < $1.first?.productName ?? "" }) {
            guard let first = group.first else { continue }
            let skus = group.map {
                OrderDetailSkuRequest(skuId: $0.skuId,
                                      skuName: $0.skuName,
                                      quantity: $0.quantity,
                                      customizations: $0.customizationRequests)
            }
            details.append(OrderDetailRequest(productId: first.productId,
                                              productName: first.productName,
                                              categoryId: first.categoryId,
                                              orderDetailSkus: skus))
        }
        // Only a customer whose identity still matches the till input counts as
        // linked. The cashier may have renamed the order after picking someone;
        // sending the stale id then would credit the sale to the wrong person.
        let linked = tab.linkedCustomer(typedName: customerName)
        return OrderRequest(storeServiceTypesId: tab.storeServiceTypesId,
                            customerName: customerName,
                            customerId: linked?.id ?? -1,
                            customerPhone: linked?.phoneValue ?? "",
                            remark: remark,
                            orderDetails: details, discount: discount)
    }
}
