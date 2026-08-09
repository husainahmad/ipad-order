import Foundation
import UIKit

enum ProductImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(for product: Product) -> UIImage? {
        let blob = product.productImage?.imageBlobValue ?? ""
        guard !blob.isEmpty else { return nil }

        let key = key(for: product)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let data = Data(base64Encoded: sanitize(blob)) else { return nil }
        guard let image = UIImage(data: data) else { return nil }

        cache.setObject(image, forKey: key)
        return image
    }

    private static func sanitize(_ base64: String) -> String {
        var cleaned = base64
        if let commaRange = cleaned.range(of: ",") {
            cleaned = String(cleaned[commaRange.upperBound...])
        }
        return cleaned.replacingOccurrences(of: "\\s", with: "", options: .regularExpression)
    }

    private static func key(for product: Product) -> NSString {
        let fileName = product.productImage?.fileName ?? ""
        if !fileName.isEmpty {
            return fileName as NSString
        }
        if let id = product.productImage?.id {
            return "\(id)" as NSString
        }
        return (product.productImage?.imageBlobValue ?? "") as NSString
    }
}
