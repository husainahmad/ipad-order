import SwiftUI

struct ContentView: View {
    @StateObject private var session = AppSession()
    @StateObject private var orderFormVM = OrderFormViewModel()
    @StateObject private var ordersVM = OrdersViewModel()

    var body: some View {
        Group {
            if session.isLoggedIn {
                OrderPagerView()
                    .environmentObject(orderFormVM)
                    .environmentObject(ordersVM)
                    .environmentObject(session)
            } else {
                LoginView()
                    .environmentObject(session)
            }
        }
        .preferredColorScheme(.light)
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
