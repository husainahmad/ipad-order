import SwiftUI
import UIKit

// MARK: - OrderConfirmPopup (compact iPad Landscape POS dialog)
// Centered dialog ~920pt wide, two columns, height = content.
// No .sheet, no GeometryReader width, single white surface (no outer cream nesting).

struct OrderConfirmPopup: View {
    @EnvironmentObject var formVM: OrderFormViewModel
    @EnvironmentObject var toastManager: ToastManager
    @ObservedObject var tab: OrderTab
    let existingOrder: Order?
    let onSuccess: (() -> Void)?
    var onClose: () -> Void

    @State private var selectedPayment = 1
    @State private var cashReceived = 0.0
    @State private var statusMessage: String?
    @State private var working = false

    /// Which order-detail field is open for editing, right here in the dialog. Editing
    /// used to close the dialog and send the cashier back to the cart, which threw away
    /// the payment method and the cash already entered.
    @State private var editingField: EditField?
    @State private var showCustomerPicker = false

    private enum EditField: Hashable { case service, customer, discount, note }

    private let denominations: [Double] = [1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000]

    private var isCartMode: Bool { existingOrder == nil }

    /// A cart-mode payment can only go ahead on an order that is currently confirmed.
    /// Any edit clears that order (see `invalidatePendingOrder`), so the footer has to
    /// confirm again before paying rather than paying the pre-edit version.
    private var needsReconfirm: Bool { isCartMode && formVM.confirmedOrder == nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 12) {
                                if isCartMode { inputsBox }
                                orderSummaryBox
                                totalsBox
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 12) {
                                paymentSection
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(12)
                    }
                    .background(Color.posSurface)
                    footer
                }
                .disabled(working)
                .opacity(working ? 0.45 : 1)
                .animation(.easeInOut(duration: 0.2), value: working)

                if working {
                    ZStack {
                        Color.posSurface.opacity(0.82)
                        VStack(spacing: 14) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .tint(.posAccent)
                            Text("Processing payment...")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.posTextPrimary)
                            Text("Please wait")
                                .font(.system(size: 13))
                                .foregroundColor(.posTextSecondary)
                        }
                        .padding(24)
                        .background(Color.posSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.posDivider, lineWidth: 1))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                // Customer is picked from the register, so its editor is the same
                // search dialog the cart uses, layered over this one.
                if showCustomerPicker {
                    Color.black.opacity(0.35).ignoresSafeArea()
                        .onTapGesture { showCustomerPicker = false }
                    CustomerPickerPopup(
                        tab: tab,
                        onSelect: { customer in
                            formVM.selectCustomer(customer)
                            editingField = nil
                        },
                        onClear: {
                            formVM.clearCustomer()
                            editingField = nil
                        },
                        onClose: { showCustomerPicker = false }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(10)
                }
            }
        }
        .frame(width: min(920, UIScreen.main.bounds.width - 32))
        .frame(height: min(680, UIScreen.main.bounds.height * 0.86))
        .background(Color.posSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
        .animation(.easeInOut(duration: 0.2), value: working)
        .animation(.easeInOut(duration: 0.16), value: editingField)
        .animation(.easeInOut(duration: 0.2), value: showCustomerPicker)
        .dismissKeyboardOnTap()
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(isCartMode ? "Confirm Order & Payment" : "Payment")).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Group {
                    if isCartMode {
                        Text("Review your order and choose a payment method")
                    } else {
                        Text("Order #\(existingOrder?.orderNoValue ?? "")")
                    }
                }
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
            }
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 36, height: 36).background(Color.white.opacity(0.15)).clipShape(Circle())
            }.buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.posPrimaryGradient)
    }

    private var orderSummaryBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Order Summary").font(.system(size: 18, weight: .bold)).foregroundColor(.posPrimary)
                Spacer()
                Text(L10n.t("%lld item(s)", totalItemCount)).font(.system(size: 14, weight: .bold)).foregroundColor(.posAccent)
            }
            VStack(spacing: 0) {
                ForEach(displayGroups) { group in
                    Text(group.productName).font(.system(size: 14, weight: .bold)).foregroundColor(.posPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 7).background(Color.posRowOdd)
                    ForEach(group.lines) { line in ConfirmLineRow(line: line) }
                }
            }
            .background(Color.posRowEven)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.posDivider, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12).background(Color.posBgLight).cornerRadius(8)
    }

    private var totalsBox: some View {
        VStack(spacing: 6) {
            HStack { Text("Sub Total").font(.system(size: 14)).foregroundColor(.posTextPrimary); Spacer()
                Text(CurrencyUtils.formatRp(subTotalValue)).font(.system(size: 14, weight: .bold)).foregroundColor(.posTextPrimary) }
            HStack { Text("Discount").font(.system(size: 14)).foregroundColor(.posTextPrimary); Spacer()
                Text(CurrencyUtils.formatRp2(discountValue)).font(.system(size: 14, weight: .bold)).foregroundColor(.posStatusVoid) }
            Divider()
            HStack { Text("Total").font(.system(size: 20, weight: .bold)).foregroundColor(.posPrimary); Spacer()
                Text(CurrencyUtils.formatRp(totalValue)).font(.system(size: 20, weight: .bold)).foregroundColor(.posPrimary) }
        }.padding(16).background(Color.posBgLight).cornerRadius(8)
    }

    private var inputsBox: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Order Details").font(.system(size: 16, weight: .bold)).foregroundColor(.posPrimary)
                Spacer()
                if needsReconfirm {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                        Text("Re-confirm to apply changes").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.posStatusConfirmed)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            serviceField
            customerField
            discountField
            noteField
        }.padding(16).background(Color.posBgLight).cornerRadius(8)
    }

    // MARK: - Editable order detail fields

    /// The pencil on a field opens its editor in place. The read-only value and the
    /// editor occupy the same slot, so the dialog never moves or closes under the
    /// cashier's finger.
    private func fieldHeader(icon: String, title: String, field: EditField) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(.posTextSecondary)
            Text(LocalizedStringKey(title)).font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.16)) {
                    editingField = editingField == field ? nil : field
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: editingField == field ? "checkmark" : "pencil")
                        .font(.system(size: 11, weight: .semibold))
                    Text(LocalizedStringKey(editingField == field ? "Done" : "Edit"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.posPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(L10n.t(editingField == field ? "Done editing %@" : "Edit %@", title)))
        }
    }

    private var serviceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldHeader(icon: "fork.knife", title: "Service", field: .service)
            if editingField == .service {
                HStack(spacing: 8) {
                    confirmTypeCard(title: "DINE IN", icon: "fork.knife", id: 1)
                    confirmTypeCard(title: "TAKE AWAY", icon: "takeoutbag.and.cup.and.straw", id: 3)
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: tab.storeServiceTypesId == 3 ? "takeoutbag.and.cup.and.straw" : "fork.knife").font(.system(size: 13)).foregroundColor(tab.storeServiceTypesId == 3 ? .posStatusConfirmed : .posPrimary)
                    Text(LocalizedStringKey(tab.storeServiceTypesId == 3 ? "TAKE AWAY" : "DINE IN")).font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.posAccent)
                }
                .padding(.horizontal, 12).frame(height: 44)
                .background(Color.posAccentSoft)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posAccent.opacity(0.6), lineWidth: 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var customerField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldHeader(icon: "person.fill", title: "Customer", field: .customer)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                hideKeyboard()
                showCustomerPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: tab.customer.isEmpty ? "person.badge.plus" : "person.fill.checkmark")
                        .font(.system(size: 13))
                        .foregroundColor(tab.customer.isEmpty ? .posTextSecondary.opacity(0.6) : .posPrimary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(tab.customer.isEmpty ? "Walk-in" : tab.customer))
                            .font(.system(size: 13, weight: tab.customer.isEmpty ? .regular : .semibold))
                            .foregroundColor(tab.customer.isEmpty ? .posTextSecondary.opacity(0.7) : .posTextPrimary)
                            .lineLimit(1)
                        // The order will be filed under this customer id; show the
                        // phone so the cashier can confirm they picked the right one.
                        if let phone = tab.customerRecord?.phoneValue, !phone.isEmpty {
                            Text(phone)
                                .font(.system(size: 11))
                                .foregroundColor(.posTextSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if tab.customerRecord != nil {
                        Text(L10n.t("ID %lld", tab.customerRecord?.id ?? -1))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.posPrimary)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.posAccentSoft)
                            .clipShape(Capsule())
                    } else {
                        Text("Search or register")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.posPrimary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.posTextSecondary)
                }
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(Color.posRowEven)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(tab.customerRecord == nil ? Color.posOutlineVariant : Color.posAccent.opacity(0.6), lineWidth: tab.customerRecord == nil ? 1 : 1.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(LocalizedStringKey("Search an existing customer by phone or register a new one")))
            if tab.customerRecord == nil {
                Text("No customer linked — this sale is recorded as a walk-in").font(.system(size: 11)).foregroundColor(.posTextSecondary)
            }
        }
    }

    private var discountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldHeader(icon: "tag.fill", title: "Discount", field: .discount)
            HStack(spacing: 8) {
                Text("Rp.").font(.system(size: 14, weight: .semibold)).foregroundColor(.posTextSecondary)
                if editingField == .discount {
                    TextField("0", text: confirmDiscountBinding)
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.posTextPrimary)
                        .tint(.posAccent).keyboardType(.numberPad)
                    if discountValue > 0 {
                        Button { formVM.setDiscount("0") } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.posTextSecondary)
                        }.buttonStyle(.plain)
                    }
                } else {
                    Text(LocalizedStringKey(discountValue > 0 ? CurrencyUtils.formatRp(discountValue).replacingOccurrences(of: "Rp.", with: "") : "0"))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(discountValue > 0 ? .posStatusVoid : .posTextSecondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12).frame(height: 44)
            .background(Color.posRowEven)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(editingField == .discount ? Color.posAccent.opacity(0.6) : Color.posOutlineVariant, lineWidth: editingField == .discount ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            if discountValue > 0 && editingField != .discount {
                Text("Discount applied from cart").font(.system(size: 11)).foregroundColor(.posStatusVoid)
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldHeader(icon: "note.text", title: "Note", field: .note)
            Group {
                if editingField == .note {
                    TextField("Add note e.g. less sugar, no ice", text: confirmRemarkBinding)
                        .font(.system(size: 13)).foregroundColor(.posTextPrimary).tint(.posAccent)
                } else {
                    Text(LocalizedStringKey(tab.remark.isEmpty ? "No notes" : tab.remark))
                        .font(.system(size: 13, weight: tab.remark.isEmpty ? .regular : .medium))
                        .foregroundColor(tab.remark.isEmpty ? .posTextSecondary.opacity(0.7) : .posTextPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44, alignment: .leading)
            .background(Color.posRowEven)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(editingField == .note ? Color.posAccent.opacity(0.6) : Color.posOutlineVariant, lineWidth: editingField == .note ? 1.5 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }


    private func confirmTypeCard(title: String, icon: String, id: Int) -> some View {
        let selected = tab.storeServiceTypesId == id
        return Button {
            // Routed through the view model so a service change invalidates the
            // pending order like any other cart edit does.
            formVM.setStoreServiceType(id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14)).foregroundColor(selected ? .posAccent : .posGrayButton)
                Text(LocalizedStringKey(title)).font(.system(size: 14, weight: selected ? .bold : .regular)).foregroundColor(selected ? .posTextPrimary : .posTextSecondary)
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.posAccent) }
            }.padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.posAccentSoft : Color.posBgLight)
                .overlay(RoundedRectangle(cornerRadius: PosShape.cornerMedium).stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
        }.buttonStyle(.plain)
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Payment Method").font(.system(size: 18, weight: .bold)).foregroundColor(.posPrimary)
                Spacer()
                Text("Total : \(CurrencyUtils.formatRp(totalValue))").font(.system(size: 13, weight: .bold)).foregroundColor(.posTextSecondary)
            }
            paymentSelector
            Group {
                if selectedPayment == 1 { cashPanel } else {
                    Color.clear.frame(height: 230).overlay(Text(LocalizedStringKey(selectedPayment == 2 ? "Scan QR Code" : "Tap card on reader")).font(.system(size: 12)).foregroundColor(.posTextSecondary))
                }
            }.frame(height: 230).animation(.easeInOut(duration: 0.15), value: selectedPayment)
            if let status = statusMessage { Text(status).font(.system(size: 13)).foregroundColor(.posStatusVoid).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(16).background(Color.posBgLight).cornerRadius(8)
    }

    private var paymentSelector: some View {
        HStack(spacing: 12) {
            paymentCard(title: "Scan QR Code", icon: "qrcode", id: 2)
            paymentCard(title: "Pay by Card", icon: "creditcard", id: 3)
            paymentCard(title: "Cash", icon: "banknote", id: 1)
        }
    }

    private func paymentCard(title: String, icon: String, id: Int) -> some View {
        let selected = selectedPayment == id
        return Button { selectedPayment = id; if id == 1 { cashReceived = 0 } } label: {
            VStack(spacing: 8) {
                ZStack { Circle().fill(selected ? Color.posAccentSoft : Color.posBgLight).frame(width: 52, height: 52)
                    Image(systemName: icon).font(.system(size: 24)).foregroundColor(selected ? .posAccent : .posGrayButton) }
                Text(LocalizedStringKey(title)).font(.system(size: 13, weight: selected ? .bold : .regular)).foregroundColor(selected ? .posPrimaryDark : .posTextSecondary)
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.posAccent) }
            }.frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(selected ? Color.posRowEven : Color.posBgLight)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: selected ? Color.posAccent.opacity(0.2) : Color.clear, radius: 6, x: 0, y: 2)
        }.buttonStyle(.plain)
    }

    private var cashPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(denominations, id: \.self) { amount in
                            Button { cashReceived += amount; UIImpactFeedbackGenerator(style: .light).impactOccurred() } label: {
                                Text(CurrencyUtils.formatRp(amount).replacingOccurrences(of: "Rp.", with: "").trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44).background(Color.posRowEven)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posDivider, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 10))
                                    .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 4) {
                        Button("CLEAR") { cashReceived = 0 }.buttonStyle(PosButtonStyle(filled: false, outlineColor: .posStatusVoid))
                        Button("EXACT") { cashReceived = totalValue }.buttonStyle(PosButtonStyle(filled: true))
                    }
                    .padding(.top, 8)
                }.frame(maxWidth: .infinity).frame(minWidth: 260)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cash Received").font(.system(size: 11)).foregroundColor(.posTextSecondary)
                    Text(CurrencyUtils.formatRp(cashReceived)).font(.system(size: 14, weight: .bold)).foregroundColor(.posTextPrimary)
                    Text("Change").font(.system(size: 11)).foregroundColor(.posTextSecondary).padding(.top, 8)
                    Text(CurrencyUtils.formatRp(change)).font(.system(size: 14, weight: .bold)).foregroundColor(.posAccent)
                }.frame(width: 120)
            }
        }.padding(10).background(Color.posRowOdd).cornerRadius(8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Cancel") { onClose() }.buttonStyle(PosButtonStyle(filled: false))
            Spacer()
            Button(LocalizedStringKey(needsReconfirm ? "Confirm & Pay" : "Pay")) { pay() }
                .buttonStyle(PosButtonStyle(filled: true))
                .disabled(working)
        }.padding(12).background(Color.posSurface).overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
    }

    private var displayGroups: [DisplayGroup] {
        isCartMode ? cartGroups : orderGroups
    }
    private var cartGroups: [DisplayGroup] {
        var groups: [String: DisplayGroup] = [:]
        for item in tab.items {
            let line = ConfirmLine(id: item.lineKey,
                                   skuName: item.skuName,
                                   options: item.customizations.map { $0.displayName }.joined(separator: " • "),
                                   price: item.unitPrice,
                                   quantity: item.quantity,
                                   lineTotal: item.lineTotal)
            if var g = groups[item.productName] { g.lines.append(line); groups[item.productName] = g }
            else { groups[item.productName] = DisplayGroup(productName: item.productName, lines: [line]) }
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }
    private var orderGroups: [DisplayGroup] {
        var groups: [String: DisplayGroup] = [:]
        for detail in existingOrder?.orderDetails ?? [] {
            let name = detail.productName ?? ""
            var group = groups[name] ?? DisplayGroup(productName: name, lines: [])
            // Each variant shows its own choices: Big ordered Hot and Regular ordered Ice
            // must not read as one cup of both. Choices from orders written before the line
            // link existed have no variant, so they fall back to the product line.
            let unattached = detail.unattachedCustomizationsByGroup
                .flatMap { $0.items.map { $0.groupedDisplayName } }
                .joined(separator: " • ")
            for sku in detail.orderDetailSkus ?? [] {
                let own = detail.customizations(forSku: sku)
                    .flatMap { $0.items.map { $0.groupedDisplayName } }
                    .joined(separator: " • ")
                let options = own.isEmpty ? unattached : own
                group.lines.append(ConfirmLine(id: "\(name)-\(sku.id ?? -1)-\(options)",
                                    skuName: sku.skuName ?? "",
                                    options: options,
                                   price: sku.priceValue,
                                   quantity: Int(sku.quantityValue),
                                   lineTotal: sku.amountValue))
            }
            groups[name] = group
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }
    private var totalItemCount: Int {
        isCartMode ? tab.items.reduce(0) { $0 + $1.quantity } : (existingOrder?.orderDetails ?? []).reduce(0) { $0 + ($1.orderDetailSkus ?? []).reduce(0) { $0 + Int($1.quantityValue) } }
    }
    private var subTotalValue: Double { isCartMode ? tab.subtotal : existingOrder?.subTotalValue ?? 0 }
    private var discountValue: Double { isCartMode ? Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0 : existingOrder?.discountTotalValue ?? 0 }
    private var totalValue: Double { isCartMode ? max(0, subTotalValue - discountValue) : existingOrder?.grandTotalValue ?? 0 }
    private var change: Double { max(0, cashReceived - totalValue) }
    /// The editors write through the view model, which is what rotates the
    /// idempotency key and drops the stale confirmed order after a change.
    private var confirmDiscountBinding: Binding<String> {
        Binding(get: { tab.discount },
                set: { formVM.setDiscount(CurrencyUtils.formatWholeInput($0)) })
    }

    private var confirmRemarkBinding: Binding<String> {
        Binding(get: { tab.remark }, set: { formVM.setRemark($0) })
    }

    /// Pays the order. In cart mode an edit leaves no confirmed order behind, so the
    /// sale is confirmed again first — paying the pre-edit version would drop the
    /// change the cashier just made.
    private func pay() {
        guard !working else { return }
        if selectedPayment == 1, cashReceived < totalValue {
            statusMessage = L10n.t("Insufficient cash entered!")
            toastManager.show(L10n.t("Insufficient cash entered!"), style: .error)
            return
        }
        if isCartMode, formVM.confirmedOrder == nil {
            reconfirmThenPay()
            return
        }
        guard let orderToPay = existingOrder ?? formVM.confirmedOrder else {
            statusMessage = L10n.t("No confirmed order to pay")
            toastManager.show(L10n.t("No confirmed order"), style: .error)
            return
        }
        statusMessage = nil
        withAnimation(.easeInOut(duration: 0.2)) { working = true }
        Task {
            do {
                let request = PaymentRequest(orderId: orderToPay.id, paymentId: selectedPayment)
                let paidOrder = try await APIClient.shared.payOrder(request)
                PrinterManager.print(PrintUtils.buildReceiptText(paidOrder)) { _ in }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { working = false }
                    toastManager.show(L10n.t("Payment successful"), style: .success)
                    onClose()
                    if isCartMode {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                            _ = formVM.removeActiveTab()
                        }
                    } else {
                        onSuccess?()
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) { working = false }
                    let msg = L10n.t("Payment failed: %@", error.localizedDescription)
                    statusMessage = msg
                    toastManager.show(msg, style: .error)
                }
            }
        }
    }

    private func reconfirmThenPay() {
        guard !working else { return }
        statusMessage = nil
        withAnimation(.easeInOut(duration: 0.2)) { working = true }
        Task {
            let success = await formVM.confirmOrder(customerName: tab.customer,
                                                    discount: CurrencyUtils.digitsOnly(tab.discount),
                                                    remark: tab.remark)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) { working = false }
                if success {
                    pay()
                } else {
                    let msg = formVM.error ?? L10n.t("Could not confirm the updated order")
                    statusMessage = msg
                    toastManager.show(msg, style: .error)
                }
            }
        }
    }
}

private struct ConfirmLineRow: View {
    let line: ConfirmLine
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.skuName).font(.system(size: 13, weight: .semibold)).foregroundColor(.posTextPrimary)
                if !line.options.isEmpty {
                    Text(line.options).font(.system(size: 11)).foregroundColor(.posAccent).lineLimit(1)
                }
                Text(CurrencyUtils.formatRp(line.price)).font(.system(size: 11, weight: .medium)).foregroundColor(.posTextPrimary).opacity(0.85)
            }
            Spacer()
            Text("x\(line.quantity)").font(.system(size: 12, weight: .bold)).foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 3).background(Color.posAccent).cornerRadius(4)
            Text(CurrencyUtils.formatRp(line.lineTotal)).font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary).frame(width: 110, alignment: .trailing)
        }.padding(.horizontal, 16).padding(.vertical, 5)
    }
}
private struct ConfirmLine: Identifiable {
    let id: String
    let skuName: String
    let options: String
    let price: Double
    let quantity: Int
    let lineTotal: Double
}
private struct DisplayGroup: Identifiable { let productName: String; var lines: [ConfirmLine]; var id: String { productName } }

