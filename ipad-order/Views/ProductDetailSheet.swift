import SwiftUI
import UIKit

// MARK: - ProductDetailPopup (compact POS dialog)
// FIX: Replaces system .sheet (900-1000pt wide) with compact centered dialog ~420pt.
// No .sheet, no .presentationDetents, no GeometryReader, no outer white background.
// Preserves: colors, fonts, SKU layout, +/- buttons, ProductImageThumb, business logic.

struct ProductDetailPopup: View {
    let product: Product
    var onClose: () -> Void

    @EnvironmentObject var formVM: OrderFormViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProductImageThumb(product: product)
                    .frame(width: 50, height: 50)
                    .background(Color.posSurfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text(product.nameValue)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: 0x221A17))
                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.posPrimary)
                Text("Select Variant")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.posPrimary)
            }

            VStack(spacing: 6) {
                let skus = product.skus ?? []
                if skus.isEmpty {
                    Text("No variants available")
                        .font(.system(size: 12))
                        .foregroundColor(.posTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(8)
                        .background(Color.posBgLight)
                        .cornerRadius(6)
                } else {
                    ForEach(skus) { sku in
                        HStack(spacing: 0) {
                            Button {
                                formVM.decrement(productId: product.id, skuId: sku.id)
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.posStatusVoid)
                                    .frame(width: 36, height: 32)
                            }
                            .buttonStyle(.plain)

                            VStack(spacing: 0) {
                                Text(sku.name ?? "")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: 0x221A17))
                                Text(CurrencyUtils.formatRp(sku.price))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.posAccent)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)

                            Button {
                                formVM.addToCart(product: product, sku: sku)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 32)
                                    .background(Color.posAccent)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.posDivider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                }
            }

            Button("Close") {
                onClose()
            }
            .buttonStyle(PosButtonStyle(filled: false))
        }
        .padding(16)
        .frame(width: min(420, UIScreen.main.bounds.width - 32))
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ProductDetailPopup(product: Product(id: 1, name: "Gula Aren", categoryId: 1, skus: [], productImage: nil), onClose: {})
        .environmentObject(OrderFormViewModel())
        .padding()
        .background(Color.black.opacity(0.45))
}
