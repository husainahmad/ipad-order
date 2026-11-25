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

    /// Rebuilds a tab from a draft saved before the app was signed out or closed.
    init(draft: PersistedOrderTab) {
        self.id = draft.id
        self.label = draft.label
        self.items = draft.items
        self.customer = draft.customer
        self.customerRecord = draft.customerRecord
        self.discount = draft.discount
        self.remark = draft.remark
        self.storeServiceTypesId = draft.storeServiceTypesId
        self.idempotencyKey = draft.idempotencyKey
    }

    var draft: PersistedOrderTab {
        PersistedOrderTab(id: id,
                          label: label,
                          items: items,
                          customer: customer,
                          customerRecord: customerRecord,
                          discount: discount,
                          remark: remark,
                          storeServiceTypesId: storeServiceTypesId,
                          idempotencyKey: idempotencyKey)
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

    // MARK: - Draft persistence

    /// Drafts are keyed by cashier so a different login on the same tablet cannot
    /// surface the previous person's open cart.
    private static func draftsKey() -> String {
        let user = TokenManager.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return "pos_order_drafts_v1_" + (user.isEmpty ? "default" : user)
    }

    /// Writes the open orders to disk. Called after every order-affecting edit, so a
    /// sign-out — expected or not — never costs the cashier the cart.
    private func persistDrafts() {
        guard let data = try? JSONEncoder().encode(tabs.map(\.draft)) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftsKey())
    }

    /// Brings back open orders saved before the last sign-out. Idempotent: it only
    /// fills an empty tab list so a live cart is never overwritten.
    func restoreDrafts() {
        guard tabs.isEmpty else { return }
        guard let data = UserDefaults.standard.data(forKey: Self.draftsKey()),
              let drafts = try? JSONDecoder().decode([PersistedOrderTab].self, from: data),
              !drafts.isEmpty else { return }
        tabs = drafts.map(OrderTab.init(draft:))
        sequence = drafts.map(\.id).max() ?? 0
        selectedPage = 0
    }

    @discardableResult
    func createNewTab() -> Int {
        sequence += 1
        let tab = OrderTab(id: sequence, label: String(format: "Order #%03d", sequence))
        tabs.append(tab)
        error = nil
        selectedPage = tab.id
        persistDrafts()
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
        persistDrafts()
    }

    /// Binds a registered customer to the order. The name travels with the id so a
    /// receipt and the order row stay readable without a second lookup.
    func selectCustomer(_ customer: Customer) {
        guard let tab = activeTab else { return }
        tab.customerRecord = customer
        tab.customer = customer.nameValue.isEmpty ? customer.phoneValue : customer.nameValue
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    /// Returns the order to a walk-in: no id, no name.
    func clearCustomer() {
        guard let tab = activeTab else { return }
        tab.customerRecord = nil
        tab.customer = ""
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    func setDiscount(_ value: String) {
        guard let tab = activeTab, tab.discount != value else { return }
        tab.discount = value
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    func setRemark(_ value: String) {
        guard let tab = activeTab, tab.remark != value else { return }
        tab.remark = value
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    func setStoreServiceType(_ id: Int) {
        guard let tab = activeTab, tab.storeServiceTypesId != id else { return }
        tab.storeServiceTypesId = id
        invalidatePendingOrder(tab)
        persistDrafts()
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
                   quantity: Int = 1, remark: String? = nil) {
        guard let tab = activeTab else { return }
        let qty = max(1, quantity)
        let note = normalizedRemark(remark)
        let key = CartItem.lineKey(productId: product.id, skuId: sku.id,
                                   optionIds: customizations.flatOptionIds, remark: note)
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
                                      customizations: customizations,
                                      remark: note))
        }
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    /// Trims a kitchen note and treats whitespace-only input as no note, so the
    /// line key does not grow a separator for a note that will not print.
    private func normalizedRemark(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    func increment(lineKey: String) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.lineKey == lineKey }) else { return }
        tab.items[index].addQuantity(1)
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    func decrement(lineKey: String) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.lineKey == lineKey }) else { return }
        tab.items[index].addQuantity(-1)
        if tab.items[index].quantity <= 0 {
            tab.items.remove(at: index)
        }
        invalidatePendingOrder(tab)
        persistDrafts()
    }

    func removeItem(lineKey: String) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.lineKey == lineKey }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            tab.items.remove(at: index)
        }
        invalidatePendingOrder(tab)
        persistDrafts()
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
        persistDrafts()
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

    /// Groups cart lines by product and line note. The order service stores the
    /// note on `order_details`, one row per group, so two SKUs of the same product
    /// with different notes must travel as two groups or one note would be lost.
    private struct OrderLineGroupKey: Hashable {
        let productId: Int
        let remark: String?
    }

    private func buildRequest(tab: OrderTab, customerName: String,
                              discount: String, remark: String) -> OrderRequest {
        var grouped: [OrderLineGroupKey: [CartItem]] = [:]
        for item in tab.items {
            let key = OrderLineGroupKey(productId: item.productId, remark: item.remark)
            grouped[key, default: []].append(item)
        }
        let sortedGroups = grouped.values.sorted {
            let left = ($0.first?.productName ?? "", $0.first?.remark ?? "")
            let right = ($1.first?.productName ?? "", $1.first?.remark ?? "")
            return left < right
        }
        var details: [OrderDetailRequest] = []
        for group in sortedGroups {
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
                                              orderDetailSkus: skus,
                                              remark: first.remark))
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

/// The part of an open order that survives a sign-out or an app restart. The
/// server-side confirmed order is deliberately not stored: the idempotency key is,
/// so confirming again returns the same order instead of creating a duplicate.
struct PersistedOrderTab: Codable {
    let id: Int
    let label: String
    let items: [CartItem]
    let customer: String
    let customerRecord: Customer?
    let discount: String
    let remark: String
    let storeServiceTypesId: Int
    let idempotencyKey: String
}
