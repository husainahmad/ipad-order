import SwiftUI

struct ProductDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var formVM: OrderFormViewModel
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    ProductImageThumb(product: product)
                        .frame(width: 80, height: 80)
                        .background(Color.posSurfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(product.nameValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.posTextPrimary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.posPrimary)
                    Text("Select Variant")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.posPrimary)
                }

                VStack(spacing: 8) {
                    let skus = product.skus ?? []
                    if skus.isEmpty {
                        Text("No variants available")
                            .font(.system(size: 14))
                            .foregroundColor(.posTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(12)
                            .background(Color.posBgLight)
                            .cornerRadius(6)
                    } else {
                        ForEach(skus) { sku in
                            HStack(spacing: 0) {
                                Button {
                                    formVM.decrement(productId: product.id, skuId: sku.id)
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.posStatusVoid)
                                        .frame(width: 52, height: 48)
                                }
                                .buttonStyle(.plain)

                                VStack(spacing: 2) {
                                    Text(sku.name ?? "")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.posTextPrimary)
                                    Text(CurrencyUtils.formatRp(sku.price))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.posAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)

                                Button {
                                    formVM.addToCart(product: product, sku: sku)
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 52, height: 48)
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
                    dismiss()
                }
                .buttonStyle(PosButtonStyle(filled: false))
            }
            .padding(20)
        }
        .sheetHeight(dynamicHeight)
    }

    private var dynamicHeight: CGFloat {
        let skuCount = product.skus?.count ?? 0
        let contentHeight = 132 + CGFloat(skuCount) * 56 + 90
        return min(max(contentHeight, 330), 620)
    }
}

private extension View {
    @ViewBuilder
    func sheetHeight(_ height: CGFloat) -> some View {
        if #available(iOS 16.4, *) {
            self.presentationDetents([.height(height)])
                .presentationCornerRadius(16)
        } else if #available(iOS 16.0, *) {
            self.presentationDetents([.height(height)])
        } else {
            self
        }
    }
}

#Preview {
    ProductDetailSheet(product: Product(id: 1, name: "Kopi", categoryId: 1, skus: [], productImage: nil))
        .environmentObject(OrderFormViewModel())
}
