import SwiftUI

struct OrderFormView: View {
    @EnvironmentObject var formVM: OrderFormViewModel
    @EnvironmentObject var toastManager: ToastManager
    @ObservedObject var tab: OrderTab

    @State private var selectedProduct: Product?
    @State private var showConfirm = false
    @State private var showOrderDetails = false
    @State private var showSummary = false
    @State private var confirmingOrder = false

    private let repository = MenuRepository()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                categoryColumn
                productColumn
                cartColumn
            }

            if let product = selectedProduct {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                ProductDetailPopup(product: product) { selectedProduct = nil }
                    .environmentObject(formVM)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }

            if showSummary {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                    .onTapGesture { showSummary = false }
                OrderSummaryPopup(tab: tab) { showSummary = false }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(2)
            }

            if showConfirm {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                OrderConfirmPopup(tab: tab, existingOrder: nil, onSuccess: nil) {
                    showConfirm = false
                }
                .environmentObject(formVM)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(3)
            }
        }
        .dismissKeyboardOnTap()
        .animation(.easeOut(duration: 0.2), value: selectedProduct != nil)
        .animation(.easeOut(duration: 0.2), value: showConfirm)
        .animation(.easeOut(duration: 0.2), value: showSummary)
        .task { await loadCategories() }
    }

    // MARK: - Category column (12%)

    private var categoryColumn: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill").font(.system(size: 15)).foregroundColor(.posPrimary)
                Text("Category").font(.system(size: 16, weight: .bold)).foregroundColor(.posTextPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tab.categories) { category in
                        Button {
                            selectCategory(category)
                        } label: {
                            HStack(spacing: 10) {
                                Text(category.name ?? "")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(tab.selectedCategoryId == category.id ? .white : .posTextPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if tab.selectedCategoryId == category.id {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 13).padding(.horizontal, 14)
                            .background(tab.selectedCategoryId == category.id ? AnyShapeStyle(Color.posPrimaryGradient) : AnyShapeStyle(Color.posSurfaceContainerHigh))
                            .overlay(RoundedRectangle(cornerRadius: PosShape.cornerMedium).stroke(tab.selectedCategoryId == category.id ? Color.clear : Color.posOutlineVariant, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
                            .shadow(color: tab.selectedCategoryId == category.id ? Color.posPrimary.opacity(0.28) : Color.clear, radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
        }
        .padding(12)
        .background(Color.posBgLight)
        .frame(width: 180)
    }

    // MARK: - Product column (53%)

    private var productColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Color.posAccent).frame(width: 4, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCategoryName).font(.system(size: 17, weight: .bold)).foregroundColor(.posTextPrimary)
                    Text("\(tab.products.count) items").font(.system(size: 12)).foregroundColor(.posTextSecondary)
                }
                Spacer()
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 15)).foregroundColor(.posAccent)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.posSurfaceContainer)
            .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)

            if tab.loadingProducts {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<8, id: \.self) { _ in SkeletonProductCard() }
                    }.padding(10)
                }.redacted(reason: .placeholder)
            } else if let error = tab.error, !error.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 28)).foregroundColor(.posStatusVoid)
                    Text(error).font(.system(size: 14)).foregroundColor(.posStatusVoid).multilineTextAlignment(.center)
                }.padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(tab.products) { product in
                            ProductCard(product: product) { handleProductTap(product) }
                        }
                    }.padding(10)
                }
            }
        }
        .background(Color.posBgLight)
        .frame(maxWidth: .infinity)
    }

    private var selectedCategoryName: String {
        if let id = tab.selectedCategoryId, let category = tab.categories.first(where: { $0.id == id }) {
            return category.name ?? ""
        }
        return "All Categories"
    }

    private var discountBinding: Binding<String> {
        Binding(get: { tab.discount }, set: { tab.discount = CurrencyUtils.formatWholeInput($0) })
    }
    private var discountValue: Double { Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0 }

    // MARK: - Cart column (35%)

    private var cartColumn: some View {
        VStack(spacing: 0) {
            Button {
                guard !tab.items.isEmpty else { toastManager.show("Cart is empty", style: .info); return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSummary = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cart.fill").font(.system(size: 15))
                    Text("Order Summary").font(.system(size: 16, weight: .bold))
                    Spacer()
                    if !tab.items.isEmpty {
                        Text("\(totalItemCount)")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(.posPrimaryDark)
                            .frame(width: 26, height: 26).background(Color.white.opacity(0.25)).clipShape(Circle())
                            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: totalItemCount).transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                }
                .foregroundColor(.white).padding(.horizontal, 16).frame(height: 52)
                .background(Color.posPrimaryGradient).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Order Summary, tap to view full list")
            .accessibilityHint(tab.items.isEmpty ? "Cart is empty" : "Shows \(totalItemCount) items")

            serviceTypeSelector

            if tab.items.isEmpty {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.posAccentSoft).frame(width: 72, height: 72)
                        Image(systemName: "cart.badge.plus").font(.system(size: 28)).foregroundColor(.posAccent)
                    }
                    Text("Cart is empty").font(.system(size: 15, weight: .semibold)).foregroundColor(.posTextPrimary)
                    Text("Tap a product to start ordering").font(.system(size: 13)).foregroundColor(.posTextSecondary)
                    Text("Your selected items will appear here").font(.system(size: 11)).foregroundColor(.posTextSecondary.opacity(0.8)).padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(groupedItems, id: \.productId) { group in
                            VStack(spacing: 0) {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill").font(.system(size: 6)).foregroundColor(.posAccent)
                                    Text(group.productName).font(.system(size: 14, weight: .bold)).foregroundColor(.posTextPrimary)
                                    Spacer()
                                    Text("\(group.items.reduce(0){$0+$1.quantity}) items").font(.system(size: 11, weight: .medium)).foregroundColor(.posTextSecondary)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8).background(Color.posAccentSoft)

                                ForEach(group.items) { item in
                                    CartRow(item: item,
                                            onDecrement: { withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) { formVM.decrement(lineKey: item.lineKey) }; UIImpactFeedbackGenerator(style: .light).impactOccurred() },
                                            onIncrement: { withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) { formVM.increment(lineKey: item.lineKey) }; UIImpactFeedbackGenerator(style: .light).impactOccurred() },
                                            onDelete: { withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { formVM.removeItem(lineKey: item.lineKey) }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() })
                                }
                            }
                            .background(Color.posRowEven)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(10)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: groupedItems.count)
                }
            }

            orderDetailsPanel
            totalsPanel
        }
        .background(Color.posBgLight)
        .frame(width: 320)
    }

    // MARK: - Collapsible order details panel

    private var orderDetailsPanel: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.8)) { showOrderDetails.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill").font(.system(size: 12)).foregroundColor(.posPrimary)
                    Text("Order Details").font(.system(size: 13, weight: .bold)).foregroundColor(.posTextPrimary)
                    Spacer()
                    if !showOrderDetails {
                        HStack(spacing: 6) {
                            if !tab.customer.isEmpty { Text(tab.customer).font(.system(size: 11, weight: .semibold)).foregroundColor(.posTextPrimary).lineLimit(1) }
                            if !tab.remark.isEmpty {
                                if !tab.customer.isEmpty { Text("•").font(.system(size: 11)).foregroundColor(.posTextSecondary) }
                                Text(tab.remark).font(.system(size: 11)).foregroundColor(.posTextSecondary).lineLimit(1)
                            }
                            if discountValue > 0 {
                                if !tab.customer.isEmpty || !tab.remark.isEmpty { Text("•").font(.system(size: 11)).foregroundColor(.posTextSecondary) }
                                Text(CurrencyUtils.formatRp(discountValue)).font(.system(size: 11, weight: .bold)).foregroundColor(.posStatusVoid).lineLimit(1)
                            }
                            if tab.customer.isEmpty && tab.remark.isEmpty && discountValue == 0 { Text("Tap to add").font(.system(size: 11)).foregroundColor(.posTextSecondary) }
                        }
                    }
                    Image(systemName: showOrderDetails ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
                }
                .padding(.horizontal, 12).frame(height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Order Details")
            .accessibilityHint(showOrderDetails ? "Collapse" : "Expand to edit customer, note, discount")

            if showOrderDetails {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill").font(.system(size: 13)).foregroundColor(.posTextSecondary)
                        TextField("Customer name (e.g. Budi)", text: $tab.customer)
                            .font(.system(size: 13)).foregroundColor(.posTextPrimary).tint(.posAccent).submitLabel(.next)
                        if !tab.customer.isEmpty { Button { tab.customer = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.posTextSecondary) }.buttonStyle(.plain) }
                    }
                    .padding(.horizontal, 12).frame(height: 44).background(Color.posRowEven)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 8) {
                        Image(systemName: "note.text").font(.system(size: 13)).foregroundColor(.posTextSecondary)
                        TextField("Add note e.g. less sugar, no ice", text: $tab.remark)
                            .font(.system(size: 13)).foregroundColor(.posTextPrimary).tint(.posAccent)
                        if !tab.remark.isEmpty { Button { tab.remark = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(.posTextSecondary) }.buttonStyle(.plain) }
                    }
                    .padding(.horizontal, 12).frame(height: 44).background(Color.posRowEven)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill").font(.system(size: 11)).foregroundColor(.posAccent)
                            Text("Discount").font(.system(size: 12, weight: .semibold)).foregroundColor(.posTextSecondary)
                            Spacer()
                            Text(discountValue > 0 ? CurrencyUtils.formatRp(discountValue) : "No discount").font(.system(size: 12, weight: .bold)).foregroundColor(discountValue > 0 ? .posStatusVoid : .posTextSecondary)
                        }
                        HStack(spacing: 8) {
                            Text("Rp.").font(.system(size: 13, weight: .semibold)).foregroundColor(.posTextSecondary)
                            TextField("0", text: discountBinding).font(.system(size: 13, weight: .medium)).foregroundColor(.posTextPrimary).tint(.posAccent).keyboardType(.numberPad)
                            if discountValue > 0 { Button { tab.discount = "0" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 13)).foregroundColor(.posTextSecondary) }.buttonStyle(.plain) }
                        }
                        .padding(.horizontal, 12).frame(height: 44).background(Color.posRowEven)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.posOutlineVariant, lineWidth: 1)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(12).background(Color.posBgLight)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.posSurface)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
        .animation(.spring(response: 0.30, dampingFraction: 0.8), value: showOrderDetails)
    }

    // MARK: - Totals + action buttons

    private var totalsPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Sub Total").font(.system(size: 14)).foregroundColor(.posTextSecondary)
                Spacer()
                Text(CurrencyUtils.formatRp(tab.subtotal)).font(.system(size: 14, weight: .semibold)).foregroundColor(.posTextPrimary)
            }
            if discountValue > 0 {
                HStack {
                    Text("Discount").font(.system(size: 14)).foregroundColor(.posTextSecondary)
                    Spacer()
                    Text(CurrencyUtils.formatRp(discountValue)).font(.system(size: 14, weight: .semibold)).foregroundColor(.posStatusVoid)
                }
            }
            HStack {
                Text("Total").font(.system(size: 20, weight: .bold)).foregroundColor(.posPrimary)
                Spacer()
                Text(CurrencyUtils.formatRp(max(0, tab.subtotal - discountValue))).font(.system(size: 20, weight: .bold)).foregroundColor(.posPrimary)
            }
            HStack(spacing: 8) {
                Button("Confirm") {
                    confirmingOrder = true
                    Task {
                        let success = await formVM.confirmOrder(customerName: tab.customer, discount: CurrencyUtils.digitsOnly(tab.discount), remark: tab.remark)
                        confirmingOrder = false
                        if success { showConfirm = true }
                        else if let error = formVM.error, !error.isEmpty { toastManager.show(error, style: .error) }
                    }
                }
                .buttonStyle(PosButtonStyle(filled: true))
                .disabled(tab.items.isEmpty || confirmingOrder)
                .opacity((tab.items.isEmpty || confirmingOrder) ? 0.4 : 1)
                .animation(.easeOut(duration: 0.15), value: tab.items.isEmpty)
                .animation(.easeOut(duration: 0.15), value: confirmingOrder)

                Button("Print") { printKitchen() }
                    .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posBlueAction))
                    .disabled(tab.items.isEmpty)
                    .opacity(tab.items.isEmpty ? 0.4 : 1)
                    .animation(.easeOut(duration: 0.15), value: tab.items.isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(16).background(Color.posSurface)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
    }

    // MARK: - Service type selector

    private var serviceTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Type").font(.system(size: 13, weight: .bold)).foregroundColor(.posTextSecondary)
            HStack(spacing: 8) {
                serviceTypeCard(title: "DINE IN", icon: "fork.knife", id: 1)
                serviceTypeCard(title: "TAKE AWAY", icon: "takeoutbag.and.cup.and.straw", id: 3)
            }
        }
        .padding(12).background(Color.white)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
    }

    private func serviceTypeCard(title: String, icon: String, id: Int) -> some View {
        let selected = tab.storeServiceTypesId == id
        return Button { formVM.setStoreServiceType(id) } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(selected ? .posAccent : .posGrayButton)
                Text(title).font(.system(size: 14, weight: selected ? .bold : .regular)).foregroundColor(selected ? .posTextPrimary : .posTextSecondary)
                Spacer()
                if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundColor(.posAccent) }
            }
            .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? Color.posAccentSoft : Color.posBgLight)
            .overlay(RoundedRectangle(cornerRadius: PosShape.cornerMedium).stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed

    private var totalItemCount: Int { tab.items.reduce(0) { $0 + $1.quantity } }

    private var groupedItems: [CartGroup] {
        var groups: [Int: CartGroup] = [:]
        for item in tab.items {
            if var group = groups[item.productId] {
                group.items.append(item)
                groups[item.productId] = group
            } else {
                groups[item.productId] = CartGroup(productId: item.productId, productName: item.productName, items: [item])
            }
        }
        return groups.values.sorted { $0.productName < $1.productName }
    }

    // MARK: - Actions

    private func loadCategories() async {
        tab.loadingCategories = true
        defer { tab.loadingCategories = false }
        do {
            tab.categories = try await repository.getCategories()
            if tab.selectedCategoryId == nil, let first = tab.categories.first { selectCategory(first) }
        } catch {
            let msg = error.localizedDescription; tab.error = msg
            toastManager.show(msg, style: .error)
        }
    }

    private func selectCategory(_ category: Category) {
        tab.selectedCategoryId = category.id
        Task { await loadProducts(categoryId: category.id) }
    }

    private func handleProductTap(_ product: Product) {
        let skus = product.skus ?? []
        let groups = formVM.customizations(for: product.id)
        // A product with customizations must go through the picker even when it has
        // a single SKU — otherwise a required option would be missed and the menu
        // service would reject the line at confirm.
        if groups.isEmpty, skus.count == 1, let sku = skus.first {
            formVM.addToCart(product: product, sku: sku)
        } else {
            selectedProduct = product
        }
    }

    private func loadProducts(categoryId: Int) async {
        tab.loadingProducts = true
        defer { tab.loadingProducts = false }
        do { tab.products = try await repository.getProducts(categoryId: categoryId) }
        catch { let msg = error.localizedDescription; tab.error = msg; toastManager.show(msg, style: .error) }
    }

    private func printKitchen() {
        guard !tab.items.isEmpty else { toastManager.show("Cart is empty", style: .info); return }
        let texts = buildKitchenTexts()
        guard !texts.isEmpty else { return }
        var index = 0
        func printNext() {
            guard index < texts.count else { toastManager.show("Kitchen ticket sent", style: .success); return }
            PrinterManager.print(texts[index]) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success: index += 1; printNext()
                    case .failure(let e): toastManager.show("Print failed: \(e.localizedDescription)", style: .error)
                    }
                }
            }
        }
        printNext()
    }

    private func buildKitchenTexts() -> [String] {
        guard !groupedItems.isEmpty else { return [] }
        let grouped = Dictionary(grouping: groupedItems, by: { $0.items.first?.categoryId ?? 0 })
        let sortedGroups = grouped.sorted(by: { $0.key < $1.key })
        return sortedGroups.map { group in
            var sb = ""
            sb += "KOPI HARMONI - KP\n----------------------------\n"
            sb += "Type   : \(tab.storeServiceTypesId == 3 ? "TAKE AWAY" : "DINE IN")\n"
            sb += "Cust : \(tab.customer)\n"
            if !tab.remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sb += "Note : \(tab.remark)\n" }
            sb += "\n"
            let name = tab.categories.first(where: { $0.id == group.key })?.name ?? "CATEGORY \(group.key)"
            sb += "== \(name) ==\n"
            for cg in group.value {
                sb += cg.productName + "\n"
                for i in cg.items {
                    sb += "  \(i.skuName) x \(i.quantity)\n"
                    for c in i.customizations { sb += "    - \(c.displayName)\n" }
                }
            }
            sb += "----------------------------\n"
            return sb
        }
    }
}

#Preview {
    OrderFormView(tab: OrderTab(id: 1, label: "#001"))
        .environmentObject(OrderFormViewModel())
}