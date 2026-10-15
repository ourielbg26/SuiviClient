import UIKit
import ImageIO

/// Réduit une photo avant envoi sur Drive (moins de données mobiles, upload plus rapide).
enum ImageCompressor {
    static func compress(_ data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.7) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Échelle 1 : sinon le dessin se fait à la densité de l'écran (×3 sur iPhone) et la
        // photo "réduite" à 1600 px sort en fait à 4800 px.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: quality) ?? data
    }

    /// Image réduite pour l'affichage, décodée directement à la bonne taille : une grande
    /// photo (ex. 3600 × 4800) n'est jamais chargée en entier en mémoire.
    static func displayImage(from data: Data, maxPixelSize: CGFloat = 1400) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
