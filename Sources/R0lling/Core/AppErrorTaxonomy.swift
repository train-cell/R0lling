import Foundation

/// Κεντρική ταξινόμηση σφαλμάτων εφαρμογής (A16) — permissions / disk / backup.
/// User-facing μηνύματα χωρίς secrets ή raw system paths σε logs/exports.
public enum AppErrorTaxonomy {
    public static let backupDomain = "R0lling.BackupRestore"
    public static let permissionDomain = "R0lling.Permissions"
    public static let diskDomain = "R0lling.Disk"
    public static let mediaDomain = "R0lling.Media"
    public static let metaGlassesDomain = "R0lling.Glasses.Meta"

    // Backup (A15)
    public static let backupMissingManifest = 2001
    public static let backupInvalidManifest = 2002
    public static let backupPathRejected = 2003
    public static let backupAgentRestoreFailed = 2004

    // Permissions (A16)
    public static let permissionCameraDenied = 8001
    public static let permissionMicrophoneDenied = 8002
    public static let permissionSpeechDenied = 8003
    public static let permissionPhotosDenied = 8004
    public static let permissionBluetoothDenied = 8005
    public static let permissionLocalNetworkDenied = 8006

    // Disk (A16)
    public static let diskFull = 8101
    public static let diskWriteFailed = 8102

    // Meta Wearables Hardware Safety & Compliance
    public static let metaCameraPrivacyIndicatorObscured = 8201
    public static let metaThermalThrottleExceeded = 8202
    public static let metaBatteryDepleted = 8203
    public static let metaBackgroundCaptureRestricted = 8204

    /// Δημιουργεί typed NSError χωρίς leak secrets/paths.
    public static func makeError(
        domain: String,
        code: Int,
        message: String,
        underlying: Error? = nil
    ) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let underlying {
            userInfo[NSUnderlyingErrorKey] = underlying
        }
        return NSError(domain: domain, code: code, userInfo: userInfo)
    }

    /// Μετατρέπει MediaApothikeusiError σε σταθερό domain/code για UI.
    public static func apoMediaError(_ error: MediaApothikeusiError) -> NSError {
        switch error {
        case .anepikisXoros:
            return makeError(
                domain: diskDomain,
                code: diskFull,
                message: error.localizedDescription
            )
        case .egrafiApetixe:
            return makeError(
                domain: diskDomain,
                code: diskWriteFailed,
                message: error.localizedDescription
            )
        case .kenoDedomena, .agnostosTypos, .arxeioDenVrethike, .unsafeRelativePath:
            return makeError(
                domain: mediaDomain,
                code: diskWriteFailed,
                message: error.localizedDescription
            )
        }
    }

    /// User-facing μήνυμα για οποιοδήποτε typed ή generic error.
    public static func minimaXristi(gia error: Error) -> String {
        if let media = error as? MediaApothikeusiError {
            return media.localizedDescription
        }
        let ns = error as NSError
        if ns.domain == backupDomain
            || ns.domain == permissionDomain
            || ns.domain == diskDomain
            || ns.domain == mediaDomain
            || ns.domain == metaGlassesDomain
            || AIErrorTaxonomy.isTypedAIError(error) {
            return ns.localizedDescription
        }
        return "Προέκυψε σφάλμα. Τα δεδομένα παρέμειναν ασφαλή."
    }

    /// True αν το error ανήκει σε γνωστό app domain (backup/permission/disk/media/meta).
    public static func isTypedAppError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == backupDomain
            || ns.domain == permissionDomain
            || ns.domain == diskDomain
            || ns.domain == mediaDomain
            || ns.domain == metaGlassesDomain
    }
}
