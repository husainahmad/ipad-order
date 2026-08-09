import Foundation

enum JsonCache {

    private static let categoryFileName = "category_cache.json"
    private static func productFileName(_ categoryId: Int) -> String {
        "product_cache_\(categoryId).json"
    }

    private static var cacheDirectory: URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir
    }

    static func readCategories() -> [Category]? {
        read(categoryFileName, as: [Category].self)
    }

    static func writeCategories(_ categories: [Category]) {
        write(categoryFileName, data: categories)
    }

    static func readProducts(categoryId: Int) -> [Product]? {
        read(productFileName(categoryId), as: [Product].self)
    }

    static func writeProducts(categoryId: Int, products: [Product]) {
        write(productFileName(categoryId), data: products)
    }

    static func clear() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: cacheDirectory,
                                                      includingPropertiesForKeys: nil) else { return }
        for file in files where file.pathExtension == "json" {
            try? fm.removeItem(at: file)
        }
    }

    private static func read<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        let url = cacheDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ name: String, data: T) {
        let url = cacheDirectory.appendingPathComponent(name)
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: url)
    }
}
