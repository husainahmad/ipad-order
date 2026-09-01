import Foundation

enum ApiError: LocalizedError {
    case invalidResponse
    case http(Int)
    case network(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .http(let code): return "HTTP \(code)"
        case .network(let message): return "Network error: \(message)"
        case .notAuthenticated: return "Not authenticated"
        }
    }
}

final class APIClient {

    static let shared = APIClient()

    private let session: URLSession
    private let refreshGate = RefreshGate()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(LoginRequest(username: username, password: password))
        return try await send(method: "POST",
                              base: ConfigManager.baseAuth,
                              path: "api/v1/auth/login",
                              body: body,
                              authenticated: false)
    }

    // MARK: - Menu

    func categories() async throws -> [Category] {
        let response: ApiResponse<[Category]> = try await send(
            method: "GET", base: ConfigManager.baseMenu, path: "api/v1/category/tier")
        return response.data ?? []
    }

    func productsByCategory(_ categoryId: Int) async throws -> [Product] {
        let response: ApiResponse<[Product]> = try await send(
            method: "GET", base: ConfigManager.baseMenu,
            path: "api/v1/product/category/\(categoryId)/price")
        return response.data ?? []
    }

    func getUser(username: String) async throws -> User {
        let response: ApiResponse<User> = try await send(
            method: "GET", base: ConfigManager.baseMenu,
            path: "api/v1/user/\(username)")
        guard let user = response.data else {
            throw ApiError.invalidResponse
        }
        return user
    }

    // MARK: - Orders

    func dailyOrders() async throws -> [Order] {
        let response: ApiResponse<[Order]> = try await send(
            method: "GET", base: ConfigManager.baseOrder, path: "api/v1/order")
        return response.data ?? []
    }

    func confirmOrder(_ request: OrderRequest) async throws -> Order {
        let body = try JSONEncoder().encode(request)
        let response: ApiResponse<Order> = try await send(
            method: "POST", base: ConfigManager.baseOrder, path: "api/v1/order", body: body)
        guard let order = response.data else {
            throw ApiError.invalidResponse
        }
        return order
    }

    func payOrder(_ request: PaymentRequest) async throws -> Order {
        let body = try JSONEncoder().encode(request)
        let response: ApiResponse<Order> = try await send(
            method: "PUT", base: ConfigManager.baseOrder, path: "api/v1/order", body: body)
        guard let order = response.data else {
            throw ApiError.invalidResponse
        }
        return order
    }

    func voidOrder(_ orderId: Int) async throws {
        let _: ApiResponse<EmptyData> = try await send(
            method: "PUT", base: ConfigManager.baseOrder, path: "api/v1/order/\(orderId)/void")
    }

    // MARK: - Reports

    func settlement(start: String, end: String) async throws -> Settlement {
        let query = [URLQueryItem(name: "start", value: start), URLQueryItem(name: "end", value: end)]
        let response: ApiResponse<Settlement> = try await send(
            method: "GET", base: ConfigManager.baseOrder,
            path: "api/v1/reports/settlement", query: query)
        guard let data = response.data else {
            throw ApiError.invalidResponse
        }
        return data
    }

    func salesReport(start: String, end: String) async throws -> [SalesReportRow] {
        let query = [URLQueryItem(name: "start", value: start), URLQueryItem(name: "end", value: end)]
        let response: ApiResponse<[SalesReportRow]> = try await send(
            method: "GET", base: ConfigManager.baseOrder,
            path: "api/v1/reports/sales", query: query)
        return response.data ?? []
    }

    func dailyReport(start: String, end: String) async throws -> [DailyReportRow] {
        let query = [URLQueryItem(name: "start", value: start), URLQueryItem(name: "end", value: end)]
        let response: ApiResponse<[DailyReportRow]> = try await send(
            method: "GET", base: ConfigManager.baseOrder,
            path: "api/v1/reports/daily", query: query)
        return response.data ?? []
    }

    func orderVolume(start: String, end: String) async throws -> OrderVolume {
        let query = [URLQueryItem(name: "start", value: start), URLQueryItem(name: "end", value: end)]
        let response: ApiResponse<OrderVolume> = try await send(
            method: "GET", base: ConfigManager.baseOrder,
            path: "api/v1/reports/order-volume", query: query)
        guard let data = response.data else {
            throw ApiError.invalidResponse
        }
        return data
    }

    // MARK: - Core request

    func reset() {}

    private func send<T: Decodable>(method: String,
                                    base: String,
                                    path: String,
                                    body: Data? = nil,
                                    query: [URLQueryItem]? = nil,
                                    authenticated: Bool = true) async throws -> T {
        var components = URLComponents(string: base + path)
        if let query = query {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw ApiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated, !TokenManager.accessToken.isEmpty {
            request.setValue("Bearer \(TokenManager.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ApiError.invalidResponse
        }

        if (http.statusCode == 401 || http.statusCode == 403), authenticated {
            let refreshed = await refreshGate.perform { await self.refreshAccessToken() }
            if refreshed {
                return try await send(method: method, base: base, path: path,
                                      body: body, query: query, authenticated: authenticated)
            }
            TokenManager.clearTokens()
            NotificationCenter.default.post(name: .didReceiveNotAuthenticated, object: nil)
            throw ApiError.notAuthenticated
        }

        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 403 {
                // No retry for permission-denied without auth context
                throw ApiError.http(http.statusCode)
            }
            throw ApiError.http(http.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func refreshAccessToken() async -> Bool {
        let refresh = TokenManager.refreshToken
        guard !refresh.isEmpty else {
            TokenManager.clearTokens()
            return false
        }
        let url = URL(string: ConfigManager.baseAuth + "api/v1/auth/refresh-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(refresh.utf8)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                TokenManager.clearTokens()
                return false
            }
            let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard !auth.accessTokenValue.isEmpty else {
                TokenManager.clearTokens()
                return false
            }
            TokenManager.setTokens(access: auth.accessTokenValue,
                                   refresh: auth.refreshTokenValue.isEmpty ? refresh : auth.refreshTokenValue)
            return true
        } catch {
            TokenManager.clearTokens()
            return false
        }
    }
}

private actor RefreshGate {
    private var isRefreshing = false

    func perform(_ op: () async -> Bool) async -> Bool {
        if isRefreshing {
            try? await Task.sleep(nanoseconds: 200_000_000)
            return true
        }
        isRefreshing = true
        defer { isRefreshing = false }
        return await op()
    }
}

struct EmptyData: Decodable {}
