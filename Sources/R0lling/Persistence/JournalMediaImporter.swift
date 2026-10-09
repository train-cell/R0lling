import Foundation
import UniformTypeIdentifiers

/// Ελάχιστος ελεύθερος χώρος πριν από αποθήκευση media (A03 / A16).
public let ELAXISTOS_ELEUTHEROS_XOROS_BYTES: Int64 = 50 * 1024 * 1024

/// Typed errors για media persistence — χωρίς silent success.
public enum MediaApothikeusiError: Error, LocalizedError, Sendable, Equatable {
    case anepikisXoros(diathesima: Int64, apaitoumena: Int64)
    case kenoDedomena
    case agnostosTypos(onomaArxeiou: String)
    case egrafiApetixe(minima: String)
    case arxeioDenVrethike(relativePath: String)
    case unsafeRelativePath(relativePath: String)

    public var errorDescription: String? {
        switch self {
        case .anepikisXoros(let diathesima, let apaitoumena):
            return "Ανεπαρκής χώρος (\(diathesima) bytes διαθέσιμα, απαιτούνται ≥\(apaitoumena))."
        case .kenoDedomena:
            return "Κενά δεδομένα media — δεν αποθηκεύτηκε τίποτα."
        case .agnostosTypos(let onoma):
            return "Άγνωστος τύπος αρχείου: \(onoma)"
        case .egrafiApetixe(let minima):
            return "Αποτυχία εγγραφής media: \(minima)"
        case .arxeioDenVrethike(let path):
            return "Το media δεν βρέθηκε: \(path)"
        case .unsafeRelativePath(let path):
            return "Μη έγκυρο σχετικό path πολυμέσου: \(path)"
        }
    }
}

/// Καθαρή ταξινόμηση αρχείων → `MediaType` (χωρίς UI / Photos framework).
public enum JournalMediaImporter: Sendable {
    /// Αντιστοιχεί filename / UTType hint σε `MediaType`.
    public static func mediaType(
        giaOnomaArxeiou onoma: String,
        utTypeIdentifier: String? = nil
    ) throws -> MediaType {
        if let utTypeIdentifier,
           let ut = UTType(utTypeIdentifier) {
            if ut.conforms(to: .image) { return .photo }
            if ut.conforms(to: .movie) || ut.conforms(to: .video) { return .video }
            if ut.conforms(to: .audiovisualContent) && ut.conforms(to: .audio) { return .audio }
            if ut.conforms(to: .audio) { return .audio }
        }

        let ext = (onoma as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "bmp":
            return .photo
        case "mp4", "mov", "m4v", "avi", "mkv":
            return .video
        case "m4a", "aac", "mp3", "wav", "caf", "aiff":
            return .audio
        case "":
            throw MediaApothikeusiError.agnostosTypos(onomaArxeiou: onoma)
        default:
            throw MediaApothikeusiError.agnostosTypos(onomaArxeiou: onoma)
        }
    }

    /// Προεπιλεγμένο κείμενο καταγραφής για εισαγωγή media χωρίς σημείωση χρήστη.
    public static func proepiloghmenoKeimeno(gia typo: MediaType) -> String {
        switch typo {
        case .photo: return "Εισαγωγή φωτογραφίας από Photos/Files."
        case .video: return "Εισαγωγή βίντεο από Photos/Files."
        case .audio: return "Εισαγωγή ηχητικού από Files."
        case .clip: return "Εισαγωγή clip."
        }
    }
}
