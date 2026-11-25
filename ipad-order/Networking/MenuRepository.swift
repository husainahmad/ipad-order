import Foundation

struct MenuRepository {

    func getCategories() async throws -> [Category] {
        if let cached = JsonCache.readCategories() {
            return cached
        }
        let data = try await APIClient.shared.categories()
        JsonCache.writeCategories(data)
        return data
    }

    func getProducts(categoryId: Int) async throws -> [Product] {
        if let cached = JsonCache.readProducts(categoryId: categoryId) {
            return cached
        }
        let data = try await APIClient.shared.productsByCategory(categoryId)
        JsonCache.writeProducts(categoryId: categoryId, products: data)
        return data
    }

    /// One cursor page of a category's products. Pages are not cached individually;
    /// only the first page is written to the cache so a cold start still has content.
    func getProductsPage(categoryId: Int, beforeId: Int? = nil,
                         limit: Int = 50) async throws -> ProductPageResponse {
        let page = try await APIClient.shared.productsByCategoryPage(categoryId,
                                                                     limit: limit,
                                                                     beforeId: beforeId)
        if beforeId == nil {
            JsonCache.writeProducts(categoryId: categoryId, products: page.products)
        }
        return page
    }

    func clearCache() {
        JsonCache.clear()
    }
}
