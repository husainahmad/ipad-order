import Foundation

struct AuthResponse: Codable {
    let accessToken: String?
    let refreshToken: String?

    var accessTokenValue: String { accessToken ?? "" }
    var refreshTokenValue: String { refreshToken ?? "" }
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}
