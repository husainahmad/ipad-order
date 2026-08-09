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

    func clearCache() {
        JsonCache.clear()
    }
}
