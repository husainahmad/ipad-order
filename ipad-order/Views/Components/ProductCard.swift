import SwiftUI

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
                        .padding(.top, 74)
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
    @State private var uiImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                Color.posSurfaceVariant
                if let uiImage {
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
        // The image is a hosted URL, so it is fetched off the main thread and cached
        // by URL. Keying the task on the product id reloads when the cell is reused
        // for a different product.
        .task(id: product.id) {
            uiImage = await ProductImageCache.image(for: product)
        }
    }
}