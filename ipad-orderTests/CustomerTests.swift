import Foundation
import Testing
@testable import ipad_order

// MARK: - Phone formatting

struct PhoneFormatterTests {

    @Test func digitsStripsFormatting() {
        #expect(PhoneFormatter.digits("0812-3456 (7890)") == "081234567890")
        #expect(PhoneFormatter.digits("+62 812 3456 7890") == "6281234567890")
    }

    @Test func shortInputIsNotWorthSearching() {
        #expect(PhoneFormatter.isSearchable("08") == false)
        #expect(PhoneFormatter.isSearchable("081") == true)
        // Digits only are counted, so a country prefix alone is still too short.
        #expect(PhoneFormatter.isSearchable("+62 8") == true)
        #expect(PhoneFormatter.isSearchable("+62") == false)
    }

    @Test func validPhoneMirrorsTheServiceRule() {
        #expect(PhoneFormatter.isValid("0812 3456 7890") == true)
        #expect(PhoneFormatter.isValid("+62-812-3456-7890") == true)
        #expect(PhoneFormatter.isValid("123") == false)
        #expect(PhoneFormatter.isValid("abcde") == false)
        #expect(PhoneFormatter.isValid("") == false)
    }
}

// MARK: - Model decoding

struct CustomerDecodingTests {

    @Test func decodesTheServiceEnvelope() throws {
        let json = """
        {"content":[{"id":7,"name":"Ada","phone":"0812345678",\
        "email":"ada@example.com","createdAt":"2026-08-23T06:00:00Z",\
        "updatedAt":null}],"totalElements":1,"totalPages":1,"page":0,"size":20}
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(CustomerPage.self, from: json)
        #expect(page.content.count == 1)
        #expect(page.content.first?.id == 7)
        #expect(page.content.first?.displayName == "Ada")
        #expect(page.totalElements == 1)
    }

    @Test func displayNameFallsBackToPhoneThenId() {
        let byPhone = Customer(id: 3, name: "  ", phone: "08123", email: nil)
        #expect(byPhone.displayName == "08123")
        let blank = Customer(id: 3, name: nil, phone: nil, email: nil)
        #expect(blank.displayName == "Customer #3")
    }
}

// MARK: - Order request carries the customer

struct OrderRequestCustomerTests {

    @Test func walkInSendsMinusOneAndNoPhone() {
        let request = OrderRequest(customerName: "Budi", remark: "",
                                   orderDetails: [], discount: "0")
        #expect(request.customerId == -1)
        #expect(request.customerPhone.isEmpty)
    }

    @Test func selectedCustomerIsEncoded() throws {
        let customer = Customer(id: 42, name: "Ada", phone: "0812345678", email: nil)
        let request = OrderRequest(customerName: "Ada", customerId: customer.id,
                                   customerPhone: customer.phoneValue, remark: "",
                                   orderDetails: [], discount: "0")
        let data = try JSONEncoder().encode(request)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["customerId"] as? Int == 42)
        #expect(object["customerPhone"] as? String == "0812345678")
        #expect(object["customerName"] as? String == "Ada")
    }
}

// MARK: - Linking a customer to a tab

struct OrderTabCustomerLinkTests {

    @Test func selectedCustomerRemainsLinkedWhileNameMatches() {
        let tab = OrderTab(id: 1, label: "#001")
        tab.customerRecord = Customer(id: 42, name: "Ada", phone: "0812345678", email: nil)
        tab.customer = "Ada"
        #expect(tab.linkedCustomer(typedName: "Ada")?.id == 42)
    }

    @Test func renamingAfterSelectionDetachesTheCustomer() {
        let tab = OrderTab(id: 1, label: "#001")
        tab.customerRecord = Customer(id: 42, name: "Ada", phone: "0812345678", email: nil)
        // The cashier edited the name by hand: the id would now point at someone else.
        #expect(tab.linkedCustomer(typedName: "Budi") == nil)
    }

    @Test func namelessCustomerIsLinkedByPhone() {
        let tab = OrderTab(id: 1, label: "#001")
        tab.customerRecord = Customer(id: 7, name: nil, phone: "0812345678", email: nil)
        // The cart shows the phone when no name was captured.
        #expect(tab.linkedCustomer(typedName: "0812345678")?.id == 7)
    }

    @Test func noCustomerMeansWalkIn() {
        let tab = OrderTab(id: 1, label: "#001")
        #expect(tab.linkedCustomer(typedName: "") == nil)
        #expect(tab.linkedCustomer(typedName: "Walk-in") == nil)
    }
}

// MARK: - Search filtering

struct CustomerSearchFilterTests {

    @Test func searchKeepsOnlyCustomersMatchingTheTypedDigits() {
        let customers = [
            Customer(id: 1, name: "Ada", phone: "0812-3456", email: nil),
            Customer(id: 2, name: "Budi", phone: "0899-0000", email: nil),
            Customer(id: 3, name: "Citra", phone: nil, email: nil)
        ]
        let digits = PhoneFormatter.digits("0812")
        let matches = customers.filter { PhoneFormatter.digits($0.phoneValue).contains(digits) }
        #expect(matches.map(\.id) == [1])
    }
}

// MARK: - Edits invalidate the pending order

struct PendingOrderInvalidationTests {

    @Test func editingAfterConfirmDropsTheConfirmedOrder() {
        let vm = OrderFormViewModel()
        _ = vm.createNewTab()
        vm.confirmedOrder = Order(id: 9, orderNo: "A-1", customerName: "Ada",
                                  remark: nil, status: "CONFIRMED",
                                  storeServiceTypesId: 1, subTotal: 25_000,
                                  discountTotal: 0, grandTotal: 25_000,
                                  createdAt: nil, orderPayment: nil, orderDetails: [])
        // The payment dialog pays `confirmedOrder`; an edit must leave nothing to pay
        // so the footer re-confirms instead of paying the pre-edit order.
        vm.setDiscount("5000")
        #expect(vm.confirmedOrder == nil)
    }
}
