import Foundation

/// SEC-004 / SEC-007: επικύρωση Hermes endpoint (HTTPS ή allowlisted LAN/VPN cleartext).
public enum HermesEndpointAsfaleia {
    /// Μέγιστο μήκος URL πριν το parse (DoS / paste guard).
    public static let maxURLLength: Int = 512

    /// Επικυρώνει Hermes base URL. HTTPS παντού OK· HTTP μόνο για localhost / RFC1918 / Tailscale CGNAT.
    public static func epikyroseHermesBaseURL(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxURLLength else {
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.hermesDomain,
                code: AIErrorTaxonomy.hermesInvalidURL,
                message: "Μη έγκυρη διεύθυνση URL για τον Hermes Agent στο Home PC."
            )
        }

        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.hermesDomain,
                code: AIErrorTaxonomy.hermesInvalidURL,
                message: "Μη έγκυρη διεύθυνση URL για τον Hermes Agent στο Home PC."
            )
        }

        switch scheme {
        case "https":
            return url
        case "http":
            guard let host = url.host, isAllowlistedCleartextHost(host) else {
                throw AIErrorTaxonomy.makeError(
                    domain: AIErrorTaxonomy.hermesDomain,
                    code: AIErrorTaxonomy.hermesEndpointDenied,
                    message: "Hermes cleartext HTTP επιτρέπεται μόνο σε localhost, ιδιωτικό LAN (RFC1918) ή Tailscale (100.64/10). Χρησιμοποίησε HTTPS ή VPN."
                )
            }
            return url
        default:
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.hermesDomain,
                code: AIErrorTaxonomy.hermesEndpointDenied,
                message: "Μη επιτρεπόμενο URL scheme για Hermes (μόνο https ή allowlisted http)."
            )
        }
    }

    /// Direct cloud endpoints: υποχρεωτικά HTTPS.
    public static func epikyroseDirectBaseURL(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxURLLength,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https"
        else {
            throw AIErrorTaxonomy.makeError(
                domain: AIErrorTaxonomy.directDomain,
                code: AIErrorTaxonomy.directInsecureEndpoint,
                message: "Το Direct AI Base URL πρέπει να είναι HTTPS."
            )
        }
        return url
    }

    /// Appends the API path while preserving URL query items and rejecting fragments.
    public static func chatCompletionsURL(
        fromBaseURL base: URL,
        errorDomain: String = AIErrorTaxonomy.hermesDomain,
        errorCode: Int = AIErrorTaxonomy.hermesInvalidURL
    ) throws -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false),
              components.fragment == nil else {
            throw AIErrorTaxonomy.makeError(
                domain: errorDomain,
                code: errorCode,
                message: "Αδυναμία σύνθεσης chat/completions URL."
            )
        }

        let basePath = components.percentEncodedPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.percentEncodedPath = basePath.isEmpty
            ? "/chat/completions"
            : "/\(basePath)/chat/completions"

        guard let endpoint = components.url else {
            throw AIErrorTaxonomy.makeError(
                domain: errorDomain,
                code: errorCode,
                message: "Αδυναμία σύνθεσης chat/completions URL."
            )
        }
        return endpoint
    }

    /// Host allowlist για cleartext HTTP (LAN / VPN threat model).
    public static func isAllowlistedCleartextHost(_ host: String) -> Bool {
        let h = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if h == "localhost" || h == "127.0.0.1" || h == "::1" || h.hasSuffix(".local") {
            return true
        }
        guard let octets = parseIPv4(h) else {
            // Hostname χωρίς IP (εκτός .local): cleartext απαγορεύεται.
            return false
        }
        return isRFC1918(octets) || isLinkLocal(octets) || isTailscaleCGNAT(octets)
    }

    /// SEC-009: host[:port] για user-facing errors — χωρίς credentials/query.
    public static func asfales_host_gia_log(_ url: URL) -> String {
        guard let host = url.host, !host.isEmpty else { return "(invalid-host)" }
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }

    // MARK: - Private helpers

    private static func parseIPv4(_ host: String) -> [UInt8]? {
        let parts = host.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var octets: [UInt8] = []
        for part in parts {
            guard let value = UInt8(part) else { return nil }
            octets.append(value)
        }
        return octets
    }

    private static func isRFC1918(_ o: [UInt8]) -> Bool {
        // 10.0.0.0/8
        if o[0] == 10 { return true }
        // 172.16.0.0/12
        if o[0] == 172 && (16...31).contains(o[1]) { return true }
        // 192.168.0.0/16
        if o[0] == 192 && o[1] == 168 { return true }
        return false
    }

    private static func isLinkLocal(_ o: [UInt8]) -> Bool {
        // 169.254.0.0/16
        o[0] == 169 && o[1] == 254
    }

    private static func isTailscaleCGNAT(_ o: [UInt8]) -> Bool {
        // 100.64.0.0/10 → 100.64.0.0 – 100.127.255.255
        o[0] == 100 && (64...127).contains(o[1])
    }
}
