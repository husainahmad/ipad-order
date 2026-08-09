import Foundation
import Combine

final class OrderTab: ObservableObject, Identifiable {
    let id: Int
    let label: String
    @Published var items: [CartItem]
    @Published var customer: String
    @Published var discount: String
    @Published var remark: String
    @Published var categories: [Category] = []
    @Published var products: [Product] = []
    @Published var selectedCategoryId: Int?
    @Published var loadingCategories = false
    @Published var loadingProducts = false
    @Published var error: String?

    init(id: Int, label: String) {
        self.id = id
        self.label = label
        self.items = []
        self.customer = ""
        self.discount = "0"
        self.remark = ""
    }

    var subtotal: Double {
        items.reduce(0) { $0 + $1.lineTotal }
    }
}

final class OrderFormViewModel: ObservableObject {

    @Published private(set) var tabs: [OrderTab] = []
    @Published var selectedPage: Int = 0
    @Published var submitting = false
    @Published var error: String?
    @Published var confirmedOrder: Order?

    private var sequence = 0

    var activeTab: OrderTab? {
        tabs.first { $0.id == selectedPage }
    }

    var cart: [CartItem] {
        activeTab?.items ?? []
    }

    var activeDiscount: Double {
        guard let tab = activeTab else { return 0 }
        return Double(tab.discount.isEmpty ? "0" : tab.discount) ?? 0
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
        activeTab?.customer = value
    }

    func setDiscount(_ value: String) {
        activeTab?.discount = value
    }

    func setRemark(_ value: String) {
        activeTab?.remark = value
    }

    func addToCart(product: Product, sku: Sku) {
        guard let tab = activeTab else { return }
        if let index = tab.items.firstIndex(where: { $0.productId == product.id && $0.skuId == sku.id }) {
            tab.items[index].addQuantity(1)
        } else {
            tab.items.append(CartItem(productId: product.id,
                                      productName: product.nameValue,
                                      categoryId: product.categoryId ?? 0,
                                      skuId: sku.id,
                                      skuName: sku.name ?? "",
                                      price: sku.price,
                                      quantity: 1))
        }
    }

    func increment(productId: Int, skuId: Int) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.productId == productId && $0.skuId == skuId }) else { return }
        tab.items[index].addQuantity(1)
    }

    func decrement(productId: Int, skuId: Int) {
        guard let tab = activeTab,
              let index = tab.items.firstIndex(where: { $0.productId == productId && $0.skuId == skuId }) else { return }
        tab.items[index].addQuantity(-1)
        if tab.items[index].quantity <= 0 {
            tab.items.remove(at: index)
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

    func resetConfirmedOrder() {
        confirmedOrder = nil
    }

    func reset() {
        tabs.removeAll()
        selectedPage = 0
        submitting = false
        error = nil
        confirmedOrder = nil
        sequence = 0
    }

    func confirmOrder(customerName: String, discount: String, remark: String) async -> Bool {
        guard let tab = activeTab, !tab.items.isEmpty else {
            error = "Cart is empty"
            return false
        }
        error = nil
        submitting = true
        defer { submitting = false }

        let request = buildRequest(tab: tab, customerName: customerName,
                                   discount: discount, remark: remark)
        do {
            let order = try await APIClient.shared.confirmOrder(request)
            confirmedOrder = order
            return true
        } catch let apiError as ApiError {
            if case .http(let code) = apiError {
                error = "Confirm order failed: HTTP \(code)"
            } else {
                error = apiError.localizedDescription
            }
            return false
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
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
                OrderDetailSkuRequest(skuId: $0.skuId, skuName: $0.skuName, quantity: $0.quantity)
            }
            details.append(OrderDetailRequest(productId: first.productId,
                                              productName: first.productName,
                                              categoryId: first.categoryId,
                                              orderDetailSkus: skus))
        }
        return OrderRequest(customerName: customerName, remark: remark,
                            orderDetails: details, discount: discount)
    }
}
