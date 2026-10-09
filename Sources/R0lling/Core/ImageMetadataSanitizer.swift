import Foundation
import ImageIO

/// Decodes and re-encodes one image while omitting source metadata except orientation.
enum ImageMetadataSanitizer {
    static let maximumVisionInputBytes = 40 * 1024 * 1024
    static let maximumVisionOutputBytes = 8 * 1024 * 1024
    static let maximumVisionPixelDimension = 2_048

    /// Preserves the source format, or normalizes it to the requested wire format.
    static func encode(_ data: Data, outputType: CFString? = nil) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let sourceType = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw failure(1, "Μη υποστηριζόμενη ή μη έγκυρη εικόνα.")
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, outputType ?? sourceType, 1, nil
        ) else { throw failure(2, "Μη υποστηριζόμενος τύπος εξόδου εικόνας.") }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        var retained: [String: Any] = [:]
        if let orientation = properties?[kCGImagePropertyOrientation as String] {
            retained[kCGImagePropertyOrientation as String] = orientation
        }
        CGImageDestinationAddImage(destination, image, retained as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw failure(3, "Αποτυχία εγγραφής εικόνας χωρίς metadata.")
        }
        return output as Data
    }

    /// Creates a bounded, metadata-free JPEG for OCR/vision requests without fully decoding
    /// a potentially huge source image. The source byte limit is checked before ImageIO work.
    static func encodeForVision(_ data: Data) throws -> Data {
        guard !data.isEmpty, data.count <= maximumVisionInputBytes else {
            throw failure(4, "Η εικόνα είναι κενή ή υπερβαίνει το όριο των 40 MB.")
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1 else {
            throw failure(1, "Μη υποστηριζόμενη ή μη έγκυρη εικόνα.")
        }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumVisionPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw failure(1, "Μη υποστηριζόμενη ή μη έγκυρη εικόνα.")
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData, "public.jpeg" as CFString, 1, nil
        ) else {
            throw failure(2, "Μη υποστηριζόμενος τύπος εξόδου εικόνας.")
        }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length <= maximumVisionOutputBytes else {
            throw failure(5, "Η επεξεργασμένη εικόνα υπερβαίνει το όριο αποστολής.")
        }
        return output as Data
    }

    /// Provides a non-sensitive failure message to image consumers.
    private static func failure(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "R0lling.Image", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
