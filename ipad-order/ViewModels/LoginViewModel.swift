import Foundation
import Combine

final class LoginViewModel: ObservableObject {

    @Published var loading = false
    @Published var error: String?

    @MainActor
    func login(username: String, password: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !password.isEmpty else {
            error = "Please enter username and password"
            return false
        }
        error = nil
        loading = true
        defer { loading = false }

        do {
            let auth = try await APIClient.shared.login(username: trimmed, password: password)
            guard !auth.accessTokenValue.isEmpty else {
                error = "Login failed"
                return false
            }
            TokenManager.setTokens(access: auth.accessTokenValue, refresh: auth.refreshTokenValue)
            let user = try await APIClient.shared.getUser(username: trimmed)
            TokenManager.saveUser(user)
            JsonCache.clear()
            return true
        } catch let apiError as ApiError {
            if case .http(let code) = apiError {
                error = "Login failed: HTTP \(code)"
            } else {
                error = apiError.localizedDescription
            }
            return false
        } catch {
            self.error = "Network error: \(error.localizedDescription)"
            return false
        }
    }
}
