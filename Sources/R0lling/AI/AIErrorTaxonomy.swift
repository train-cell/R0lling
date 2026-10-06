import Foundation

/// Κεντρική ταξινόμηση σφαλμάτων AI (Direct / Hermes / Router).
/// User-facing μηνύματα χωρίς raw provider body ή credentials (SEC-005).
public enum AIErrorTaxonomy {
    public static let directDomain = "R0lling.AI"
    public static let hermesDomain = "R0lling.Hermes"
    public static let keychainDomain = "R0lling.Keychain"

    // Direct
    public static let directInvalidURL = 7001
    public static let directHTTPRejected = 7002
    public static let directTransport = 7003
    public static let directEmptyKey = 7004
    public static let directInsecureEndpoint = 7005
    public static let directRetryExhausted = 7006

    // Hermes
    public static let hermesInvalidURL = 7101
    public static let hermesHTTPRejected = 7102
    public static let hermesTransport = 7103
    public static let hermesEmptyToken = 7104
    public static let hermesEndpointDenied = 7105
    public static let hermesRetryExhausted = 7106

    // Router / vision
    public static let routerDirectMissing = 7201
    public static let routerHermesMissing = 7202
    public static let routerNoVisionFrames = 7203

    /// Δημιουργεί typed NSError χωρίς leak secrets.
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

    /// Επιστρέφει true αν το error ανήκει σε γνωστό AI domain (για rethrow χωρίς wrap).
    public static func isTypedAIError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == directDomain || ns.domain == hermesDomain || ns.domain == keychainDomain
    }
}
