import Foundation

struct Category: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
}

struct TierPrice: Codable, Hashable {
    let price: Double?
}

struct Sku: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let tierPrice: TierPrice?

    var price: Double { tierPrice?.price ?? 0 }
}

struct ProductImage: Codable, Hashable {
    let id: Int?
    let fileName: String?
    let url: String?
    let mimeType: String?

    /// The hosted image location. The menu service uploads to ImgBB and stores the
    /// returned link, so the app never receives image bytes — only this URL.
    var urlValue: String { url ?? "" }
}

struct Product: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let categoryId: Int?
    let skus: [Sku]?
    let productImage: ProductImage?

    var nameValue: String { name ?? "" }
}
