import Foundation

/// A customer as the customer service returns it. `id` is what an order carries in
/// `customerId` so the sale can be traced back to a real person rather than a name
/// typed at the till.
struct Customer: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let phone: String?
    let email: String?
    let createdAt: String?
    let updatedAt: String?

    init(id: Int, name: String?, phone: String?, email: String?,
         createdAt: String? = nil, updatedAt: String? = nil) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var nameValue: String { (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var phoneValue: String { (phone ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var emailValue: String { (email ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    /// What a cashier recognises a customer by. Falls back to the phone when a name
    /// was never captured, and to the id only when the record is otherwise blank.
    var displayName: String {
        if !nameValue.isEmpty { return nameValue }
        if !phoneValue.isEmpty { return phoneValue }
        return "Customer #\(id)"
    }
}

/// The paged envelope `/api/v1/customers` answers with.
struct CustomerPage: Decodable {
    let content: [Customer]
    let totalElements: Int?
    let totalPages: Int?
    let page: Int?
    let size: Int?
}

struct CreateCustomerRequest: Codable {
    let name: String
    let phone: String
    let email: String?
}

/// Phone handling shared by the search box and the register form. The backend keys
/// customers on their exact phone string, so the same input is normalised in one
/// place rather than several.
enum PhoneFormatter {

    /// Digits only, which is the form the search retries with when a formatted
    /// number fails to match a number stored without separators.
    static func digits(_ value: String) -> String {
        value.filter { $0.isNumber }
    }

    /// Whether the input is long enough to be worth a round trip.
    static func isSearchable(_ value: String) -> Bool {
        digits(value).count >= 3
    }

    /// Mirrors the customer service's own rule: 5–30 characters from the phone
    /// alphabet. Validating here saves a pointless request and a 400 round trip.
    static func isValid(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (5...30).contains(trimmed.count) else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789+-() ")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
