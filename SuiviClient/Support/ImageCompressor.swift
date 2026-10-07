import UIKit

/// Réduit une photo avant envoi sur Drive (moins de données mobiles, upload plus rapide).
enum ImageCompressor {
    static func compress(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
