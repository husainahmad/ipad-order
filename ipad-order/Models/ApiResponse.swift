import Foundation

struct ApiResponse<T: Decodable>: Decodable {
    let data: T?
    let message: String?
    let code: Int?

    var messageValue: String { message ?? "" }
}
