import SwiftUI

struct ContentView: View {
    @StateObject private var session = AppSession()
    @StateObject private var orderFormVM = OrderFormViewModel()
    @StateObject private var ordersVM = OrdersViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var toastManager = ToastManager()

    var body: some View {
        Group {
            if session.isLoggedIn {
                OrderPagerView()
                    .environmentObject(orderFormVM)
                    .environmentObject(ordersVM)
                    .environmentObject(session)
                    .environmentObject(themeManager)
            } else {
                LoginView()
                    .environmentObject(session)
                    .environmentObject(themeManager)
            }
        }
        .toast(manager: toastManager)
        .dismissKeyboardOnTap()
        .preferredColorScheme(themeManager.colorScheme)
        .environmentObject(themeManager)
        .environmentObject(toastManager)
        .onChange(of: session.isLoggedIn) { loggedIn in
            if !loggedIn {
                orderFormVM.reset()
            }
        }
    }
}

#Preview {
    ContentView()
}
