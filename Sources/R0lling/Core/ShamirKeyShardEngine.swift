import Foundation

#if canImport(CryptoKit)
import CryptoKit
#elseif canImport(Crypto)
import Crypto
#endif

#if canImport(Security)
import Security
#endif

public enum ShamirKeyShardError: Error, LocalizedError, Sendable {
    case emptySecret
    case secretTooLarge
    case insufficientShares
    case tooManyShares
    case malformedShare
    case unsupportedVersion
    case unsupportedAlgorithm
    case invalidShareMetadata
    case duplicateShare
    case mixedShareSets
    case inconsistentShares
    case integrityCheckFailed
    case invalidUTF8
    case secureRandomUnavailable
    case secureRandomFailed
    case cryptographyUnavailable

    public var errorDescription: String? {
        switch self {
        case .emptySecret:
            "Το μυστικό δεν μπορεί να είναι κενό."
        case .secretTooLarge:
            "Το μυστικό ξεπερνά το όριο του 1 MiB."
        case .insufficientShares:
            "Χρειάζονται τουλάχιστον δύο έγκυρα shards από το ίδιο σετ."
        case .tooManyShares:
            "Ένα σετ περιέχει έως τρία shards."
        case .malformedShare:
            "Το shard δεν έχει έγκυρη ή κανονική μορφή."
        case .unsupportedVersion:
            "Η έκδοση του shard δεν υποστηρίζεται."
        case .unsupportedAlgorithm:
            "Ο αλγόριθμος του shard δεν υποστηρίζεται."
        case .invalidShareMetadata:
            "Τα μεταδεδομένα του shard δεν είναι έγκυρα."
        case .duplicateShare:
            "Το σετ περιέχει διπλό shard."
        case .mixedShareSets:
            "Τα shards δεν ανήκουν στο ίδιο σετ."
        case .inconsistentShares:
            "Τα shards δεν ανήκουν στο ίδιο πολυώνυμο."
        case .integrityCheckFailed:
            "Ο έλεγχος ακεραιότητας των shards απέτυχε."
        case .invalidUTF8:
            "Τα ανακτημένα bytes δεν είναι έγκυρο UTF-8."
        case .secureRandomUnavailable:
            "Δεν υπάρχει ασφαλής γεννήτρια τυχαίων bytes σε αυτή την πλατφόρμα."
        case .secureRandomFailed:
            "Η ασφαλής δημιουργία τυχαίων bytes απέτυχε."
        case .cryptographyUnavailable:
            "Η κρυπτογραφική υποστήριξη δεν είναι διαθέσιμη σε αυτή την πλατφόρμα."
        }
    }
}

/// Two-of-three Shamir secret sharing over GF(256), with authenticated share envelopes.
/// This engine does not persist or export shares and does not promise memory zeroization.
public actor ShamirKeyShardEngine {
    public static let threshold = 2
    public static let totalShares = 3
    public static let maximumSecretBytes = 1_048_576

    private let randomByteProvider: ShamirSecretSharing.RandomByteProvider

    public init() {
        self.randomByteProvider = { count in
            try ShamirSecretSharing.secureRandomBytes(count: count)
        }
    }

    /// Internal deterministic source is available to the test target through `@testable import`.
    init(randomByteProvider: @escaping ShamirSecretSharing.RandomByteProvider) {
        self.randomByteProvider = randomByteProvider
    }

    /// Splits the exact UTF-8 bytes into three independently encoded shares; any two recover it.
    public func splitSecretIntoQuorum(
        secret: String
    ) throws -> (shardA: String, shardB: String, shardC: String) {
        let secretByteCount = secret.utf8.count
        guard secretByteCount > 0 else { throw ShamirKeyShardError.emptySecret }
        guard secretByteCount <= Self.maximumSecretBytes else {
            throw ShamirKeyShardError.secretTooLarge
        }
        return try ShamirSecretSharing.split(
            secretBytes: Data(secret.utf8),
            randomByteProvider: randomByteProvider
        )
    }

    /// Reconstructs a secret from two or three valid shares from one set.
    public func reconstructSecret(from shards: [String]) throws -> String {
        try ShamirSecretSharing.reconstructSecret(from: shards)
    }

    /// Returns true only when the supplied 2–3 distinct shares authenticate and agree.
    public func verifyQuorum(shards: [String]) -> Bool {
        do {
            _ = try ShamirSecretSharing.reconstructSecret(from: shards)
            return true
        } catch {
            return false
        }
    }
}

enum ShamirSecretSharing {
    typealias RandomByteProvider = @Sendable (Int) throws -> Data

    static let secretLimit = ShamirKeyShardEngine.maximumSecretBytes
    static let validationKeyLength = 32
    static let setIdentifierLength = 16
    static let authenticationTagLength = 32
    static let headerLength = 29
    static let textPrefix = "r0ss1."
    private static let magic: [UInt8] = [0x52, 0x30, 0x53, 0x53] // R0SS
    private static let version: UInt8 = 1
    private static let algorithmAESField: UInt8 = 1 // GF(2^8), x^8+x^4+x^3+x+1 (0x11B)
    private static let authenticationDomain = Data("R0lling/ShamirKeyShard/v1\0".utf8)

    struct Share: Sendable {
        let coordinate: UInt8
        let setIdentifier: Data
        let secretLength: Int
        let payload: Data
        let unsignedEnvelope: Data
        let authenticationTag: Data
    }

    static func split(
        secretBytes: Data,
        randomByteProvider: RandomByteProvider
    ) throws -> (shardA: String, shardB: String, shardC: String) {
        guard !secretBytes.isEmpty else { throw ShamirKeyShardError.emptySecret }
        guard secretBytes.count <= secretLimit else { throw ShamirKeyShardError.secretTooLarge }

        let setIdentifier = try secureRandomBytes(count: setIdentifierLength, using: randomByteProvider)
        let validationKey = try secureRandomBytes(count: validationKeyLength, using: randomByteProvider)
        var protectedPayload = secretBytes
        protectedPayload.append(validationKey)
        let slopes = try secureRandomBytes(count: protectedPayload.count, using: randomByteProvider)

        var payloads = [Data](repeating: Data(), count: ShamirKeyShardEngine.totalShares)
        for index in payloads.indices {
            payloads[index].reserveCapacity(protectedPayload.count)
        }

        for byteIndex in 0..<protectedPayload.count {
            let secretByte = protectedPayload[byteIndex]
            let slope = slopes[byteIndex]
            for shareIndex in 0..<ShamirKeyShardEngine.totalShares {
                let coordinate = UInt8(shareIndex + 1)
                payloads[shareIndex].append(secretByte ^ gfMultiply(slope, coordinate))
            }
        }

        let encodedShares = try payloads.enumerated().map { index, payload in
            try encodeShare(
                coordinate: UInt8(index + 1),
                setIdentifier: setIdentifier,
                secretLength: secretBytes.count,
                payload: payload,
                validationKey: validationKey
            )
        }
        return (encodedShares[0], encodedShares[1], encodedShares[2])
    }

    static func reconstructSecret(from rawShares: [String]) throws -> String {
        guard rawShares.count >= ShamirKeyShardEngine.threshold else {
            throw ShamirKeyShardError.insufficientShares
        }
        guard rawShares.count <= ShamirKeyShardEngine.totalShares else {
            throw ShamirKeyShardError.tooManyShares
        }

        let shares = try rawShares.map(decodeShare)
        guard let first = shares.first else { throw ShamirKeyShardError.insufficientShares }
        var seenCoordinates = Set<UInt8>()
        for share in shares {
            guard seenCoordinates.insert(share.coordinate).inserted else {
                throw ShamirKeyShardError.duplicateShare
            }
            guard share.setIdentifier == first.setIdentifier,
                  share.secretLength == first.secretLength else {
                throw ShamirKeyShardError.mixedShareSets
            }
        }

        let ordered = shares.sorted { $0.coordinate < $1.coordinate }
        let basisShares = Array(ordered.prefix(ShamirKeyShardEngine.threshold))
        if ordered.count == ShamirKeyShardEngine.totalShares {
            try validateThirdShare(ordered[0], ordered[1], ordered[2])
        }

        let protectedPayload = try interpolateAtZero(basisShares)
        let secretBytes = Data(protectedPayload.prefix(first.secretLength))
        let validationKey = Data(protectedPayload.suffix(validationKeyLength))
        for share in ordered {
            guard isValidAuthenticationTag(
                share.authenticationTag,
                message: authenticationMessage(for: share.unsignedEnvelope),
                key: validationKey
            ) else {
                throw ShamirKeyShardError.integrityCheckFailed
            }
        }

        guard let secret = String(data: secretBytes, encoding: .utf8) else {
            throw ShamirKeyShardError.invalidUTF8
        }
        return secret
    }

    static func gfMultiply(_ lhs: UInt8, _ rhs: UInt8) -> UInt8 {
        var multiplicand = lhs
        var multiplier = rhs
        var product: UInt8 = 0
        for _ in 0..<8 {
            let addMask = UInt8(0) &- (multiplier & 1)
            product ^= multiplicand & addMask
            let highBitMask = UInt8(0) &- (multiplicand >> 7)
            multiplicand = (multiplicand << 1) ^ (0x1B & highBitMask)
            multiplier >>= 1
        }
        return product
    }

    static func gfInverse(_ value: UInt8) -> UInt8 {
        // All interpolation denominators are distinct nonzero coordinates.
        var exponent = 254
        var base = value
        var result: UInt8 = 1
        while exponent > 0 {
            if exponent & 1 == 1 { result = gfMultiply(result, base) }
            base = gfMultiply(base, base)
            exponent >>= 1
        }
        return result
    }

    static func interpolateAtZero(_ shares: [Share]) throws -> Data {
        guard shares.count == ShamirKeyShardEngine.threshold,
              shares[0].payload.count == shares[1].payload.count else {
            throw ShamirKeyShardError.invalidShareMetadata
        }
        let first = shares[0]
        let second = shares[1]
        let denominator = first.coordinate ^ second.coordinate
        guard denominator != 0 else { throw ShamirKeyShardError.duplicateShare }
        let firstWeight = gfMultiply(second.coordinate, gfInverse(denominator))
        let secondWeight = gfMultiply(first.coordinate, gfInverse(denominator))

        var output = Data(count: first.payload.count)
        for index in 0..<output.count {
            output[index] = gfMultiply(first.payload[index], firstWeight)
                ^ gfMultiply(second.payload[index], secondWeight)
        }
        return output
    }

    private static func validateThirdShare(_ first: Share, _ second: Share, _ third: Share) throws {
        guard first.payload.count == second.payload.count,
              second.payload.count == third.payload.count else {
            throw ShamirKeyShardError.invalidShareMetadata
        }
        let coordinateDifference = first.coordinate ^ second.coordinate
        guard coordinateDifference != 0 else { throw ShamirKeyShardError.duplicateShare }
        let inverseDifference = gfInverse(coordinateDifference)
        for index in 0..<first.payload.count {
            let slope = gfMultiply(
                first.payload[index] ^ second.payload[index],
                inverseDifference
            )
            let expected = first.payload[index]
                ^ gfMultiply(slope, third.coordinate ^ first.coordinate)
            guard expected == third.payload[index] else {
                throw ShamirKeyShardError.inconsistentShares
            }
        }
    }

    private static func encodeShare(
        coordinate: UInt8,
        setIdentifier: Data,
        secretLength: Int,
        payload: Data,
        validationKey: Data
    ) throws -> String {
        guard setIdentifier.count == setIdentifierLength,
              validationKey.count == validationKeyLength,
              secretLength > 0, secretLength <= secretLimit,
              payload.count == secretLength + validationKeyLength,
              (1...ShamirKeyShardEngine.totalShares).contains(Int(coordinate)) else {
            throw ShamirKeyShardError.invalidShareMetadata
        }
        var envelope = Data(magic)
        envelope.append(version)
        envelope.append(algorithmAESField)
        envelope.append(UInt8(ShamirKeyShardEngine.threshold))
        envelope.append(UInt8(ShamirKeyShardEngine.totalShares))
        envelope.append(coordinate)
        envelope.append(setIdentifier)
        let length = UInt32(secretLength)
        envelope.append(UInt8((length >> 24) & 0xFF))
        envelope.append(UInt8((length >> 16) & 0xFF))
        envelope.append(UInt8((length >> 8) & 0xFF))
        envelope.append(UInt8(length & 0xFF))
        envelope.append(payload)

        let tag = try authenticationCode(
            for: authenticationMessage(for: envelope),
            using: validationKey
        )
        envelope.append(tag)
        return textPrefix + encodeBase64URL(envelope)
    }

    private static func decodeShare(_ text: String) throws -> Share {
        guard text.hasPrefix(textPrefix) else { throw ShamirKeyShardError.malformedShare }
        let encodedText = String(text.dropFirst(textPrefix.count))
        let maximumBinaryLength = headerLength + secretLimit + validationKeyLength + authenticationTagLength
        let maximumEncodedLength = ((maximumBinaryLength + 2) / 3) * 4
        // Check the UTF-8 view before materializing a second, byte-array copy of hostile input.
        let encodedLength = encodedText.utf8.count
        guard encodedLength > 0,
              encodedLength <= maximumEncodedLength,
              encodedLength % 4 != 1 else {
            throw ShamirKeyShardError.malformedShare
        }
        let encodedBytes = Array(encodedText.utf8)
        guard
              encodedBytes.allSatisfy(isBase64URLByte),
              encodedBytes.count == encodedLength else {
            throw ShamirKeyShardError.malformedShare
        }

        let standardBase64 = encodedText
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingCount = (4 - encodedLength % 4) % 4
        guard let decoded = Data(
            base64Encoded: standardBase64 + String(repeating: "=", count: paddingCount)
        ), encodeBase64URL(decoded) == encodedText else {
            throw ShamirKeyShardError.malformedShare
        }

        let bytes = Array(decoded)
        guard bytes.count >= headerLength + validationKeyLength + authenticationTagLength,
              Array(bytes[0..<magic.count]) == magic else {
            throw ShamirKeyShardError.malformedShare
        }
        guard bytes[4] == version else { throw ShamirKeyShardError.unsupportedVersion }
        guard bytes[5] == algorithmAESField else { throw ShamirKeyShardError.unsupportedAlgorithm }
        guard bytes[6] == UInt8(ShamirKeyShardEngine.threshold),
              bytes[7] == UInt8(ShamirKeyShardEngine.totalShares),
              (1...ShamirKeyShardEngine.totalShares).contains(Int(bytes[8])) else {
            throw ShamirKeyShardError.invalidShareMetadata
        }

        let secretLengthValue = (UInt32(bytes[25]) << 24)
            | (UInt32(bytes[26]) << 16)
            | (UInt32(bytes[27]) << 8)
            | UInt32(bytes[28])
        guard secretLengthValue > 0,
              secretLengthValue <= UInt32(secretLimit) else {
            throw ShamirKeyShardError.secretTooLarge
        }
        let secretLength = Int(secretLengthValue)
        let payloadLength = secretLength + validationKeyLength
        let expectedCount = headerLength + payloadLength + authenticationTagLength
        guard bytes.count == expectedCount else { throw ShamirKeyShardError.malformedShare }

        let setIdentifier = Data(bytes[9..<25])
        let payload = Data(bytes[headerLength..<(headerLength + payloadLength)])
        let unsignedEnvelope = Data(bytes[..<(headerLength + payloadLength)])
        let authenticationTag = Data(bytes[(headerLength + payloadLength)..<expectedCount])
        return Share(
            coordinate: bytes[8],
            setIdentifier: setIdentifier,
            secretLength: secretLength,
            payload: payload,
            unsignedEnvelope: unsignedEnvelope,
            authenticationTag: authenticationTag
        )
    }

    private static func authenticationMessage(for unsignedEnvelope: Data) -> Data {
        var message = authenticationDomain
        message.append(unsignedEnvelope)
        return message
    }

    private static func authenticationCode(for message: Data, using key: Data) throws -> Data {
        #if canImport(CryptoKit)
        let code = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return Data(code)
        #elseif canImport(Crypto)
        let code = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return Data(code)
        #else
        throw ShamirKeyShardError.cryptographyUnavailable
        #endif
    }

    private static func isValidAuthenticationTag(_ tag: Data, message: Data, key: Data) -> Bool {
        #if canImport(CryptoKit)
        return HMAC<SHA256>.isValidAuthenticationCode(
            tag,
            authenticating: message,
            using: SymmetricKey(data: key)
        )
        #elseif canImport(Crypto)
        return HMAC<SHA256>.isValidAuthenticationCode(
            tag,
            authenticating: message,
            using: SymmetricKey(data: key)
        )
        #else
        return false
        #endif
    }

    static func secureRandomBytes(count: Int) throws -> Data {
        guard count >= 0 else { throw ShamirKeyShardError.secureRandomFailed }
        #if canImport(Security)
        if count == 0 { return Data() }
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard status == errSecSuccess else { throw ShamirKeyShardError.secureRandomFailed }
        return bytes
        #else
        throw ShamirKeyShardError.secureRandomUnavailable
        #endif
    }

    private static func secureRandomBytes(
        count: Int,
        using provider: RandomByteProvider
    ) throws -> Data {
        let bytes = try provider(count)
        guard bytes.count == count else { throw ShamirKeyShardError.secureRandomFailed }
        return bytes
    }

    private static func encodeBase64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func isBase64URLByte(_ byte: UInt8) -> Bool {
        (byte >= 0x41 && byte <= 0x5A)
            || (byte >= 0x61 && byte <= 0x7A)
            || (byte >= 0x30 && byte <= 0x39)
            || byte == 0x2D
            || byte == 0x5F
    }
}
