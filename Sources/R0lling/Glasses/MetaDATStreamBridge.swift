import Foundation

#if canImport(MetaWearablesDAT)
import MetaWearablesDAT
#endif

/// Γέφυρα προς το Meta Wearables DAT SDK.
///
/// Σε builds **χωρίς** `MetaWearablesDAT` (Windows SPM / CI χωρίς vendor), κάθε live API
/// πετάει σαφές error — **ποτέ** ψευδή σύνδεση. Σε Mac με DAT linked (`#if canImport`),
/// τα hooks γεμίζουν με πραγματικές session κλήσεις (βλ. `docs/LANE_CLIP_META.md`).
public enum MetaDATStreamBridge {
    public static let errorDomain = "R0lling.Glasses.DAT"
    /// SDK δεν είναι linked στο τρέχον build.
    public static let kodikosSDKMiDiathesimo: Int = 4010
    /// Session ανοίγει μόνο με πραγματικό device token / Dev Mode.
    public static let kodikosSessionApotyxia: Int = 4011

    /// `true` μόνο όταν το MetaWearablesDAT module είναι importable.
    public static var einaiSDKDiathesimo: Bool {
        #if canImport(MetaWearablesDAT)
        return true
        #else
        return false
        #endif
    }

    /// Αποτέλεσμα ανοίγματος live camera session.
    public struct LiveSessionHandle: Sendable {
        public let deviceName: String
        public let batteryPercent: Int?
        public let supportsCompressedHEVC: Bool
        public let isSimulationLabeled: Bool

        public init(
            deviceName: String,
            batteryPercent: Int?,
            supportsCompressedHEVC: Bool,
            isSimulationLabeled: Bool
        ) {
            self.deviceName = deviceName
            self.batteryPercent = batteryPercent
            self.supportsCompressedHEVC = supportsCompressedHEVC
            self.isSimulationLabeled = isSimulationLabeled
        }
    }

    /// Ανοίγει live streaming session στα Gen 2.
    /// - Throws: `4010` χωρίς SDK· `4011` σε αποτυχία pairing/session.
    public static func anoixeLiveSession() async throws -> LiveSessionHandle {
        #if canImport(MetaWearablesDAT)
        // MARK: DAT wiring point (Mac + Gen 2)
        // Αντικατέστησε με: Wearables session start / CameraAccess startStreaming
        // σύμφωνα με το επίσημο sample CameraAccess του meta-wearables-dat-ios.
        //
        // Παράδειγμα δομής (ψευδοκώδικας — συμπλήρωσε με πραγματικά DAT types):
        //   let session = try await WearablesSession.shared.connect()
        //   try await session.camera.startStreaming(codec: .hevc)
        //   return LiveSessionHandle(deviceName: session.device.name, ...)
        //
        // Μέχρι να γίνει wire με πραγματικά σύμβολα SDK, ρίχνουμε 4011 ώστε
        // να μην εμφανίζεται ψευδής «connected» χωρίς επιτυχή DAT call.
        throw NSError(
            domain: errorDomain,
            code: kodikosSessionApotyxia,
            userInfo: [NSLocalizedDescriptionKey:
                "MetaWearablesDAT είναι linked αλλά το live session hook δεν έχει γίνει wire ακόμα. " +
                "Ολοκλήρωσε το CameraAccess startStreaming στο MetaDATStreamBridge.anoixeLiveSession — " +
                "docs/LANE_CLIP_META.md βήμα 4."]
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey:
                "Το Meta Wearables DAT SDK δεν είναι συνδεδεμένο σε αυτό το build " +
                "(canImport(MetaWearablesDAT) == false). " +
                "Ενεργοποίησε Simulation Mode ή πρόσθεσε το SPM dependency στο Mac — docs/LANE_CLIP_META.md."]
        )
        #endif
    }

    /// Κλείνει live session αν υπάρχει.
    public static func kleiseLiveSession() async {
        #if canImport(MetaWearablesDAT)
        // Wire: session.camera.stopStreaming() + disconnect
        #endif
    }

    /// Διαβάζει ένα compressed video frame από το DAT stream (Annex-B ή length-prefixed).
    /// - Returns: `nil` αν δεν υπάρχει νέο frame (poll miss).
    public static func diavaseEpomenoVideoFrame() async throws -> BufferedSample? {
        #if canImport(MetaWearablesDAT)
        throw NSError(
            domain: errorDomain,
            code: kodikosSessionApotyxia,
            userInfo: [NSLocalizedDescriptionKey:
                "DAT frame pull δεν έχει γίνει wire. Συμπλήρωσε diavaseEpomenoVideoFrame με CameraAccess sample callback."]
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "DAT frame pull αδύνατο χωρίς MetaWearablesDAT."]
        )
        #endif
    }

    /// Διαβάζει συγχρονισμένο audio sample από τη ροή των γυαλιών (αν παρέχεται).
    public static func diavaseEpomenoAudioSample() async throws -> BufferedSample? {
        #if canImport(MetaWearablesDAT)
        return nil
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "DAT audio pull αδύνατο χωρίς MetaWearablesDAT."]
        )
        #endif
    }

    /// Διαβάζει IMU sample (pitch/roll/yaw) αν το SDK το εκθέτει.
    public static func diavaseEpomenoIMU() async throws -> HeadGestureDetector.IMUSample? {
        #if canImport(MetaWearablesDAT)
        return nil
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "DAT IMU pull αδύνατο χωρίς MetaWearablesDAT."]
        )
        #endif
    }
}
