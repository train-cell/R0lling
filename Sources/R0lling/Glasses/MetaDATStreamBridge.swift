import Foundation

#if canImport(MWDATCore) && canImport(MWDATCamera)
import MWDATCore
import MWDATCamera
#endif

/// Γέφυρα προς το Meta Wearables DAT SDK.
///
/// Builds χωρίς και τα δύο DAT modules (`MWDATCore` + `MWDATCamera`) απορρίπτουν
/// κάθε live αίτημα με σαφές error.
/// Η εισαγωγή του SDK από μόνη της δεν ενεργοποιεί τη σύνδεση: τα session, video,
/// audio και IMU hooks παραμένουν stubs και το real mode είναι απενεργοποιημένο.
/// Δες `docs/LANE_CLIP_META.md` για την απαιτούμενη υλοποίηση και επαλήθευση.
public enum MetaDATStreamBridge {
    /// Module presence does not imply a working camera/session integration.
    public static let einaiLiveYlopoiimeno = false

    public static let errorDomain = "R0lling.Glasses.DAT"
    /// SDK δεν είναι linked στο τρέχον build.
    public static let kodikosSDKMiDiathesimo: Int = 4010
    /// Session ανοίγει μόνο με πραγματικό device token / Dev Mode.
    public static let kodikosSessionApotyxia: Int = 4011

    /// `true` μόνο όταν είναι importable και το `MWDATCore` και το `MWDATCamera`.
    public static var einaiSDKDiathesimo: Bool {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
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

    /// Προσπαθεί να ανοίξει live streaming session στα Gen 2.
    /// Αυτή η υλοποίηση δεν ανοίγει session και αποτυγχάνει κλειστά.
    /// - Throws: `4010` χωρίς SDK· `4011` όταν το SDK υπάρχει αλλά το hook δεν είναι wired.
    public static func anoixeLiveSession() async throws -> LiveSessionHandle {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        // Do not report connected merely because the vendor module can be imported.
        throw NSError(
            domain: errorDomain,
            code: kodikosSessionApotyxia,
            userInfo: [NSLocalizedDescriptionKey:
                "MWDATCore/MWDATCamera είναι linked αλλά το live session hook δεν έχει γίνει wire ακόμα. " +
                "Ολοκλήρωσε και έλεγξε το session/frame bridge πριν ενεργοποιήσεις real mode — " +
                "docs/LANE_CLIP_META.md §3."]
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey:
                "Τα Meta Wearables DAT modules MWDATCore και MWDATCamera δεν είναι και τα δύο συνδεδεμένα σε αυτό το build. " +
                "Ενεργοποίησε Simulation Mode ή πρόσθεσε το SPM dependency στο Mac — docs/LANE_CLIP_META.md."]
        )
        #endif
    }

    /// Κλείνει live session αν υπάρχει.
    public static func kleiseLiveSession() async {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        // No DAT session is opened by this stub, so there is nothing to close.
        #endif
    }

    /// DAT video-frame hook. It currently fails closed in every build configuration.
    public static func diavaseEpomenoVideoFrame() async throws -> BufferedSample? {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
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
            userInfo: [NSLocalizedDescriptionKey: "DAT frame pull αδύνατο χωρίς τα MWDATCore/MWDATCamera modules."]
        )
        #endif
    }

    /// Διαβάζει συγχρονισμένο audio sample από τη ροή των γυαλιών (αν παρέχεται).
    public static func diavaseEpomenoAudioSample() async throws -> BufferedSample? {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        throw NSError(
            domain: errorDomain,
            code: kodikosSessionApotyxia,
            userInfo: [NSLocalizedDescriptionKey:
                "DAT audio capture δεν έχει γίνει wire. Το SDK module υπάρχει, αλλά δεν παρέχεται live audio sample."]
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "DAT audio pull αδύνατο χωρίς τα MWDATCore/MWDATCamera modules."]
        )
        #endif
    }

    /// Διαβάζει IMU sample (pitch/roll/yaw) αν το SDK το εκθέτει.
    public static func diavaseEpomenoIMU() async throws -> HeadGestureDetector.IMUSample? {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        throw NSError(
            domain: errorDomain,
            code: kodikosSessionApotyxia,
            userInfo: [NSLocalizedDescriptionKey:
                "DAT IMU capture δεν έχει γίνει wire. Το SDK module υπάρχει, αλλά δεν παρέχεται live IMU sample."]
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "DAT IMU pull αδύνατο χωρίς τα MWDATCore/MWDATCamera modules."]
        )
        #endif
    }
}
