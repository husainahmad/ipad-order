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
    let imageBlob: String?
    let mimeType: String?

    var imageBlobValue: String { imageBlob ?? "" }
}

struct Product: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let categoryId: Int?
    let skus: [Sku]?
    let productImage: ProductImage?

    var nameValue: String { name ?? "" }
}
