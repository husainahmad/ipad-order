import SwiftUI

struct OrderFormView: View {
    @EnvironmentObject var formVM: OrderFormViewModel
    @EnvironmentObject var toastManager: ToastManager
    @ObservedObject var tab: OrderTab

    @State private var selectedProduct: Product?
    @State private var showConfirm = false

    private let repository = MenuRepository()
    // 9.7" compact: 4 cols x ~125pt (180+320 side panels =500, product 524) -> same width/height, image 68x125 crop
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                categoryColumn
                productColumn
                cartColumn
            }

            // Product variant popup (420pt compact, ZStack overlay)
            if let product = selectedProduct {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                ProductDetailPopup(product: product) { selectedProduct = nil }
                    .environmentObject(formVM)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }

            // Order Confirm & Payment (920pt landscape two-column, ZStack overlay)
            if showConfirm {
                Color.black.opacity(0.45).ignoresSafeArea().transition(.opacity)
                OrderConfirmPopup(tab: tab, existingOrder: nil, onSuccess: nil) {
                    showConfirm = false
                }
                .environmentObject(formVM)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .zIndex(2)
            }
        }
        .dismissKeyboardOnTap()
        .animation(.easeOut(duration: 0.2), value: selectedProduct != nil)
        .animation(.easeOut(duration: 0.2), value: showConfirm)
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
        .frame(width: 180)
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
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<8, id: \.self) { _ in
                            SkeletonProductCard()
                        }
                    }
                    .padding(10)
                }
                .redacted(reason: .placeholder)
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
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(tab.products) { product in
                            ProductCard(product: product) {
                                handleProductTap(product)
                            }
                        }
                    }
                    .padding(10)
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
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: totalItemCount)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.posPrimaryGradient)

            serviceTypeSelector

            if tab.items.isEmpty {
                VStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.posAccentSoft).frame(width: 72, height: 72)
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 28))
                            .foregroundColor(.posAccent)
                    }
                    Text("Cart is empty")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.posTextPrimary)
                    Text("Tap a product to start ordering")
                        .font(.system(size: 13))
                        .foregroundColor(.posTextSecondary)
                    Text("Your selected items will appear here")
                        .font(.system(size: 11))
                        .foregroundColor(.posTextSecondary.opacity(0.8))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
                                    Text("\(group.items.reduce(0){$0+$1.quantity}) items")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.posTextSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.posAccentSoft)

                                ForEach(group.items) { item in
                                    CartRow(item: item,
                                            onDecrement: { withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) { formVM.decrement(productId: item.productId, skuId: item.skuId) }; UIImpactFeedbackGenerator(style: .light).impactOccurred() },
                                            onIncrement: { withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) { formVM.increment(productId: item.productId, skuId: item.skuId) }; UIImpactFeedbackGenerator(style: .light).impactOccurred() },
                                            onDelete: { withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { formVM.removeItem(productId: item.productId, skuId: item.skuId) }; UIImpactFeedbackGenerator(style: .medium).impactOccurred() })
                                }
                            }
                            .background(Color.posRowEven)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.posDivider, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(10)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: groupedItems.count)
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
                let discountVal = Double(CurrencyUtils.digitsOnly(tab.discount)) ?? 0
                if discountVal > 0 {
                    HStack {
                        Text("Discount")
                            .font(.system(size: 14))
                            .foregroundColor(.posTextSecondary)
                        Spacer()
                        Text(CurrencyUtils.formatRp(discountVal))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.posStatusVoid)
                    }
                }
                HStack {
                    Text("Total")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.posPrimary)
                    Spacer()
                    Text(CurrencyUtils.formatRp(max(0, tab.subtotal - discountVal)))
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
        .frame(width: 320)
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
                    .foregroundColor(selected ? .posAccent : .posGrayButton)
                Text(title)
                    .font(.system(size: 14, weight: selected ? .bold : .regular))
                    .foregroundColor(selected ? .posTextPrimary : .posTextSecondary)
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
            let msg = error.localizedDescription
            tab.error = msg
            toastManager.show(msg, style: .error)
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
            let msg = error.localizedDescription
            tab.error = msg
            toastManager.show(msg, style: .error)
        }
    }

    private func printKitchen() {
        guard !tab.items.isEmpty else {
            let msg = "Cart is empty"
            tab.error = msg
            toastManager.show(msg, style: .info)
            return
        }
        let text = buildKitchenText()
        PrinterManager.print(text) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    tab.error = nil
                    toastManager.show("Kitchen ticket sent", style: .success)
                case .failure(let printError):
                    let msg = "Print failed: \(printError.localizedDescription)"
                    tab.error = msg
                    toastManager.show(msg, style: .error)
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
    let onDelete: () -> Void

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
                .animation(.spring(response: 0.28, dampingFraction: 0.6), value: item.quantity)

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

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.posStatusVoid)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.001))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

struct ProductCard: View {
    let product: Product
    let action: () -> Void
    private var isSoldOut: Bool { (product.skus ?? []).isEmpty }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ZStack {
                        ProductImageThumb(product: product)
                            .frame(height: 90)
                            .frame(maxWidth: .infinity)
                            .background(Color.posSurfaceVariant)
                        if isSoldOut {
                            Color.black.opacity(0.42)
                            Text("Sold Out")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.posStatusVoid)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(height: 90)
                    .padding(.bottom, 4)

                    VStack(spacing: 4) {
                        Text(product.nameValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.posTextPrimary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 4) {
                            Text(isSoldOut ? "Unavailable" : defaultPrice)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isSoldOut ? .posTextSecondary : .posAccent)
                                .lineLimit(1)
                            Spacer()
                            // Reserve space for FAB overlap so text doesn't collide
                            Color.clear.frame(width: 30, height: 1)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 130)
                .background(Color.posSurfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerLarge))
                .overlay(
                    RoundedRectangle(cornerRadius: PosShape.cornerLarge)
                        .stroke(Color.posOutlineVariant, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                .opacity(isSoldOut ? 0.72 : 1)

                // Floating FAB - hidden when sold out
                if !isSoldOut {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.posAccent)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: Color.posAccent.opacity(0.32), radius: 6, x: 0, y: 3)
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        .padding(.top, 74) // 90 - 16 (center on image bottom edge)
                        .padding(.trailing, 8)
                }
            }
            .frame(height: 130)
            .contentShape(RoundedRectangle(cornerRadius: PosShape.cornerLarge))
        }
        .buttonStyle(.plain)
        .disabled(isSoldOut)
    }

    private var defaultPrice: String {
        let skus = product.skus ?? []
        guard let sku = skus.first(where: { ($0.name ?? "").lowercased().contains("regular") }) ?? skus.first else {
            return ""
        }
        return CurrencyUtils.formatRp(sku.price)
    }
}

struct SkeletonProductCard: View {
    @State private var shimmer = false
    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.posDivider.opacity(0.6))
                .frame(height: 90)
                .overlay(
                    LinearGradient(colors: [Color.clear, Color.white.opacity(0.55), Color.clear], startPoint: .leading, endPoint: .trailing)
                        .offset(x: shimmer ? 160 : -160)
                )
                .clipped()
                .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.7)).frame(height: 10).frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 4).fill(Color.posDivider.opacity(0.5)).frame(width: 60, height: 10)
            }
            .padding(8)
        }
        .frame(height: 130)
        .background(Color.posSurfaceContainerHigh)
        .clipShape(RoundedRectangle(cornerRadius: PosShape.cornerLarge))
        .overlay(RoundedRectangle(cornerRadius: PosShape.cornerLarge).stroke(Color.posOutlineVariant.opacity(0.5), lineWidth: 1))
        .onAppear { withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { shimmer.toggle() } }
    }
}

struct ProductImageThumb: View {
    let product: Product

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                Color.posSurfaceVariant
                if let uiImage = ProductImageCache.image(for: product) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 30))
                        .foregroundColor(Color.posAccent.opacity(0.4))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .frame(height: 90)
        .frame(maxWidth: .infinity)
        .background(Color.posSurfaceVariant)
        .clipped()
        .contentShape(Rectangle())
    }
}

#Preview {
    OrderFormView(tab: OrderTab(id: 1, label: "#001"))
        .environmentObject(OrderFormViewModel())
}
