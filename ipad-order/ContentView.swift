import SwiftUI

struct ContentView: View {
    @StateObject private var session = AppSession()
    @StateObject private var orderFormVM = OrderFormViewModel()
    @StateObject private var ordersVM = OrdersViewModel()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var toastManager = ToastManager()
    @AppStorage("app_language") private var appLanguage = AppLanguage.system

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
        .environment(\.locale, contentLocale)
        .id(contentLocale.identifier)
        .environmentObject(themeManager)
        .environmentObject(toastManager)
        .onAppear {
            // Already signed in at launch: bring back the open orders left on disk.
            if session.isLoggedIn { orderFormVM.restoreDrafts() }
        }
        .onChange(of: session.isLoggedIn) { loggedIn in
            if loggedIn {
                // Restore any open orders saved before the last sign-out.
                orderFormVM.restoreDrafts()
            } else {
                // Keep the drafts on disk; only the in-memory cart is cleared so a
                // stale cart is not shown while logged out.
                orderFormVM.reset()
            }
        }
    }

    private var contentLocale: Locale {
        if appLanguage == AppLanguage.system { return AppLanguage.locale }
        return Locale(identifier: appLanguage)
    }
}

#Preview {
    ContentView()
}
