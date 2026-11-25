import SwiftUI
import UIKit

// MARK: - ProductDetailPopup (POS customization dialog)
//
// Layout follows the POS mockup: product header, variant chips, one row of
// choice chips per single-answer group, a two-column grid of checkbox cards for
// multi-answer groups, a kitchen note, and a footer with the line quantity and a
// single "Add to order" button showing the line total.
//
// Options are still resolved client-side only for display; the order service
// re-prices the line from the option ids.

struct ProductDetailPopup: View {
    let product: Product
    var onClose: () -> Void

    @EnvironmentObject var formVM: OrderFormViewModel

    @State private var selectedSkuId: Int?
    @State private var selection = CustomizationSelection()
    @State private var quantity = 1
    @State private var note = ""

    private var skus: [Sku] { product.skus ?? [] }
    private var groups: [ProductCustomization] { formVM.customizations(for: product.id) }
    private var selectedSku: Sku? { skus.first { $0.id == selectedSkuId } }
    private var isLoading: Bool { formVM.loadingCustomizationProductId == product.id }
    private var multipleSkus: Bool { skus.count > 1 }

    private var pending: [SelectedCustomization] { selection.resolved(from: groups) }

    private var pendingSurcharge: Double {
        pending.reduce(0) { $0 + $1.price * Double(max(1, $1.quantity)) }
    }

    private var unitTotal: Double { (selectedSku?.price ?? 0) + pendingSurcharge }
    private var lineTotal: Double { unitTotal * Double(max(1, quantity)) }

    private var unmet: [ProductCustomization] { selection.unmetRequirements(in: groups) }
    private var canAdd: Bool { selectedSku != nil && unmet.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.posDivider)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if multipleSkus { variantSection }
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("Loading options...").font(.system(size: 12)).foregroundColor(.posTextSecondary)
                        }
                    }
                    ForEach(groups) { group in
                        groupSection(group)
                    }

                    noteSection
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)

            Divider().overlay(Color.posDivider)
            footer
        }
        .frame(width: min(560, UIScreen.main.bounds.width - 40))
        .frame(maxHeight: min(760, UIScreen.main.bounds.height * 0.92))
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
        .onAppear {
            // This note belongs to the line being added, not to the whole order.
            // The order-level note lives in the Order Details panel.
            note = ""
            if skus.count == 1 { selectedSkuId = skus.first?.id }
        }
        .task(id: product.id) { await formVM.loadCustomizations(productId: product.id) }
        .dismissKeyboardOnTap()
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(product.nameValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.posTextSecondary)
            }
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.posBgLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var subtitle: String {
        let price = selectedSku?.price ?? (skus.first?.price ?? 0)
        var text = CurrencyUtils.formatRp(price)
        if let sku = selectedSku, multipleSkus { text += " · \(sku.name ?? "")" }
        return text
    }

    // MARK: - Variant chips

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(title: "Select Variant", hint: nil)
            chipRow {
                ForEach(skus) { sku in
                    ChoiceChip(text: "\(sku.name ?? "") · \(CurrencyUtils.formatRp(sku.price))",
                               selected: sku.id == selectedSkuId) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        if selectedSkuId == sku.id {
                            selectedSkuId = nil
                        } else {
                            selectedSkuId = sku.id
                            selection = CustomizationSelection()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Groups

    @ViewBuilder
    private func groupSection(_ group: ProductCustomization) -> some View {
        // Options are chosen for a specific SKU; lock them until one is picked.
        let locked = multipleSkus && selectedSku == nil
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(title: group.nameValue, hint: groupHint(group))

            if locked {
                Text("Select a variant above to choose options")
                    .font(.system(size: 12))
                    .foregroundColor(.posTextSecondary)
                    .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .background(Color.posBgLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if group.allowsMultiple {
                optionGrid(group)
            } else {
                chipRow {
                    ForEach(group.sortedOptions) { option in
                        ChoiceChip(text: chipLabel(option),
                                   selected: selection.isSelected(option.id, in: group.customizationId)) {
                            selection.select(option.id, in: group)
                        }
                    }
                }
            }
        }
        .opacity(locked ? 0.5 : 1)
    }

    private func optionGrid(_ group: ProductCustomization) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(group.sortedOptions) { option in
                OptionCard(
                    name: option.nameValue,
                    priceText: option.price > 0 ? "+\(CurrencyUtils.formatRp(option.price))" : L10n.t("Free"),
                    selected: selection.isSelected(option.id, in: group.customizationId),
                    quantity: group.allowsQuantity ? selection.count(of: option.id, in: group.customizationId) : 0,
                    allowsQuantity: group.allowsQuantity,
                    canIncrement: selection.canIncrement(option.id, in: group),
                    onToggle: { selection.select(option.id, in: group) },
                    onIncrement: { selection.increment(option.id, in: group) },
                    onDecrement: { selection.decrement(option.id, in: group) }
                )
            }
        }
    }

    private func groupHeader(title: String, hint: String?) -> some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.posTextPrimary)
            Spacer()
            if let hint {
                Text(hint)
                    .font(.system(size: 13))
                    .foregroundColor(.posTextSecondary)
            }
        }
    }

    private func groupHint(_ group: ProductCustomization) -> String {
        let min = group.minCount
        let max = group.maxCount
        if min > 0, group.allowsMultiple, max > min { return L10n.t("Choose %d-%d", min, max) }
        if min > 0 { return L10n.t("Choose 1") }
        if group.allowsMultiple, max > 1 { return L10n.t("Choose max %d", max) }
        return L10n.t("Optional")
    }

    private func chipRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }
                .padding(.vertical, 2)
        }
    }

    private func chipLabel(_ option: CustomizationOption) -> String {
        option.price > 0
            ? "\(option.nameValue) · +\(CurrencyUtils.formatRp(option.price))"
            : option.nameValue
    }

    // MARK: - Kitchen note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeader(title: "Item note", hint: nil)
            TextEditor(text: $note)
                .font(.system(size: 14))
                .foregroundColor(.posTextPrimary)
                .frame(minHeight: 64)
                .padding(8)
                .background(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posDivider, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if note.isEmpty {
                        Text("mis. ayam jangan terlalu gosong")
                            .font(.system(size: 14))
                            .foregroundColor(.posTextSecondary.opacity(0.6))
                            .padding(.horizontal, 12).padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Button {
                    if quantity > 1 { quantity -= 1; UISelectionFeedbackGenerator().selectionChanged() }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(quantity > 1 ? .posTextPrimary : .posTextSecondary.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .background(Color.posBgLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(quantity <= 1)

                Text("\(quantity)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.posTextPrimary)
                    .frame(width: 36)

                Button {
                    quantity += 1; UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.posAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button {
                addToCart()
            } label: {
                Text(canAdd
                     ? L10n.t("Add to Order · %@", CurrencyUtils.formatRp(lineTotal))
                     : L10n.t("Add to Order"))
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PosButtonStyle(filled: true))
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func addToCart() {
        guard let sku = selectedSku else { return }
        formVM.addToCart(product: product, sku: sku, customizations: pending,
                         quantity: quantity, remark: note)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onClose()
    }
}

// MARK: - Chips + cards

private struct ChoiceChip: View {
    let text: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: selected ? .bold : .regular))
                .foregroundColor(selected ? .white : .posTextPrimary)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(selected ? Color.posPrimary : Color.white)
                .overlay(RoundedRectangle(cornerRadius: 22)
                    .stroke(selected ? Color.posPrimary : Color.posDivider, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

private struct OptionCard: View {
    let name: String
    let priceText: String
    let selected: Bool
    let quantity: Int
    let allowsQuantity: Bool
    let canIncrement: Bool
    let onToggle: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(selected ? .posPrimary : .posTextSecondary.opacity(0.5))
                    Text(name)
                        .font(.system(size: 14))
                        .foregroundColor(.posTextPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if allowsQuantity && selected {
                HStack(spacing: 4) {
                    Button(action: onDecrement) {
                        Image(systemName: "minus.circle.fill").foregroundColor(.posTextSecondary)
                    }.buttonStyle(.plain)
                    Text("\(quantity)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.posPrimary)
                        .frame(minWidth: 14)
                    Button(action: onIncrement) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(canIncrement ? .posPrimary : .posPrimary.opacity(0.3))
                    }.buttonStyle(.plain).disabled(!canIncrement)
                }
            } else {
                Text(priceText)
                    .font(.system(size: 12))
                    .foregroundColor(.posTextSecondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(selected ? Color.posAccentSoft : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(selected ? Color.posPrimary : Color.posDivider, lineWidth: selected ? 1.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

