import Foundation
import Combine

final class AppSession: ObservableObject {
    @Published var isLoggedIn = TokenManager.isLoggedIn

    func logIn() {
        isLoggedIn = true
    }

    func logOut() {
        TokenManager.clearTokens()
        isLoggedIn = false
    }
}
