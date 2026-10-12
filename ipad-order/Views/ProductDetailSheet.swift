import SwiftUI
import UIKit

// MARK: - ProductDetailPopup (compact POS dialog)
// FIX: Replaces system .sheet (900-1000pt wide) with compact centered dialog ~420pt.
// No .sheet, no .presentationDetents, no GeometryReader, no outer white background.
// Preserves: colors, fonts, SKU layout, ProductImageThumb, business logic.
//
// Variant selection plus the product's customization groups. The cashier picks a
// SKU, then answers each group (single or multiple, bounded by the group's min/max),
// then commits the whole line in one go. Only option IDs reach the order service —
// it resolves the names and prices itself.

struct ProductDetailPopup: View {
    let product: Product
    var onClose: () -> Void

    @EnvironmentObject var formVM: OrderFormViewModel

    @State private var selectedSkuId: Int?
    @State private var selection = CustomizationSelection()

    private var skus: [Sku] { product.skus ?? [] }
    private var groups: [ProductCustomization] { formVM.customizations(for: product.id) }
    private var selectedSku: Sku? { skus.first { $0.id == selectedSkuId } }
    private var isLoading: Bool { formVM.loadingCustomizationProductId == product.id }

    private var pending: [SelectedCustomization] {
        selection.resolved(from: groups)
    }

    private var pendingSurcharge: Double {
        pending.reduce(0) { $0 + $1.price * Double(max(1, $1.quantity)) }
    }

    private var pendingTotal: Double {
        (selectedSku?.price ?? 0) + pendingSurcharge
    }

    private var unmet: [ProductCustomization] {
        selection.unmetRequirements(in: groups)
    }

    private var canAdd: Bool { selectedSku != nil && unmet.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            variantSection

            if !groups.isEmpty {
                Divider().opacity(0.6)
                // Options are chosen for a specific SKU, so they stay locked until
                // one is picked. A single-SKU product auto-selects on appear, so it
                // never shows this state.
                if selectedSku == nil {
                    lockedCustomizationHint
                } else {
                    customizationSections
                }
            }

            footer
        }
        .padding(16)
        .frame(width: min(420, UIScreen.main.bounds.width - 32))
        .frame(maxHeight: min(640, UIScreen.main.bounds.height * 0.86))
        .background(Color.posSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
        .onAppear(perform: selectDefaultSku)
        .task(id: product.id) { await formVM.loadCustomizations(productId: product.id) }
        .onChange(of: selectedSkuId) { newValue in
            // Options are chosen per SKU, so a different SKU starts a fresh answer.
            if newValue != initialSkuId { selection = CustomizationSelection() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ProductImageThumb(product: product)
                .frame(width: 50, height: 50)
                .background(Color.posSurfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(product.nameValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.posTextPrimary)
                if selectedSku != nil {
                    Text(selectedSku?.name ?? "")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.posAccent)
                }
            }
            Spacer()
            Button { onClose() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.posTextSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.posBgLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Variants

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.posPrimary)
                Text(skus.count > 1 ? "Select Variant" : "Select Item")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.posPrimary)
                if isLoading {
                    Spacer()
                    ProgressView().scaleEffect(0.7)
                }
            }

            if skus.isEmpty {
                Text("No variants available")
                    .font(.system(size: 12))
                    .foregroundColor(Color.posTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(Color.posBgLight)
                    .cornerRadius(6)
            } else {
                VStack(spacing: 6) {
                    ForEach(skus) { sku in
                        variantRow(sku)
                    }
                }
            }
        }
    }

    private func variantRow(_ sku: Sku) -> some View {
        let isSelected = sku.id == selectedSkuId
        let qty = cartQuantity(forSku: sku.id)
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.7)) { selectedSkuId = isSelected ? nil : sku.id }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 0) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 15))
                    .foregroundColor(isSelected ? Color.posAccent : Color.posTextSecondary.opacity(0.45))
                    .frame(width: 30, height: 32)

                Text(sku.name ?? "")
                    .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(Color.posTextPrimary)
                    .lineLimit(1)

                Spacer()

                Text(CurrencyUtils.formatRp(sku.price))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.posAccent)

                // Qty badge — total already in the cart for this SKU, across every
                // customization variant of it.
                if qty > 0 {
                    Text("\(qty)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.posPrimaryDark)
                        .frame(width: 26, height: 22)
                        .background(Color.posAccentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, 6)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(isSelected ? Color.posAccentSoft.opacity(0.45) : Color.posRowEven)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.posAccent : Color.posDivider, lineWidth: isSelected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: qty)
    }

    private func cartQuantity(forSku skuId: Int) -> Int {
        formVM.activeTab?.items
            .filter { $0.productId == product.id && $0.skuId == skuId }
            .reduce(0) { $0 + $1.quantity } ?? 0
    }

    // MARK: - Customizations

    private var lockedCustomizationHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.posTextSecondary)
            Text("Select a variant above to choose options")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.posTextSecondary)
            Spacer()
            Text("\(groups.count) group\(groups.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(Color.posTextSecondary.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(Color.posBgLight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var customizationSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(groups) { group in
                    customizationSection(group)
                }
            }
        }
        // Defence in depth: the sections only render with a SKU selected, and this
        // makes an option untappable even if that gating is ever loosened.
        .disabled(selectedSku == nil)
    }

    private func customizationSection(_ group: ProductCustomization) -> some View {
        // The counter tracks distinct options against the min/max option budget;
        // summed units live on each row's stepper badge instead.
        let chosenCount = selection.distinctCount(in: group.customizationId)
        let options = group.sortedOptions
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(group.nameValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.posTextPrimary)
                if group.isRequired {
                    Text("REQUIRED")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.posStatusVoid)
                        .clipShape(Capsule())
                }
                Spacer()
                if group.allowsMultiple || group.allowsQuantity {
                    HStack(spacing: 6) {
                        Text("Pick up to \(group.maxCount)")
                            .font(.system(size: 10))
                            .foregroundColor(Color.posTextSecondary)
                        Text("\(chosenCount)/\(group.maxCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(chosenCount >= group.maxCount ? Color.posAccent : Color.posTextSecondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(chosenCount >= group.maxCount ? Color.posAccentSoft : Color.posBgLight)
                            .clipShape(Capsule())
                    }
                }
            }

            if options.isEmpty {
                Text("No options available")
                    .font(.system(size: 11))
                    .foregroundColor(Color.posTextSecondary)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.posBgLight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 6) {
                    ForEach(options) { option in
                        optionRow(option, group: group)
                    }
                }
            }
        }
    }

    private func optionRow(_ option: CustomizationOption, group: ProductCustomization) -> some View {
        let count = selection.count(of: option.id, in: group.customizationId)
        let isSelected = count > 0
        // In quantity mode the cap is the summed units against maxSelection; the
        // `+` goes dead the moment the group budget is spent.
        let canAddMore = group.allowsQuantity
            ? selection.canIncrement(option.id, in: group)
            : false

        // Two sibling controls, not nested: the body selects (radio / checkbox),
        // and — only when the catalogue allows quantities — the trailing stepper
        // moves the option by a single unit so it can be ordered more than once.
        return HStack(spacing: 0) {
            Button {
                select(option, group: group)
            } label: {
                HStack(spacing: 0) {
                    // Radio for a single-choice group, checkbox where more can be picked.
                    Image(systemName: optionIcon(isSelected: isSelected, group: group))
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? Color.posAccent : Color.posTextSecondary.opacity(0.5))
                        .frame(width: 28, height: 30)

                    Text(option.nameValue)
                        .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                        .foregroundColor(Color.posTextPrimary)
                        .lineLimit(1)

                    if count > 1 {
                        Text("×\(count)")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(Color.posAccent)
                            .padding(.leading, 4)
                    }

                    Spacer()

                    if option.price > 0 {
                        Text("+\(CurrencyUtils.formatRp(option.price))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.posAccent)
                    }
                }
                .padding(.leading, 10)
                .padding(.trailing, group.allowsQuantity ? 4 : 10)
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if group.allowsQuantity {
                quantityStepper(option, group: group, count: count, canAddMore: canAddMore)
            }
        }
        .frame(height: 34)
        .background(isSelected ? Color.posAccentSoft.opacity(0.4) : Color.posRowOdd)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.posAccent.opacity(0.6) : Color.posDivider, lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// A minus / count / plus control for a quantity group. Each tap moves the
    /// option by one unit; the count never drops below zero and `+` goes dead
    /// once the summed units reach the group's `maxCount`, which is the same
    /// budget the menu service enforces.
    private func quantityStepper(_ option: CustomizationOption, group: ProductCustomization,
                                 count: Int, canAddMore: Bool) -> some View {
        HStack(spacing: 3) {
            if count > 0 {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                        selection.decrement(option.id, in: group)
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Color.posTextSecondary)
                }
                .buttonStyle(.plain)

                Text("\(count)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Color.posAccent)
                    .frame(minWidth: 12)
            }

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) {
                    selection.increment(option.id, in: group)
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(canAddMore ? Color.posAccent : Color.posAccent.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!canAddMore)
        }
        .padding(.trailing, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.nameValue), \(count) selected")
    }

    private func select(_ option: CustomizationOption, group: ProductCustomization) {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.75)) { selection.select(option.id, in: group) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Footer

    private func optionIcon(isSelected: Bool, group: ProductCustomization) -> String {
        if group.allowsMultiple { return isSelected ? "checkmark.square.fill" : "square" }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if !unmet.isEmpty, selectedSku != nil {
                Text(unmet.map { $0.nameValue }.joined(separator: ", ") + " is required")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.posStatusVoid)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if pendingSurcharge > 0 {
                HStack {
                    Text("Options")
                        .font(.system(size: 12))
                        .foregroundColor(Color.posTextSecondary)
                    Spacer()
                    Text("+\(CurrencyUtils.formatRp(pendingSurcharge))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.posAccent)
                }
            }

            Button {
                guard let sku = selectedSku else { return }
                formVM.addToCart(product: product, sku: sku, customizations: pending)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selection = CustomizationSelection()
                selectedSkuId = skus.count == 1 ? sku.id : nil
                onClose()
            } label: {
                HStack(spacing: 6) {
                    Text("Add to Cart")
                    Text(CurrencyUtils.formatRp(pendingTotal))
                        .fontWeight(.heavy)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PosButtonStyle(filled: true))
            .disabled(!canAdd)
            .opacity(canAdd ? 1 : 0.4)
            .animation(.easeOut(duration: 0.15), value: canAdd)
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private var initialSkuId: Int? {
        skus.count == 1 ? skus.first?.id : nil
    }

    private func selectDefaultSku() {
        if selectedSkuId == nil { selectedSkuId = initialSkuId }
    }
}

#Preview {
    ProductDetailPopup(product: Product(id: 1, name: "Gula Aren", categoryId: 1, skus: [], productImage: nil), onClose: {})
        .environmentObject(OrderFormViewModel())
        .padding()
        .background(Color.black.opacity(0.45))
}