import Foundation

/// Uses iOS Data Protection for ordinary journal and media files.
/// This is OS-managed encryption at rest, not app-level encryption or biometric access control.
enum R0llingFileProtection {
    static let atomicWriteOptions: Data.WritingOptions = {
        #if os(iOS)
        return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        return [.atomic]
        #endif
    }()

    static func apply(to url: URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
    }
}
