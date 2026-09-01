import Foundation
import Combine

final class AppSession: ObservableObject {
    @Published var isLoggedIn = TokenManager.isLoggedIn

    init() {
        FontLoader.registerFonts()
        NotificationCenter.default.addObserver(forName: .didReceiveNotAuthenticated, object: nil, queue: .main) { [weak self] _ in
            self?.isLoggedIn = false
        }
    }

    func logIn() {
        isLoggedIn = true
    }

    func logOut() {
        TokenManager.clearTokens()
        isLoggedIn = false
    }
}

extension Notification.Name {
    static let didReceiveNotAuthenticated = Notification.Name("didReceiveNotAuthenticated")
}
