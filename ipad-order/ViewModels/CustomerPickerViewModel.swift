import Foundation
import Combine

/// Drives the customer picker: a phone search, the results it finds, and the
/// register-new-customer form. Search and registration both end in the same place —
/// a `Customer` handed back to the caller to bind to the order.
///
/// Search is debounced because it fires on every keystroke of a phone number, and a
/// POS till is usually on a shared shop network. A query shorter than a few digits
/// matches too broadly to be useful, so it is skipped rather than sent.
@MainActor
final class CustomerPickerViewModel: ObservableObject {

    /// What the cashier is typing into the phone box. Changes schedule a search.
    @Published var query = "" {
        didSet { scheduleSearch() }
    }

    @Published private(set) var results: [Customer] = []
    @Published private(set) var searching = false
    @Published private(set) var registering = false
    @Published private(set) var hasSearched = false

    /// A failure the picker itself should show. The register form has its own error
    /// channel so a rejected phone number never replaces the result list.
    @Published var searchError: String?
    @Published var registerError: String?

    // Register form fields.
    @Published var newName = ""
    @Published var newPhone = ""
    @Published var newEmail = ""

    /// Set when the search found nothing for a phone that is otherwise valid, which
    /// is the moment registering is obviously the next step.
    @Published private(set) var searchedPhone = ""

    private var searchTask: Task<Void, Never>?
    private let debounceNanos: UInt64 = 300_000_000

    var canRegister: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && PhoneFormatter.isValid(newPhone)
            && !registering
    }

    /// Fills the register form from the failed search so the teller does not retype
    /// a number that is already on screen.
    func prepareRegistration() {
        newPhone = searchedPhone.isEmpty ? query.trimmingCharacters(in: .whitespacesAndNewlines) : searchedPhone
        if newName.isEmpty { newName = "" }
        registerError = nil
    }

    func resetRegisterForm() {
        newName = ""
        newPhone = ""
        newEmail = ""
        registerError = nil
    }

    func clearResults() {
        results = []
        hasSearched = false
        searchedPhone = ""
        searchError = nil
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PhoneFormatter.isSearchable(trimmed) else {
            results = []
            hasSearched = false
            searchedPhone = ""
            searching = false
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceNanos ?? 0)
            guard !Task.isCancelled else { return }
            await self?.runSearch(trimmed)
        }
    }

    private func runSearch(_ term: String) async {
        searching = true
        searchError = nil
        defer { searching = false }
        do {
            let page = try await APIClient.shared.searchCustomers(term)
            guard !Task.isCancelled else { return }
            // The service matches name/phone/email with LIKE, so a short number can
            // drag in unrelated people. Keep only rows whose phone contains the
            // digits typed, which is what the cashier is searching by here.
            let digits = PhoneFormatter.digits(term)
            let matches = page.content.filter { customer in
                let stored = PhoneFormatter.digits(customer.phoneValue)
                return digits.isEmpty || stored.contains(digits)
            }
            results = matches
            searchedPhone = term
            hasSearched = true
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            hasSearched = true
            searchError = message(for: error)
        }
    }

    /// Re-runs the current query, for the retry button after a network failure.
    func retrySearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PhoneFormatter.isSearchable(trimmed) else { return }
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.runSearch(trimmed)
        }
    }

    // MARK: - Register

    /// Creates the customer and returns it so the caller can select it straight away.
    /// Returns `nil` when validation or the service rejects the input; the reason is
    /// left on `registerError`.
    func register() async -> Customer? {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = newPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            registerError = L10n.t("Name is required")
            return nil
        }
        guard PhoneFormatter.isValid(phone) else {
            registerError = L10n.t("Enter a valid phone number (5–30 digits)")
            return nil
        }

        registering = true
        registerError = nil
        defer { registering = false }
        do {
            let request = CreateCustomerRequest(name: name,
                                               phone: phone,
                                               email: email.isEmpty ? nil : email)
            let customer = try await APIClient.shared.createCustomer(request)
            // The new customer is the search result now, so the list stays truthful
            // if the teller backs out of the form and looks again.
            results = [customer]
            hasSearched = true
            searchedPhone = phone
            return customer
        } catch {
            registerError = message(for: error)
            return nil
        }
    }

    private func message(for error: Error) -> String {
        if let apiError = error as? ApiError {
            if case .server(_, let message) = apiError { return message }
            if case .http(let code) = apiError { return L10n.t("Request failed: HTTP %d", code) }
            return apiError.localizedDescription
        }
        return error.localizedDescription
    }
}
