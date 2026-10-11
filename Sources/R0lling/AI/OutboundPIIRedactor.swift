import Foundation

/// Local, deterministic scrubbing for common identifiers in provider-bound text.
/// This does not inspect image pixels or infer names and free-form addresses.
public enum OutboundPIIRedactor {
    private static let emailPattern =
        #"(?<![\p{L}\p{N}._%+-])[\p{L}\p{N}._%+-]+@[\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)+(?![\p{L}\p{N}.-])"#
    private static let ibanPattern = #"(?<![A-Z0-9])[A-Z]{2}\d{2}(?: ?[A-Z0-9]{4}){2,7}(?: ?[A-Z0-9]{1,4})(?![A-Z0-9])"#
    private static let paymentCardPattern = #"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)"#
    private static let usSocialSecurityPattern = #"(?<!\d)\d{3}[- ]\d{2}[- ]\d{4}(?!\d)"#
    private static let greekTaxIDPattern =
        #"(?<![\p{L}])(?:ΑΦΜ|AFM|tax(?:payer)?\s*ID)\s*[:#]?\s*\d(?:[ -]?\d){8}(?!\d)"#
    private static let internationalPhonePattern =
        #"(?<![\p{L}\p{N}])(?:\+\s?\d{1,3}|00\s?\d{1,3})(?:[\s().-]*\d){7,12}(?!\d)"#
    private static let greekPhonePattern = #"(?<!\d)(?:2\d{9}|69\d{8})(?!\d)"#
    private static let groupedPhonePattern =
        #"(?<![\p{L}\p{N}])(?<!\d[ .-])(?:\d{2,4}|\(\d{2,4}\))[ .-]+\d{2,4}[ .-]+\d{3,4}(?![\p{L}\p{N}])(?![ .-]+\d)"#

    private static let replacement = "[REDACTED]"

    /// Redacts common email, checksum-valid IBAN/card, SSN, Greek AFM, and phone patterns from free text.
    public static func redact(_ text: String) -> String {
        var result = replacingMatches(in: text, pattern: emailPattern)
        result = replacingMatches(in: result, pattern: ibanPattern, shouldReplace: passesIBANChecksum)
        result = replacingMatches(
            in: result,
            pattern: paymentCardPattern,
            shouldReplace: passesLuhn
        )
        result = replacingMatches(in: result, pattern: usSocialSecurityPattern)
        result = replacingMatches(in: result, pattern: greekTaxIDPattern)
        result = replacingMatches(in: result, pattern: internationalPhonePattern)
        result = replacingMatches(in: result, pattern: greekPhonePattern)
        result = replacingMatches(in: result, pattern: groupedPhonePattern)
        return result
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        shouldReplace: ((String) -> Bool)? = nil
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let source = text as NSString
        let matches = expression.matches(
            in: text,
            range: NSRange(location: 0, length: source.length)
        )
        var result = text
        for match in matches.reversed() {
            let candidate = source.substring(with: match.range)
            guard shouldReplace?(candidate) ?? true,
                  let range = Range(match.range, in: result) else {
                continue
            }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    private static func passesLuhn(_ candidate: String) -> Bool {
        let digits = candidate.filter(\.isNumber).compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else { return false }

        let checksum = digits.reversed().enumerated().reduce(into: 0) { total, item in
            var digit = item.element
            if item.offset.isMultiple(of: 2) == false {
                digit *= 2
                if digit > 9 { digit -= 9 }
            }
            total += digit
        }
        return checksum.isMultiple(of: 10)
    }

    private static func passesIBANChecksum(_ candidate: String) -> Bool {
        var normalized: [UInt8] = []
        normalized.reserveCapacity(candidate.utf8.count)
        for byte in candidate.uppercased().utf8 {
            if byte == 0x20 { continue }
            guard (48...57).contains(byte) || (65...90).contains(byte) else { return false }
            normalized.append(byte)
        }

        guard (15...34).contains(normalized.count),
              normalized[0...1].allSatisfy({ (65...90).contains($0) }),
              normalized[2...3].allSatisfy({ (48...57).contains($0) }) else {
            return false
        }

        let rearranged = Array(normalized.dropFirst(4)) + Array(normalized.prefix(4))
        var remainder = 0
        for byte in rearranged {
            if (48...57).contains(byte) {
                remainder = (remainder * 10 + Int(byte - 48)) % 97
            } else {
                let value = Int(byte - 65) + 10
                remainder = (remainder * 100 + value) % 97
            }
        }
        return remainder == 1
    }
}
