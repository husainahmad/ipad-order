import Foundation
import UIKit

/// Loads and caches product images from the hosted URL the menu service returns.
///
/// The catalogue no longer ships image bytes: an upload goes to ImgBB and only the
/// resulting link comes back on the product. So an image is a download, not a
/// base64 decode, and it is cached by URL so a grid of products that share a link
/// only fetches it once.
enum ProductImageCache {
    private static let cache = NSCache<NSURL, UIImage>()

    /// The hosted URL for a product's image, or `nil` when it has none or the link
    /// is not a usable URL.
    static func url(for product: Product) -> URL? {
        let raw = product.productImage?.urlValue
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let url = URL(string: raw) else { return nil }
        return url
    }

    /// The product's image, loaded from its URL on first call and served from the
    /// cache afterwards. Returns `nil` when there is no image, or the download or
    /// decode fails, so callers fall back to their placeholder.
    static func image(for product: Product) async -> UIImage? {
        guard let url = url(for: product) else { return nil }
        if let cached = cache.object(forKey: url as NSURL) { return cached }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            return nil
        }
    }
}
