import Foundation

struct Brand: Codable {
    let id: Int?
    let name: String?
}

struct Chain: Codable {
    let id: Int?
    let name: String?
    let brand: Brand?
}

struct Store: Codable {
    let id: Int?
    let name: String?
    let chain: Chain?
}

struct User: Codable {
    let id: Int?
    let username: String?
    let store: Store?

    var usernameValue: String { username ?? "" }
    var storeName: String { store?.name ?? "" }
    var chainName: String { store?.chain?.name ?? "" }
    var brandName: String { store?.chain?.brand?.name ?? "" }
}
