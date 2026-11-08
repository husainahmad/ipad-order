import Foundation

enum ApiError: LocalizedError {
    case invalidResponse
    case http(Int)
    /// A rejection that came with a human-readable explanation, e.g. the customer
    /// service's `DUPLICATE_CUSTOMER`. Prefer this over `http` whenever the body
    /// carries a message, so the teller sees "Phone already registered" rather
    /// than "HTTP 409".
    case server(code: String?, message: String)
    case network(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .http(let code): return "HTTP \(code)"
        case .server(_, let message): return message
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

    /// One cursor page of a category's products with the operator's tier pricing.
    ///
    /// `beforeId` is the cursor the previous page returned. Paging on an id rather than
    /// an offset means a product inserted between two requests cannot make the next page
    /// repeat a row the cashier has already seen.
    func productsByCategoryPage(_ categoryId: Int, limit: Int = 50,
                                beforeId: Int? = nil) async throws -> ProductPageResponse {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let beforeId {
            query.append(URLQueryItem(name: "beforeId", value: String(beforeId)))
        }
        let response: ApiResponse<ProductPageResponse> = try await send(
            method: "GET", base: ConfigManager.baseMenu,
            path: "api/v1/product/category/\(categoryId)/price/page", query: query)
        guard let page = response.data else { throw ApiError.invalidResponse }
        return page
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

    func productCustomizations(_ productId: Int) async throws -> [ProductCustomization] {
        let response: ApiResponse<[ProductCustomization]> = try await send(
            method: "GET", base: ConfigManager.baseMenu,
            path: "api/v1/product/\(productId)/customization")
        return response.data ?? []
    }

    // MARK: - Customers

    /// Searches customers by free text. The service matches name, phone and email, so
    /// a phone number typed at the till finds the customer without a dedicated
    /// phone-only endpoint.
    func searchCustomers(_ search: String, page: Int = 0, size: Int = 20) async throws -> CustomerPage {
        let query = [
            URLQueryItem(name: "search", value: search),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        return try await send(method: "GET", base: ConfigManager.baseCustomer,
                              path: "api/v1/customers", query: query)
    }

    func createCustomer(_ request: CreateCustomerRequest) async throws -> Customer {
        let body = try JSONEncoder().encode(request)
        return try await send(method: "POST", base: ConfigManager.baseCustomer,
                              path: "api/v1/customers", body: body)
    }

    // MARK: - Orders

    func dailyOrders() async throws -> [Order] {
        let response: ApiResponse<[Order]> = try await send(
            method: "GET", base: ConfigManager.baseOrder, path: "api/v1/order")
        return response.data ?? []
    }

    /// One page of today's orders, newest first.
    ///
    /// `beforeId` is the cursor the previous page returned. Paging on an id rather than an
    /// offset means a sale confirmed between two requests cannot make the next page repeat
    /// a row the cashier has already seen.
    func dailyOrdersPage(limit: Int = 50, beforeId: Int? = nil) async throws -> OrderPageResponse {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let beforeId {
            query.append(URLQueryItem(name: "beforeId", value: String(beforeId)))
        }
        let response: ApiResponse<OrderPageResponse> = try await send(
            method: "GET", base: ConfigManager.baseOrder,
            path: "api/v1/order/page", query: query)
        guard let page = response.data else { throw ApiError.invalidResponse }
        return page
    }

    func confirmOrder(_ request: OrderRequest, idempotencyKey: String? = nil) async throws -> Order {
        let body = try JSONEncoder().encode(request)
        let headers = idempotencyKey.map { ["Idempotency-Key": $0] }
        let response: ApiResponse<Order> = try await send(
            method: "POST", base: ConfigManager.baseOrder, path: "api/v1/order",
            body: body, headers: headers)
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
                                    headers: [String: String]? = nil,
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
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
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
                                      body: body, query: query, headers: headers,
                                      authenticated: authenticated)
            }
            TokenManager.clearTokens()
            NotificationCenter.default.post(name: .didReceiveNotAuthenticated, object: nil)
            throw ApiError.notAuthenticated
        }

        guard (200..<300).contains(http.statusCode) else {
            // The services answer failures with a stable error envelope. Surfacing
            // its message is the difference between "Phone already registered" and
            // an opaque status code at the counter.
            if let body = try? JSONDecoder().decode(ServerErrorBody.self, from: data),
               let message = body.message, !message.isEmpty {
                throw ApiError.server(code: body.code, message: message)
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

/// The error envelope every Harmoni service answers with. Only the fields the app
/// actually shows are decoded; `fieldErrors` is not needed for a counter message.
struct ServerErrorBody: Decodable {
    let code: String?
    let message: String?
}

