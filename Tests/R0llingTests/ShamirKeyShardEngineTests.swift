import Foundation
import XCTest
@testable import R0lling

final class ShamirKeyShardEngineTests: XCTestCase {
    func testAllTwoOfThreePairsRecoverExactUTF8AndAllThreeVerify() async throws {
        let secret = "Ελληνικό μυστικό 🔐 e\u{301}\0tail"
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x31))
        let result = try await engine.splitSecretIntoQuorum(secret: secret)
        let allShares = [result.shardA, result.shardB, result.shardC]

        for pair in [[allShares[0], allShares[1]], [allShares[0], allShares[2]], [allShares[1], allShares[2]]] {
            let restored = try await engine.reconstructSecret(from: pair)
            XCTAssertEqual(Array(restored.utf8), Array(secret.utf8))
            let validPair = await engine.verifyQuorum(shards: pair)
            XCTAssertTrue(validPair)
        }
        let validSet = await engine.verifyQuorum(shards: allShares)
        XCTAssertTrue(validSet)
    }

    func testSingleShareDoesNotVerifyAndCannotReconstruct() async throws {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x42))
        let shares = try await engine.splitSecretIntoQuorum(secret: "key")

        for share in [shares.shardA, shares.shardB, shares.shardC] {
            let hasQuorum = await engine.verifyQuorum(shards: [share])
            XCTAssertFalse(hasQuorum)
            do {
                _ = try await engine.reconstructSecret(from: [share])
                XCTFail("A single share must not reconstruct the secret")
            } catch ShamirKeyShardError.insufficientShares {
                // Expected.
            }
        }
    }

    func testEmptyAndOversizedSecretsAreRejected() async {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x53))
        do {
            _ = try await engine.splitSecretIntoQuorum(secret: "")
            XCTFail("Empty secret should be rejected")
        } catch ShamirKeyShardError.emptySecret {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let oversized = String(repeating: "x", count: ShamirKeyShardEngine.maximumSecretBytes + 1)
        do {
            _ = try await engine.splitSecretIntoQuorum(secret: oversized)
            XCTFail("Oversized secret should be rejected")
        } catch ShamirKeyShardError.secretTooLarge {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDuplicateMixedMalformedAndNonCanonicalSharesFailClosed() async throws {
        let firstEngine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x64))
        let secondEngine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x75))
        let first = try await firstEngine.splitSecretIntoQuorum(secret: "first secret")
        let second = try await secondEngine.splitSecretIntoQuorum(secret: "second secret")

        let duplicate = await firstEngine.verifyQuorum(shards: [first.shardA, first.shardA])
        XCTAssertFalse(duplicate)
        let mixedSet = await firstEngine.verifyQuorum(shards: [first.shardA, second.shardB])
        XCTAssertFalse(mixedSet)
        let malformed = await firstEngine.verifyQuorum(shards: ["not-a-share", first.shardB])
        XCTAssertFalse(malformed)
        let padded = await firstEngine.verifyQuorum(shards: [first.shardA + "=", first.shardB])
        XCTAssertFalse(padded)
    }

    func testTamperedPayloadOrTagFailsAuthentication() async throws {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x26))
        let shares = try await engine.splitSecretIntoQuorum(secret: "integrity matters")

        let tamperedPayload = mutateEnvelopeByte(shares.shardA, offset: ShamirSecretSharing.headerLength)
        let badPayload = await engine.verifyQuorum(shards: [tamperedPayload, shares.shardB])
        XCTAssertFalse(badPayload)

        let tamperedTag = mutateEnvelopeByte(shares.shardA, offset: nil)
        let badTag = await engine.verifyQuorum(shards: [tamperedTag, shares.shardB])
        XCTAssertFalse(badTag)

        let badThreeShareSet = await engine.verifyQuorum(shards: [tamperedPayload, shares.shardB, shares.shardC])
        XCTAssertFalse(badThreeShareSet)
    }

    func testUnsupportedVersionAlgorithmTruncationAndExtraSharesFailClosed() async throws {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x2B))
        let shares = try await engine.splitSecretIntoQuorum(secret: "strict parser")

        let unsupportedVersion = mutateEnvelopeByte(shares.shardA, offset: 4)
        let badVersionAccepted = await engine.verifyQuorum(shards: [unsupportedVersion, shares.shardB])
        XCTAssertFalse(badVersionAccepted)

        let unsupportedAlgorithm = mutateEnvelopeByte(shares.shardA, offset: 5)
        let badAlgorithmAccepted = await engine.verifyQuorum(shards: [unsupportedAlgorithm, shares.shardB])
        XCTAssertFalse(badAlgorithmAccepted)

        let truncated = String(shares.shardA.dropLast())
        let truncatedAccepted = await engine.verifyQuorum(shards: [truncated, shares.shardB])
        XCTAssertFalse(truncatedAccepted)

        let tooManyShares = await engine.verifyQuorum(shards: [shares.shardA, shares.shardB, shares.shardC, shares.shardA])
        XCTAssertFalse(tooManyShares)
    }

    func testThresholdTotalCoordinateSetAndLengthMetadataAreValidated() async throws {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x2C))
        let shares = try await engine.splitSecretIntoQuorum(secret: "metadata")

        let badThreshold = mutateEnvelopeByte(shares.shardA, offset: 6)
        do {
            _ = try await engine.reconstructSecret(from: [badThreshold, shares.shardB])
            XCTFail("Unsupported threshold must fail")
        } catch ShamirKeyShardError.invalidShareMetadata {
            // Expected.
        }

        let badTotal = mutateEnvelopeByte(shares.shardA, offset: 7)
        do {
            _ = try await engine.reconstructSecret(from: [badTotal, shares.shardB])
            XCTFail("Unsupported share count must fail")
        } catch ShamirKeyShardError.invalidShareMetadata {
            // Expected.
        }

        let badCoordinate = mutateEnvelopeByte(shares.shardA, offset: 8)
        do {
            _ = try await engine.reconstructSecret(from: [badCoordinate, shares.shardB])
            XCTFail("Zero share coordinate must fail")
        } catch ShamirKeyShardError.invalidShareMetadata {
            // Expected.
        }

        let mixedSetIdentifier = mutateEnvelopeByte(shares.shardA, offset: 9)
        do {
            _ = try await engine.reconstructSecret(from: [mixedSetIdentifier, shares.shardB])
            XCTFail("Different set identifiers must fail")
        } catch ShamirKeyShardError.mixedShareSets {
            // Expected.
        }

        let invalidLength = mutateEnvelopeByte(shares.shardA, offset: 28)
        do {
            _ = try await engine.reconstructSecret(from: [invalidLength, shares.shardB])
            XCTFail("Length inconsistent with envelope must fail")
        } catch ShamirKeyShardError.malformedShare {
            // Expected.
        }
    }

    func testThreeSharesMustBelongToOneDegreeOnePolynomial() async throws {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x37))
        let shares = try await engine.splitSecretIntoQuorum(secret: "consistent")
        let tamperedThird = mutateEnvelopeByte(shares.shardC, offset: ShamirSecretSharing.headerLength + 1)
        let validPair = await engine.verifyQuorum(shards: [shares.shardA, shares.shardB])
        let invalidTriple = await engine.verifyQuorum(shards: [shares.shardA, shares.shardB, tamperedThird])
        XCTAssertTrue(validPair)
        XCTAssertFalse(invalidTriple)
    }

    func testInvalidUTF8AfterValidShareAuthenticationIsRejected() async throws {
        let random = seededRandom(0x48)
        let encoded = try ShamirSecretSharing.split(secretBytes: Data([0xFF]), randomByteProvider: random)
        let engine = ShamirKeyShardEngine(randomByteProvider: random)
        do {
            _ = try await engine.reconstructSecret(from: [encoded.shardA, encoded.shardB])
            XCTFail("Invalid UTF-8 must not be silently replaced")
        } catch ShamirKeyShardError.invalidUTF8 {
            // Expected.
        }
        let reportsQuorum = await engine.verifyQuorum(shards: [encoded.shardA, encoded.shardB])
        XCTAssertFalse(reportsQuorum)
    }

    func testResplittingCreatesANewShareSet() async throws {
        let firstEngine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x19))
        let secondEngine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x2A))
        let first = try await firstEngine.splitSecretIntoQuorum(secret: "same secret")
        let second = try await secondEngine.splitSecretIntoQuorum(secret: "same secret")

        XCTAssertNotEqual(first.shardA, second.shardA)
        let firstIdentifier = try shareSetIdentifier(first.shardA)
        let secondIdentifier = try shareSetIdentifier(second.shardA)
        XCTAssertNotEqual(firstIdentifier, secondIdentifier)
    }

    func testGF256KnownProductsAndInverses() {
        XCTAssertEqual(ShamirSecretSharing.gfMultiply(0x57, 0x13), 0xFE)
        XCTAssertEqual(ShamirSecretSharing.gfMultiply(0x53, 0xCA), 0x01)
        for value in UInt8(1)...UInt8(255) {
            XCTAssertEqual(ShamirSecretSharing.gfMultiply(value, ShamirSecretSharing.gfInverse(value)), 0x01)
        }
    }

    func testKnownTwoPointInterpolationVector() throws {
        let setID = Data(repeating: 0xA1, count: ShamirSecretSharing.setIdentifierLength)
        let first = ShamirSecretSharing.Share(
            coordinate: 1,
            setIdentifier: setID,
            secretLength: 1,
            payload: Data([0xDB]), // 0x42 XOR (0x99 * 1)
            unsignedEnvelope: Data(),
            authenticationTag: Data()
        )
        let second = ShamirSecretSharing.Share(
            coordinate: 2,
            setIdentifier: setID,
            secretLength: 1,
            payload: Data([0x6B]), // 0x42 XOR (0x99 * 2) in GF(256)/0x11B
            unsignedEnvelope: Data(),
            authenticationTag: Data()
        )
        XCTAssertEqual(try ShamirSecretSharing.interpolateAtZero([first, second]), Data([0x42]))
    }

    func testShortRandomSourceFailsWithoutFallback() async {
        let engine = ShamirKeyShardEngine(randomByteProvider: { _ in Data([0x7F]) })
        do {
            _ = try await engine.splitSecretIntoQuorum(secret: "secret")
            XCTFail("Short CSPRNG output must fail closed")
        } catch ShamirKeyShardError.secureRandomFailed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testThrowingRandomSourceFailsWithoutFallback() async {
        let engine = ShamirKeyShardEngine(randomByteProvider: { _ in
            throw ShamirKeyShardError.secureRandomFailed
        })
        do {
            _ = try await engine.splitSecretIntoQuorum(secret: "secret")
            XCTFail("Failed CSPRNG must fail closed")
        } catch ShamirKeyShardError.secureRandomFailed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMaximumAllowedSecretRoundTrips() async throws {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x4D))
        let secret = String(repeating: "z", count: ShamirKeyShardEngine.maximumSecretBytes)
        let shares = try await engine.splitSecretIntoQuorum(secret: secret)
        let restored = try await engine.reconstructSecret(from: [shares.shardA, shares.shardC])
        XCTAssertEqual(restored.utf8.count, ShamirKeyShardEngine.maximumSecretBytes)
        XCTAssertEqual(restored, secret)
    }

    func testOversizedShareInputIsRejectedBeforeDecoding() async {
        let engine = ShamirKeyShardEngine(randomByteProvider: seededRandom(0x5A))
        let maximumBinaryLength = ShamirSecretSharing.headerLength
            + ShamirKeyShardEngine.maximumSecretBytes
            + ShamirSecretSharing.validationKeyLength
            + ShamirSecretSharing.authenticationTagLength
        let maximumEncodedLength = ((maximumBinaryLength + 2) / 3) * 4
        let oversized = ShamirSecretSharing.textPrefix + String(repeating: "A", count: maximumEncodedLength + 1)
        let accepted = await engine.verifyQuorum(shards: [oversized, oversized])
        XCTAssertFalse(accepted)
    }

    private func seededRandom(_ seed: UInt8) -> ShamirSecretSharing.RandomByteProvider {
        { count in
            Data((0..<count).map { UInt8(truncatingIfNeeded: $0) &+ seed })
        }
    }

    private func mutateEnvelopeByte(_ share: String, offset: Int?) -> String {
        let prefix = ShamirSecretSharing.textPrefix
        guard share.hasPrefix(prefix) else { return "malformed" }
        let encoded = String(share.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard var bytes = Data(base64Encoded: padded), !bytes.isEmpty else { return "malformed" }
        let byteIndex = offset ?? (bytes.count - 1)
        guard bytes.indices.contains(byteIndex) else { return "malformed" }
        bytes[byteIndex] ^= 0x01
        let modified = bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return prefix + modified
    }

    private func shareSetIdentifier(_ share: String) throws -> Data {
        let prefix = ShamirSecretSharing.textPrefix
        guard share.hasPrefix(prefix) else { throw ShamirKeyShardError.malformedShare }
        let encoded = String(share.dropFirst(prefix.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let bytes = Data(base64Encoded: padded), bytes.count >= 25 else {
            throw ShamirKeyShardError.malformedShare
        }
        return Data(bytes[9..<25])
    }
}
