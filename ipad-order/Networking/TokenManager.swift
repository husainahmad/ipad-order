import Foundation

enum TokenManager {

    private static let defaults = UserDefaults.standard

    private static let keyAccess = "pos_access_token"
    private static let keyRefresh = "pos_refresh_token"
    private static let keyUsername = "pos_username"
    private static let keyStoreId = "pos_store_id"
    private static let keyStoreName = "pos_store_name"
    private static let keyChainId = "pos_chain_id"
    private static let keyChainName = "pos_chain_name"
    private static let keyBrandId = "pos_brand_id"
    private static let keyBrandName = "pos_brand_name"

    private static let refreshBufferSeconds: Int64 = 30

    static var accessToken: String { defaults.string(forKey: keyAccess) ?? "" }
    static var refreshToken: String { defaults.string(forKey: keyRefresh) ?? "" }

    static func setTokens(access: String, refresh: String) {
        defaults.set(access, forKey: keyAccess)
        defaults.set(refresh, forKey: keyRefresh)
    }

    static var username: String { defaults.string(forKey: keyUsername) ?? "" }
    static var storeName: String { defaults.string(forKey: keyStoreName) ?? "" }
    static var chainName: String { defaults.string(forKey: keyChainName) ?? "" }
    static var brandName: String { defaults.string(forKey: keyBrandName) ?? "" }

    static var isAccessTokenExpired: Bool {
        let exp = JwtUtils.exp(accessToken)
        guard exp > 0 else { return false }
        let now = Int64(Date().timeIntervalSince1970)
        return now >= exp - refreshBufferSeconds
    }

    static func saveUser(_ user: User) {
        defaults.set(user.usernameValue, forKey: keyUsername)
        defaults.set(user.store?.id ?? 0, forKey: keyStoreId)
        defaults.set(user.storeName, forKey: keyStoreName)
        defaults.set(user.store?.chain?.id ?? 0, forKey: keyChainId)
        defaults.set(user.chainName, forKey: keyChainName)
        defaults.set(user.store?.chain?.brand?.id ?? 0, forKey: keyBrandId)
        defaults.set(user.brandName, forKey: keyBrandName)
    }

    static var isLoggedIn: Bool {
        !accessToken.isEmpty && !username.isEmpty
    }

    static func clearTokens() {
        defaults.set("", forKey: keyAccess)
        defaults.set("", forKey: keyRefresh)
        defaults.set("", forKey: keyUsername)
        defaults.set("", forKey: keyStoreName)
        defaults.set("", forKey: keyChainName)
        defaults.set("", forKey: keyBrandName)
    }
}
