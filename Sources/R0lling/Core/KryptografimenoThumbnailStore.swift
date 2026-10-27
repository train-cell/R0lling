import Foundation
import CryptoKit

/// Kryptografimeno Store gia Media Thumbnails (Idea 20).
/// Apothikevei tis mikrografies eikonwn kai videoclips krypto-apomonwmenes me AES-256-GCM,
/// apotrepontas ti diarroi previews stous koinoxristous fakelous QuickLook/Photos tou iOS.
public final class KryptografimenoThumbnailStore: @unchecked Sendable {
    public static let shared = KryptografimenoThumbnailStore()

    private let kleidaria = NSLock()
    private var kleidiKryptografisis: SymmetricKey
    private var apothikiMnimis: [UUID: Data] = [:]

    public init(kleidi: SymmetricKey = SymmetricKey(size: .bits256)) {
        self.kleidiKryptografisis = kleidi
    }

    /// Krypto-apothikefsi thumbnail gia ena sygekrimeno mediaID.
    public func apothikefsiThumbnail(mediaID: UUID, dedomenaEikonas: Data) throws {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard !dedomenaEikonas.isEmpty else {
            throw NSError(domain: "R0lling.ThumbnailStore", code: 4101, userInfo: [
                NSLocalizedDescriptionKey: "Κενά δεδομένα εικόνας για δημιουργία thumbnail."
            ])
        }

        let sealedBox = try AES.GCM.seal(dedomenaEikonas, using: kleidiKryptografisis)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "R0lling.ThumbnailStore", code: 4102, userInfo: [
                NSLocalizedDescriptionKey: "Αποτυχία παραγωγής συνδυασμένου κρυπτογραφημένου πακέτου."
            ])
        }

        apothikiMnimis[mediaID] = combined

        R0llingTelemetry.shared.log(
            .storage,
            stathmi: .debug,
            "[ThumbnailStore] Κρυπτογραφήθηκε και αποθηκεύτηκε thumbnail για το media \(mediaID.uuidString) (\(dedomenaEikonas.count) bytes)"
        )
    }

    /// Anaklisi kai apokryptografisi tou thumbnail gia to mediaID.
    public func anaklisiThumbnail(mediaID: UUID) throws -> Data? {
        kleidaria.lock()
        defer { kleidaria.unlock() }

        guard let combined = apothikiMnimis[mediaID] else {
            return nil
        }

        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decryptedData = try AES.GCM.open(sealedBox, using: kleidiKryptografisis)
        return decryptedData
    }

    /// Diagrafi tou thumbnail.
    public func diagrafiThumbnail(mediaID: UUID) {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        apothikiMnimis.removeValue(forKey: mediaID)
    }

    /// Katharismos olwn twn thumbnails.
    public func katharismos() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        apothikiMnimis.removeAll()
    }
}
