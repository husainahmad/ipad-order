import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: AppSession
    @StateObject private var viewModel = LoginViewModel()

    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case username, password }

    var body: some View {
        ZStack {
            Color.posLoginGradient.ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 480, height: 480)
                .offset(x: -360, y: -380)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 560, height: 560)
                .offset(x: 380, y: 420)

            VStack(spacing: 0) {
                brandMark

                VStack(spacing: 0) {
                    Text("Welcome Back")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.posTextPrimary)

                    Text("Sign in to start taking orders")
                        .font(.system(size: 14))
                        .foregroundColor(.posTextSecondary)
                        .padding(.top, 4)

                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.posPrimary)
                                .frame(width: 22)
                            TextField("Username", text: $username)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .focused($focusedField, equals: .username)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .password }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.posBgLight)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .username ? Color.posPrimary : Color.posDivider, lineWidth: 1.5)
                        )

                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.posPrimary)
                                .frame(width: 22)
                            SecureField("Password", text: $password)
                                .focused($focusedField, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { login() }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color.posBgLight)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == .password ? Color.posPrimary : Color.posDivider, lineWidth: 1.5)
                        )

                        if let error = viewModel.error, !error.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                Text(error)
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.posStatusVoid)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: login) {
                            ZStack {
                                if viewModel.loading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Login")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.posPrimaryGradient)
                            .cornerRadius(12)
                            .shadow(color: Color.posPrimary.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .disabled(viewModel.loading)
                        .opacity(viewModel.loading ? 0.7 : 1)
                    }
                    .padding(.top, 28)
                }
                .padding(32)
                .background(Color.posSurface)
                .cornerRadius(28)
                .shadow(color: Color.black.opacity(0.22), radius: 30, x: 0, y: 16)
                .frame(width: 440)
            }
            .dismissKeyboardOnTap()
        }
    }

    private var brandMark: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 108, height: 108)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 46))
                    .foregroundColor(.white)
            }

            VStack(spacing: 2) {
                Text("Kopi Harmoni")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                Text("Point of Sale · Tablet")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(.bottom, 36)
    }

    private func login() {
        Task {
            let success = await viewModel.login(username: username, password: password)
            if success {
                session.logIn()
            }
        }
    }
}

#Preview {
    LoginView().environmentObject(AppSession())
}
