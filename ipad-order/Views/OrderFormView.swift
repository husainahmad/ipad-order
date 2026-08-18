import SwiftUI

struct OrderFormView: View {
    @EnvironmentObject var formVM: OrderFormViewModel
    @ObservedObject var tab: OrderTab

    @State private var selectedProduct: Product?
    @State private var showConfirm = false

    private let repository = MenuRepository()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        HStack(spacing: 0) {
            categoryColumn
            productColumn
            cartColumn
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailSheet(product: product)
        }
        .sheet(isPresented: $showConfirm) {
            OrderConfirmSheet(tab: tab)
        }
        .task {
            await loadCategories()
        }
    }

    // MARK: - Category column (12%)

    private var categoryColumn: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.posPrimary)
                Text("Category")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.posTextPrimary)
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
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 14)
                            .background(tab.selectedCategoryId == category.id ? AnyShapeStyle(Color.posPrimaryGradient) : AnyShapeStyle(Color.posSurfaceContainerHigh))
                            .overlay(
                                RoundedRectangle(cornerRadius: PosShape.cornerMedium)
                                    .stroke(tab.selectedCategoryId == category.id ? Color.clear : Color.posOutlineVariant, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
                            .shadow(color: tab.selectedCategoryId == category.id ? Color.posPrimary.opacity(0.28) : Color.clear,
                                    radius: 6, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
        }
        .padding(12)
        .background(Color.posBgLight)
        .frame(width: 210)
    }

    // MARK: - Product column (53%)

    private var productColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.posAccent)
                    .frame(width: 4, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCategoryName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.posTextPrimary)
                    Text("\(tab.products.count) items")
                        .font(.system(size: 12))
                        .foregroundColor(.posTextSecondary)
                }
                Spacer()
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.posAccent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.posSurfaceContainer)
            .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)

            if tab.loadingProducts {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = tab.error, !error.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.posStatusVoid)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.posStatusVoid)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(tab.products) { product in
                            ProductCard(product: product) {
                                handleProductTap(product)
                            }
                        }
                    }
                    .padding(14)
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

    // MARK: - Cart column (35%)

    private var cartColumn: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 15))
                Text("Order Summary")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                if !tab.items.isEmpty {
                    Text("\(totalItemCount)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.posPrimaryDark)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Circle())
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.posPrimaryGradient)

            serviceTypeSelector

            if tab.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 44))
                        .foregroundColor(.posDivider)
                    Text("Cart is empty")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.posTextPrimary)
                    Text("Tap a product to start")
                        .font(.system(size: 13))
                        .foregroundColor(.posTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(groupedItems, id: \.productId) { group in
                            VStack(spacing: 0) {
                                HStack(spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(.posAccent)
                                    Text(group.productName)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.posTextPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.posAccentSoft)

                                ForEach(group.items) { item in
                                    CartRow(item: item,
                                            onDecrement: { formVM.decrement(productId: item.productId, skuId: item.skuId) },
                                            onIncrement: { formVM.increment(productId: item.productId, skuId: item.skuId) })
                                }
                            }
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.posDivider, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(10)
                }
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Sub Total")
                        .font(.system(size: 14))
                        .foregroundColor(.posTextSecondary)
                    Spacer()
                    Text(CurrencyUtils.formatRp(tab.subtotal))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.posTextPrimary)
                }
                HStack {
                    Text("Total")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.posPrimary)
                    Spacer()
                    Text(CurrencyUtils.formatRp(tab.subtotal))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.posPrimary)
                }
                HStack(spacing: 8) {
                    Button("Confirm") {
                        showConfirm = true
                    }
                    .buttonStyle(PosButtonStyle(filled: true))

                    Button("Print") {
                        printKitchen()
                    }
                    .buttonStyle(PosButtonStyle(filled: false, outlineColor: .posBlueAction))
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color.white)
            .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .top)
        }
        .background(Color.posBgLight)
        .frame(width: 360)
    }

    private var totalItemCount: Int {
        tab.items.reduce(0) { $0 + $1.quantity }
    }

    private var serviceTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Type")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.posTextSecondary)
            HStack(spacing: 8) {
                serviceTypeCard(title: "DINE IN", icon: "fork.knife", id: 1)
                serviceTypeCard(title: "TAKE AWAY", icon: "takeoutbag.and.cup.and.straw", id: 3)
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().fill(Color.posDivider).frame(height: 1), alignment: .bottom)
    }

    private func serviceTypeCard(title: String, icon: String, id: Int) -> some View {
        let selected = tab.storeServiceTypesId == id
        return Button {
            formVM.setStoreServiceType(id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(selected ? .posPrimaryDark : .posGrayButton)
                Text(title)
                    .font(.system(size: 14, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? .posPrimaryDark : .posTextSecondary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.posAccent)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? Color.posAccentSoft : Color.posBgLight)
            .overlay(
                RoundedRectangle(cornerRadius: PosShape.cornerMedium)
                    .stroke(selected ? Color.posAccent : Color.posDivider, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerMedium))
        }
        .buttonStyle(.plain)
    }

    private var groupedItems: [CartGroup] {
        var groups: [Int: CartGroup] = [:]
        for item in tab.items {
            if var group = groups[item.productId] {
                group.items.append(item)
                groups[item.productId] = group
            } else {
                groups[item.productId] = CartGroup(productId: item.productId,
                                                   productName: item.productName,
                                                   items: [item])
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
            if tab.selectedCategoryId == nil, let first = tab.categories.first {
                selectCategory(first)
            }
        } catch {
            tab.error = error.localizedDescription
        }
    }

    private func selectCategory(_ category: Category) {
        tab.selectedCategoryId = category.id
        Task { await loadProducts(categoryId: category.id) }
    }

    private func handleProductTap(_ product: Product) {
        let skus = product.skus ?? []
        if skus.count == 1, let sku = skus.first {
            formVM.addToCart(product: product, sku: sku)
        } else {
            selectedProduct = product
        }
    }

    private func loadProducts(categoryId: Int) async {
        tab.loadingProducts = true
        defer { tab.loadingProducts = false }
        do {
            tab.products = try await repository.getProducts(categoryId: categoryId)
        } catch {
            tab.error = error.localizedDescription
        }
    }

    private func printKitchen() {
        guard !tab.items.isEmpty else {
            tab.error = "Cart is empty"
            return
        }
        let text = buildKitchenText()
        PrinterManager.print(text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    tab.error = nil
                case .failure(let printError):
                    tab.error = "Print failed: \(printError.localizedDescription)"
                }
            }
        }
    }

    private func buildKitchenText() -> String {
        var sb = ""
        sb += "KOPI HARMONI - KP\n"
        sb += "----------------------------\n"
        sb += "Type   : \(tab.storeServiceTypesId == 3 ? "TAKE AWAY" : "DINE IN")\n"
        sb += "Cust : \(tab.customer)\n\n"
        for group in groupedItems {
            sb += group.productName + "\n"
            for item in group.items {
                sb += "  \(item.skuName) x \(item.quantity)\n"
            }
        }
        sb += "----------------------------\n"
        return sb
    }
}

private struct CartGroup {
    let productId: Int
    let productName: String
    var items: [CartItem]
}

private struct CartRow: View {
    let item: CartItem
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(item.skuName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.posTextPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDecrement) {
                Image(systemName: "minus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.posStatusVoid)
                    .frame(width: 30, height: 30)
                    .background(Color.posStatusVoid.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("\(item.quantity)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.posTextPrimary)
                .frame(width: 30)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.posAccent)
                    .clipShape(Circle())
                    .shadow(color: Color.posAccent.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Text(CurrencyUtils.formatRp(item.lineTotal))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.posTextPrimary)
                .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct ProductCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ProductImageThumb(product: product)
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .background(Color.posSurfaceVariant)

                VStack(spacing: 5) {
                    Text(product.nameValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.posTextPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        Text(defaultPrice)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.posAccent)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.posPrimary)
                    }
                }
                .padding(10)
            }
            .background(Color.posSurfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerLarge))
            .overlay(
                RoundedRectangle(cornerRadius: PosShape.cornerLarge)
                    .stroke(Color.posOutlineVariant, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var defaultPrice: String {
        let skus = product.skus ?? []
        guard let sku = skus.first(where: { ($0.name ?? "").lowercased().contains("regular") }) ?? skus.first else {
            return ""
        }
        return CurrencyUtils.formatRp(sku.price)
    }
}

struct ProductImageThumb: View {
    let product: Product

    var body: some View {
        if let uiImage = ProductImageCache.image(for: product) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            ZStack {
                Color.posSurfaceVariant
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 34))
                    .foregroundColor(Color.posAccent.opacity(0.4))
            }
        }
    }
}

#Preview {
    OrderFormView(tab: OrderTab(id: 1, label: "#001"))
        .environmentObject(OrderFormViewModel())
}
