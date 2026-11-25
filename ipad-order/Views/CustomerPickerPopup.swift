import SwiftUI
import UIKit

// MARK: - CustomerPickerPopup
//
// The till's customer step: search a registered customer by phone and bind them to
// the order, or register a new one on the spot. Picking a customer is what makes an
// order travel with a real `customerId`; closing without picking leaves it a walk-in.
//
// Two modes in one dialog, because they are the same moment in the flow: the search
// says "nobody has this number", and the register form is the answer to that.

struct CustomerPickerPopup: View {
    @ObservedObject var tab: OrderTab
    /// Binding the customer to the order goes through the form view model, which
    /// owns the idempotency key: a customer change on an already-confirmed order must
    /// rotate it, or the next confirm would silently reuse the old order.
    var onSelect: (Customer) -> Void
    var onClear: () -> Void
    var onClose: () -> Void

    @StateObject private var picker = CustomerPickerViewModel()
    @State private var mode: Mode = .search
    @FocusState private var phoneFocused: Bool

    private enum Mode { case search, register }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    if let linked = tab.customerRecord {
                        linkedBanner(linked)
                    }
                    switch mode {
                    case .search:
                        searchBox
                        searchResults
                    case .register:
                        registerForm
                    }
                }
                .padding(14)
            }
            .background(Color.posSurface)

            footer
        }
        .frame(width: min(560, UIScreen.main.bounds.width - 32))
        .frame(maxHeight: min(660, UIScreen.main.bounds.height * 0.86))
        .background(Color.posSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
        .onAppear {
            picker.query = tab.customerRecord?.phoneValue ?? ""
            phoneFocused = true
        }
        .dismissKeyboardOnTap()
        .animation(.easeInOut(duration: 0.18), value: mode)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(mode == .search ? "Find Customer" : "New Customer"))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)
                Text(LocalizedStringKey(mode == .search ? "Search by mobile phone" : "Register before taking the order"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(LocalizedStringKey("Close")))
        }
        .padding(14)
        .background(Color.posPrimaryGradient)
    }

    // MARK: - Linked customer

    private func linkedBanner(_ customer: Customer) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.posAccentSoft).frame(width: 38, height: 38)
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 15))
                    .foregroundColor(.posAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                    .lineLimit(1)
                Text(LocalizedStringKey(customer.phoneValue.isEmpty ? "No phone on file" : customer.phoneValue))
                    .font(.system(size: 12))
                    .foregroundColor(.posTextSecondary)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onClear()
            } label: {
                Text("Remove")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.posStatusVoid)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.posStatusVoid.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.posRowEven)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posAccent.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Search

    private var searchBox: some View {
        HStack(spacing: 8) {
            Image(systemName: "phone.fill")
                .font(.system(size: 13))
                .foregroundColor(.posTextSecondary)
            TextField("Mobile phone e.g. 0812 3456 7890", text: $picker.query)
                .font(.system(size: 14))
                .foregroundColor(.posTextPrimary)
                .tint(.posAccent)
                .keyboardType(.phonePad)
                .focused($phoneFocused)
                .submitLabel(.search)
            if picker.searching {
                ProgressView().scaleEffect(0.7)
            } else if !picker.query.isEmpty {
                Button {
                    picker.query = ""
                    picker.clearResults()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.posTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(LocalizedStringKey("Clear search")))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(Color.posRowEven)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var searchResults: some View {
        if let error = picker.searchError {
            messageCard(icon: "wifi.exclamationmark",
                        title: "Search failed",
                        detail: error,
                        color: .posStatusVoid,
                        actionTitle: "Retry") { picker.retrySearch() }
        } else if picker.searching {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("Searching customers...")
                    .font(.system(size: 13))
                    .foregroundColor(.posTextSecondary)
                Spacer()
            }
            .padding(12)
        } else if !picker.results.isEmpty {
            VStack(spacing: 0) {
                ForEach(picker.results) { customer in
                    resultRow(customer)
                    if customer.id != picker.results.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
            .background(Color.posRowEven)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if picker.hasSearched {
            messageCard(icon: "person.fill.questionmark",
                        title: "No customer found",
                        detail: L10n.t("No one matches %@.", picker.searchedPhone.isEmpty ? L10n.t("that number") : picker.searchedPhone),
                        color: .posBlueAction,
                        actionTitle: "Register new customer") { startRegistration() }
        } else {
            messageCard(icon: "magnifyingglass",
                        title: "Search by phone",
                        detail: L10n.t("Type a mobile number to find an existing customer, or register a new one."),
                        color: .posTextSecondary,
                        actionTitle: "Register new customer") { startRegistration() }
        }
    }

    private func resultRow(_ customer: Customer) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            select(customer)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.posAccentSoft).frame(width: 36, height: 36)
                    Text(initials(customer.displayName))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.posAccent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(customer.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.posTextPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !customer.phoneValue.isEmpty {
                            Text(customer.phoneValue)
                                .font(.system(size: 12))
                                .foregroundColor(.posTextSecondary)
                        }
                        if !customer.emailValue.isEmpty {
                            Text("•").font(.system(size: 10)).foregroundColor(.posTextSecondary)
                            Text(customer.emailValue)
                                .font(.system(size: 12))
                                .foregroundColor(.posTextSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.posTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(customer.displayName), \(customer.phoneValue)")
    }

    private func messageCard(icon: String, title: String, detail: String,
                             color: Color, actionTitle: String,
                             action: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(color)
            Text(LocalizedStringKey(title))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.posTextPrimary)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.posTextSecondary)
                .multilineTextAlignment(.center)
            Button(LocalizedStringKey(actionTitle), action: action)
                .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posAccent))
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.posBgLight)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Register

    private var registerForm: some View {
        VStack(spacing: 10) {
            field(icon: "person.fill", title: "Name",
                  placeholder: "Customer name", text: $picker.newName)
            field(icon: "phone.fill", title: "Mobile phone",
                  placeholder: "0812 3456 7890", text: $picker.newPhone,
                  keyboard: .phonePad)
            field(icon: "envelope.fill", title: "Email (optional)",
                  placeholder: "name@example.com", text: $picker.newEmail,
                  keyboard: .emailAddress)

            if let error = picker.registerError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.posStatusVoid)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.posStatusVoid)
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.posBgLight)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func field(icon: String, title: String, placeholder: String,
                       text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.posTextSecondary)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.posTextSecondary)
                TextField(LocalizedStringKey(placeholder), text: text)
                    .font(.system(size: 14))
                    .foregroundColor(.posTextPrimary)
                    .tint(.posAccent)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                    .autocorrectionDisabled(keyboard == .emailAddress)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.posRowEven)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            switch mode {
            case .search:
                Button("Register") { startRegistration() }
                    .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posAccent))
                Spacer()
                Button("Done") { onClose() }
                    .buttonStyle(PosButtonStyle(filled: true))
            case .register:
                Button("Back to search") { backToSearch() }
                    .buttonStyle(PosButtonStyle(filled: false))
                Spacer()
                Button(LocalizedStringKey(picker.registering ? "Saving..." : "Save & Select")) {
                    saveAndSelect()
                }
                .buttonStyle(PosButtonStyle(filled: true))
                .disabled(!picker.canRegister)
                .opacity(picker.canRegister ? 1 : 0.45)
            }
        }
        .padding(12)
        .background(Color.posSurface)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
    }

    // MARK: - Actions

    private func select(_ customer: Customer) {
        onSelect(customer)
        onClose()
    }

    private func startRegistration() {
        picker.prepareRegistration()
        withAnimation(.easeInOut(duration: 0.18)) { mode = .register }
    }

    private func backToSearch() {
        picker.resetRegisterForm()
        withAnimation(.easeInOut(duration: 0.18)) { mode = .search }
    }

    private func saveAndSelect() {
        Task {
            guard let customer = await picker.register() else { return }
            select(customer)
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.45).ignoresSafeArea()
        CustomerPickerPopup(tab: OrderTab(id: 1, label: "#001"),
                            onSelect: { _ in },
                            onClear: {},
                            onClose: {})
    }
}
