import SwiftUI

// MARK: - Preference to measure content height

private struct SheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Reusable adaptive bottom sheet container
// - Dynamically adjusts height via .presentationDetents
// - Landscape-aware (uses screen proportions, not fixed widths)
// - Single surface: no nested border artifact (sheet background IS card)

struct PosSheet<Content: View>: View {
    let content: Content
    @State private var detentHeight: CGFloat = 300

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let maxH = maxAllowedHeight(screenHeight: proxy.size.height)

            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(key: SheetHeightKey.self, value: inner.size.height)
                        }
                    )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            .frame(maxHeight: maxH, alignment: .top)
            .onPreferenceChange(SheetHeightKey.self) { h in
                // 32 = vertical padding + safe margin, clamp to 28%...85% of screen
                let screenH = UIScreen.main.bounds.height
                let minH = screenH * 0.28
                let maxOuter = screenH * 0.85
                let ideal = h + 16 // inner padding
                let clamped = min(max(ideal, minH), maxOuter)
                // avoid jitter: only update when delta > 4pt
                if abs(clamped - detentHeight) > 4 {
                    detentHeight = clamped
                }
            }
        }
        .background(Color.clear)
        .posSheetDetent(height: detentHeight)
    }

    private func maxAllowedHeight(screenHeight: CGFloat) -> CGFloat {
        // Landscape: height is the constraining dimension; use 85% of physical screen height
        // No hardcoded width; height only adapts.
        UIScreen.main.bounds.height * 0.85
    }
}

// MARK: - View modifiers (avoid availability duplication)

private extension View {
    @ViewBuilder
    func posSheetDetent(height: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            // Single detent = exact content height. No .medium/.large stepping.
            self.presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadiusCompat(16)
                .presentationBackgroundCompat()
        } else {
            self
        }
    }

    @ViewBuilder
    func presentationCornerRadiusCompat(_ radius: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationCornerRadius(radius)
        } else {
            self
        }
    }

    @ViewBuilder
    func presentationBackgroundCompat() -> some View {
        if #available(iOS 16.4, *) {
            // Sheet chrome transparent so PosSheet's single white card is the visible surface
            // Avoids cream-outer + white-inner double border artifact
            self.presentationBackground(Color.clear)
        } else {
            self
        }
    }
}

// MARK: - Convenience sheet builder (iPad + iPhone)

extension View {
    /// Present `content` in a PosSheet modal with dynamic height.
    func posBottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            PosSheet(content: content)
        }
    }

    func posBottomSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        self.sheet(item: item) { item in
            PosSheet { content(item) }
        }
    }
}

// MARK: - Example (refactor ProductDetailSheet to use it)
/*
 In ProductDetailSheet.swift:

 struct ProductDetailSheetContent: View {
   let product: Product
   var body: some View {
     VStack(alignment: .leading, spacing: 10) {
       HStack { ProductImageThumb(product: product).frame(width:50,height:50)...; Text(product.nameValue)... }
       HStack { Image(...); Text("Select Variant") }
       ForEach(product.skus ?? []) { sku in VariantRow(...) }
       Button("Close") { dismiss() }.buttonStyle(PosButtonStyle(filled:false))
     }
   }
 }

 // presenter:
 .posBottomSheet(item: $selectedProduct) { product in
   ProductDetailSheetContent(product: product).environmentObject(formVM)
 }

 Result on 9.7" landscape (iOS 16.7): sheet is centered, height = content + 16, no 420 fixed width, no cream outer padding.
 On iPhone portrait: same component becomes bottom sheet with drag indicator, height = content, max 85% screen, scrollable if overflow.
 */

#Preview {
    Color.posBgLight.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            PosSheet {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.posSurfaceVariant).frame(width: 50, height: 50)
                        Text("Gula Aren").font(.system(size: 16, weight: .bold))
                    }
                    Text("Select Variant").font(.system(size: 15, weight: .bold)).foregroundColor(.posPrimary)
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12).fill(Color.white).frame(height: 36).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.posDivider))
                    }
                    Button("Close") {}.buttonStyle(PosButtonStyle(filled: false))
                }
            }
        }
}
