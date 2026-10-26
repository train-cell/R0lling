import Foundation

#if canImport(MWDATCore) && canImport(MWDATCamera)
import MWDATCore
import MWDATCamera
#endif

/// Γέφυρα προς το Meta Wearables DAT SDK.
///
/// Builds χωρίς και τα δύο DAT modules (`MWDATCore` + `MWDATCamera`) απορρίπτουν
/// κάθε live αίτημα με σαφές error.
/// Η εισαγωγή του SDK από μόνη της δεν ενεργοποιεί το real mode. Το registration
/// και το DeviceSession lifecycle έχουν source υλοποίηση· camera/media και sensor
/// callbacks παραμένουν κλειστά μέχρι να ολοκληρωθούν τα format και device checks.
/// Δες `docs/LANE_CLIP_META.md` για την απαιτούμενη υλοποίηση και επαλήθευση.
public enum MetaDATStreamBridge {
    /// Module presence does not imply a working camera/session integration.
    public static let einaiLiveYlopoiimeno = false

    public static let errorDomain = "R0lling.Glasses.DAT"
    /// SDK δεν είναι linked στο τρέχον build.
    public static let kodikosSDKMiDiathesimo: Int = 4010
    /// Live session/camera hook failure or an unavailable live media path.
    public static let kodikosSessionApotyxia: Int = 4011
    /// Η registration ροή ξεκίνησε ή εκκρεμεί επιστροφή από Meta AI.
    public static let kodikosRegistrationRequired: Int = 4012
    /// Το DeviceSession δεν έφτασε στο `.started` εντός του ορίου αναμονής.
    public static let kodikosSessionStartTimedOut: Int = 4013
    /// Απαιτείται ρητή επιβεβαίωση πριν από το Meta AI camera-permission handoff.
    public static let kodikosCameraPermissionConfirmationRequired: Int = 4014
    /// Η camera permission δεν δόθηκε ή το stream δεν ξεκίνησε.
    public static let kodikosCameraUnavailable: Int = 4015

    #if canImport(MWDATCore) && canImport(MWDATCamera)
    private static let sessionController = MetaDATSessionController()
    #endif

    /// `true` μόνο όταν είναι importable και το `MWDATCore` και το `MWDATCamera`.
    public static var einaiSDKDiathesimo: Bool {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        return true
        #else
        return false
        #endif
    }

    /// Αποτέλεσμα ανοίγματος DAT DeviceSession· δεν σημαίνει ότι άνοιξε camera stream.
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

    /// Συνδέεται σε DAT DeviceSession στα Gen 2· δεν προσθέτει camera capability.
    /// Ξεκινά registration όταν απαιτείται και περιμένει το DAT DeviceSession να γίνει `.started`.
    /// Η κλήση πρέπει να προέρχεται από ρητή ενέργεια σύνδεσης του χρήστη.
    /// - Throws: `4010` χωρίς SDK· `4011` για αποτυχία session· `4012` για ολοκλήρωση registration.
    public static func anoixeLiveSession() async throws -> LiveSessionHandle {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        return try await sessionController.open()
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey:
                "Τα Meta Wearables DAT modules MWDATCore και MWDATCamera δεν είναι διαθέσιμα σε αυτό το build. " +
                "Χρειάζεται συμβατό iOS build· διαφορετικά χρησιμοποίησε Simulation Mode — docs/LANE_CLIP_META.md."]
        )
        #endif
    }

    /// Κλείνει live session αν υπάρχει.
    public static func kleiseLiveSession() async {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        await sessionController.close()
        #endif
    }

    /// Καλείται μόνο από υπάρχουσα ενέργεια start αφού ο χρήστης επιβεβαιώσει
    /// ότι μπορεί να ανοίξει το Meta AI για αίτημα camera permission.
    public static func zitaCameraPermissionMetaAIHandoff() async throws {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        try await sessionController.requestCameraPermissionAfterUserConfirmation()
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "Η DAT camera permission δεν είναι διαθέσιμη χωρίς MWDATCore/MWDATCamera."]
        )
        #endif
    }

    /// Ξεκινά την υπάρχουσα live-buffer ροή μόνο αφού έχει ήδη δοθεί permission.
    /// Δεν εμφανίζει μόνο του Meta AI ούτε ζητά permission χωρίς την παραπάνω επιβεβαίωση.
    public static func arxiseLiveCameraStream() async throws {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        try await sessionController.startCameraStream()
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "Η DAT camera stream δεν είναι διαθέσιμη χωρίς MWDATCore/MWDATCamera."]
        )
        #endif
    }

    public static func stamataLiveCameraStream() async {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        await sessionController.stopCameraStream()
        #endif
    }

    /// Pulls from the bounded publisher-backed frame queue when DAT is linked;
    /// builds without the SDK fail closed.
    public static func diavaseEpomenoVideoFrame() async throws -> BufferedSample? {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        return try await sessionController.nextVideoFrame()
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

    /// Λήψη μεμονωμένης φωτογραφίας υψηλής ανάλυσης από τα έξυπνα γυαλιά (on-demand capture).
    /// - Throws: `4010` χωρίς SDK, `4011` όταν δεν υπάρχει live session/camera hook.
    public static func travaFotografia() async throws -> Data {
        #if canImport(MWDATCore) && canImport(MWDATCamera)
        throw NSError(
            domain: errorDomain,
            code: kodikosSessionApotyxia,
            userInfo: [NSLocalizedDescriptionKey:
                "DAT photo capture δεν έχει γίνει wire. Το SDK module υπάρχει, αλλά δεν παρέχεται live capture hook."]
        )
        #else
        throw NSError(
            domain: errorDomain,
            code: kodikosSDKMiDiathesimo,
            userInfo: [NSLocalizedDescriptionKey: "DAT photo capture αδύνατο χωρίς τα MWDATCore/MWDATCamera modules."]
        )
        #endif
    }
}

#if canImport(MWDATCore) && canImport(MWDATCamera)
/// Owns the vendor session and serializes open/close so disconnect can invalidate a
/// session while a caller is waiting for its asynchronous `.started` transition.
private actor MetaDATSessionController {
    private var session: DeviceSession?
    private var camera: Camera?
    private var listenerTokens: ListenerTokenBag?
    private var frameBuffer: MetaDATVideoFrameBuffer?
    private var h264Encoder: MetaDATH264Encoder?
    private var streamStartGate: MetaDATStreamStartGate?
    private var isOpening = false

    func open() async throws -> MetaDATStreamBridge.LiveSessionHandle {
        guard !isOpening else {
            throw failure(
                code: MetaDATStreamBridge.kodikosSessionApotyxia,
                message: "Υπάρχει ήδη προσπάθεια ανοίγματος Meta DAT session."
            )
        }
        isOpening = true
        defer { isOpening = false }

        if let session, session.state == .started {
            return sessionHandle(for: session)
        }
        if let session {
            await stopCameraStream()
            session.stop()
            self.session = nil
        }

        let wearables = Wearables.shared
        switch wearables.registrationState {
        case .registered:
            break
        case .registering:
            throw failure(
                code: MetaDATStreamBridge.kodikosRegistrationRequired,
                message: "Ολοκλήρωσε τη σύνδεση της εφαρμογής στο Meta AI και πάτησε ξανά Σύνδεση."
            )
        case .available, .unavailable:
            try await wearables.startRegistration()
            throw failure(
                code: MetaDATStreamBridge.kodikosRegistrationRequired,
                message: "Άνοιξε το Meta AI για να εγκρίνεις το R0lling και μετά πάτησε ξανά Σύνδεση."
            )
        }

        try Task.checkCancellation()
        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        let newSession = try wearables.createSession(deviceSelector: deviceSelector)
        session = newSession

        do {
            try newSession.start()
            try await waitUntilStarted(newSession)
            try Task.checkCancellation()
            guard newSession.state == .started else {
                throw failure(
                    code: MetaDATStreamBridge.kodikosSessionApotyxia,
                    message: "Το Meta DAT session δεν παρέμεινε σε κατάσταση started."
                )
            }
            return sessionHandle(for: newSession)
        } catch {
            newSession.stop()
            if session?.deviceId == newSession.deviceId {
                session = nil
            }
            throw error
        }
    }

    func requestCameraPermissionAfterUserConfirmation() async throws {
        let wearables = Wearables.shared
        let currentStatus = try await wearables.checkPermissionStatus(.camera)
        guard currentStatus != .granted else { return }
        guard session?.state == .started else {
            throw failure(
                code: MetaDATStreamBridge.kodikosSessionApotyxia,
                message: "Σύνδεσε πρώτα τα γυαλιά πριν ζητήσεις camera permission."
            )
        }
        let requestedStatus = try await wearables.requestPermission(.camera)
        guard requestedStatus == .granted else {
            throw failure(
                code: MetaDATStreamBridge.kodikosCameraUnavailable,
                message: "Το Meta AI δεν έδωσε camera permission στο R0lling."
            )
        }
    }

    func startCameraStream() async throws {
        guard let session, session.state == .started else {
            throw failure(
                code: MetaDATStreamBridge.kodikosSessionApotyxia,
                message: "Η DAT camera απαιτεί ενεργό DeviceSession σε κατάσταση started."
            )
        }
        if camera?.stream.state == .streaming { return }
        if camera != nil { await stopCameraStream() }

        let permissionStatus = try await Wearables.shared.checkPermissionStatus(.camera)
        guard permissionStatus == .granted else {
            throw failure(
                code: MetaDATStreamBridge.kodikosCameraPermissionConfirmationRequired,
                message: "Πριν ανοίξει το Meta AI για camera permission, επιβεβαίωσε ξανά την έναρξη της ροής μέσα στο R0lling."
            )
        }
        guard self.session?.deviceId == session.deviceId, session.state == .started else {
            throw failure(
                code: MetaDATStreamBridge.kodikosSessionApotyxia,
                message: "Το DAT DeviceSession άλλαξε ή σταμάτησε κατά τον έλεγχο camera permission."
            )
        }

        let frameBufferID = UUID()
        let nextFrameBuffer = MetaDATVideoFrameBuffer(id: frameBufferID) { [weak self] message in
            Task { await self?.stopCameraStream(ifCurrentID: frameBufferID, failureMessage: message) }
        }
        let nextEncoder = try MetaDATH264Encoder(
            onEncodedSample: { sample in
                nextFrameBuffer.enqueue(sample)
            },
            onFailure: { error in
                nextFrameBuffer.finish(errorMessage: error.localizedDescription)
            }
        )

        let configuration = StreamConfiguration(videoCodec: .raw, resolution: .medium, frameRate: 24)
        let nextCamera: Camera
        do {
            guard let createdCamera = try session.addCamera(config: configuration) else {
                await nextEncoder.finish()
                throw failure(
                    code: MetaDATStreamBridge.kodikosCameraUnavailable,
                    message: "Το started DAT DeviceSession δεν επέστρεψε Camera capability."
                )
            }
            nextCamera = createdCamera
        } catch {
            await nextEncoder.finish()
            await nextFrameBuffer.finish(errorMessage: error.localizedDescription)
            throw error
        }

        let tokens = ListenerTokenBag()
        let stream = nextCamera.stream
        let lifecycle = MetaDATStreamLifecycleObserver()
        let startGate = MetaDATStreamStartGate()

        stream.videoFramePublisher.listen { frame in
            nextEncoder.encode(frame.sampleBuffer)
        }.store(in: tokens)

        stream.errorPublisher.listen { error in
            nextFrameBuffer.finish(errorMessage: error.localizedDescription)
        }.store(in: tokens)

        stream.statePublisher.listen { state in
            Task { await startGate.observe(state) }
            if lifecycle.shouldTerminate(for: state) {
                nextFrameBuffer.finish(errorMessage: "Το DAT camera stream σταμάτησε.")
            }
        }.store(in: tokens)

        camera = nextCamera
        listenerTokens = tokens
        frameBuffer = nextFrameBuffer
        h264Encoder = nextEncoder
        streamStartGate = startGate
        stream.start()
        do {
            try await startGate.waitUntilStreaming()
        } catch {
            await stopCameraStream(failureMessage: error.localizedDescription)
            throw error
        }
    }

    func nextVideoFrame() async throws -> BufferedSample? {
        if camera == nil || frameBuffer?.isTerminated == true {
            if camera != nil { await stopCameraStream() }
            try await startCameraStream()
        }
        guard let frameBuffer else {
            throw failure(
                code: MetaDATStreamBridge.kodikosCameraUnavailable,
                message: "Το DAT camera frame queue δεν είναι ενεργό."
            )
        }
        return try await frameBuffer.next()
    }

    func stopCameraStream() async {
        await stopCameraStream(failureMessage: nil)
    }

    private func stopCameraStream(failureMessage: String?) async {
        let currentCamera = camera
        let currentTokens = listenerTokens
        let currentFrameBuffer = frameBuffer
        let currentEncoder = h264Encoder
        let currentStartGate = streamStartGate
        camera = nil
        listenerTokens = nil
        frameBuffer = nil
        h264Encoder = nil
        streamStartGate = nil

        // Stop the child camera before cancelling callbacks and stopping its encoder.
        currentCamera?.stop()
        await currentTokens?.cancelAll()
        await currentEncoder?.finish()
        await currentFrameBuffer?.finish(errorMessage: failureMessage)
        await currentStartGate?.cancel()
    }

    private func stopCameraStream(ifCurrentID id: UUID, failureMessage: String) async {
        guard frameBuffer?.id == id else { return }
        await stopCameraStream(failureMessage: failureMessage)
    }

    func close() async {
        await stopCameraStream()
        session?.stop()
        session = nil
    }

    private func waitUntilStarted(_ session: DeviceSession) async throws {
        if session.state == .started { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await state in session.stateStream() {
                    try Task.checkCancellation()
                    if state == .started { return }
                    if state == .stopped {
                        throw Self.failure(
                            code: MetaDATStreamBridge.kodikosSessionApotyxia,
                            message: "Το Meta DAT session σταμάτησε πριν ξεκινήσει."
                        )
                    }
                }
                throw Self.failure(
                    code: MetaDATStreamBridge.kodikosSessionApotyxia,
                    message: "Η ροή κατάστασης του Meta DAT session τερματίστηκε πριν ξεκινήσει."
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw Self.failure(
                    code: MetaDATStreamBridge.kodikosSessionStartTimedOut,
                    message: "Το Meta DAT session δεν ξεκίνησε μέσα σε 30 δευτερόλεπτα."
                )
            }
            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }

    private func sessionHandle(for session: DeviceSession) -> MetaDATStreamBridge.LiveSessionHandle {
        let device = session.device
        return MetaDATStreamBridge.LiveSessionHandle(
            deviceName: device?.nameOrId() ?? "Meta glasses",
            batteryPercent: device?.batteryLevel,
            supportsCompressedHEVC: false,
            isSimulationLabeled: false
        )
    }

    private static func failure(code: Int, message: String) -> NSError {
        NSError(
            domain: MetaDATStreamBridge.errorDomain,
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func failure(code: Int, message: String) -> NSError {
        Self.failure(code: code, message: message)
    }
}

/// Pull adapter over the DAT publisher. It has a small bounded queue; if the
/// consumer cannot keep up, the camera is stopped and the loss is surfaced.
private final class MetaDATVideoFrameBuffer: @unchecked Sendable {
    private static let capacity = 2

    private let continuation: AsyncThrowingStream<BufferedSample, Error>.Continuation
    private let reader: MetaDATVideoFrameReader
    private let onFailure: @Sendable (String) -> Void
    private let lock = NSLock()
    private var isFinished = false
    let id: UUID

    init(id: UUID, onFailure: @escaping @Sendable (String) -> Void) {
        self.id = id
        self.onFailure = onFailure
        var streamContinuation: AsyncThrowingStream<BufferedSample, Error>.Continuation?
        let stream = AsyncThrowingStream<BufferedSample, Error>(bufferingPolicy: .bufferingOldest(Self.capacity)) {
            streamContinuation = $0
        }
        self.continuation = streamContinuation!
        self.reader = MetaDATVideoFrameReader(stream: stream)
    }

    func next() async throws -> BufferedSample? {
        try await reader.next()
    }

    func enqueue(_ sample: BufferedSample) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        switch continuation.yield(sample) {
        case .enqueued:
            lock.unlock()
        case .dropped:
            isFinished = true
            lock.unlock()
            fail("Η DAT frame queue γέμισε· η κάμερα σταμάτησε χωρίς σιωπηλή απώλεια καρέ.")
        case .terminated:
            isFinished = true
            lock.unlock()
        @unknown default:
            isFinished = true
            lock.unlock()
            fail("Η DAT frame queue τερματίστηκε απροσδόκητα.")
        }
    }

    var isTerminated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isFinished
    }

    func finish(errorMessage: String? = nil) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        lock.unlock()

        if let errorMessage {
            continuation.finish(throwing: makeFailure(errorMessage))
            onFailure(errorMessage)
        } else {
            continuation.finish()
        }
    }

    private func fail(_ message: String) {
        continuation.finish(throwing: makeFailure(message))
        onFailure(message)
    }

    private func makeFailure(_ message: String) -> NSError {
        NSError(
            domain: MetaDATStreamBridge.errorDomain,
            code: MetaDATStreamBridge.kodikosCameraUnavailable,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private actor MetaDATVideoFrameReader {
    private var iterator: AsyncThrowingStream<BufferedSample, Error>.Iterator

    init(stream: AsyncThrowingStream<BufferedSample, Error>) {
        self.iterator = stream.makeAsyncIterator()
    }

    func next() async throws -> BufferedSample? {
        // A mutating async call cannot take actor-isolated storage inout, so advance a local copy.
        // The iterator only wraps the shared stream storage, and this actor is its single consumer.
        var currentIterator = iterator
        defer { iterator = currentIterator }
        return try await currentIterator.next()
    }
}

private actor MetaDATStreamStartGate {
    private var didBegin = false
    private var didStart = false
    private var failure: Error?
    private var waiter: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    func observe(_ state: StreamState) {
        switch state {
        case .waitingForDevice, .starting, .paused, .stopping:
            didBegin = true
        case .streaming:
            didBegin = true
            didStart = true
            resolve(with: .success(()))
        case .stopped:
            if didBegin, !didStart {
                resolve(with: .failure(makeFailure("Το DAT camera stream σταμάτησε πριν αρχίσει.")))
            }
        }
    }

    func waitUntilStreaming() async throws {
        if didStart { return }
        if let failure { throw failure }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard waiter == nil else {
                    continuation.resume(throwing: makeFailure("Υπάρχει ήδη αναμονή για εκκίνηση DAT camera stream."))
                    return
                }
                waiter = continuation
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    guard !Task.isCancelled else { return }
                    await self?.timeout()
                }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func cancel() {
        guard !didStart else { return }
        resolve(with: .failure(CancellationError()))
    }

    private func timeout() {
        guard !didStart else { return }
        resolve(with: .failure(makeFailure("Το DAT camera stream δεν έφτασε σε κατάσταση streaming μέσα σε 15 δευτερόλεπτα.")))
    }

    private func resolve(with result: Result<Void, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        let currentWaiter = waiter
        waiter = nil
        switch result {
        case .success:
            didStart = true
            currentWaiter?.resume()
        case .failure(let error):
            failure = error
            currentWaiter?.resume(throwing: error)
        }
    }

    private func makeFailure(_ message: String) -> NSError {
        NSError(
            domain: MetaDATStreamBridge.errorDomain,
            code: MetaDATStreamBridge.kodikosCameraUnavailable,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

/// Ignores the initial `.stopped` state before `stream.start()`, then treats a
/// later stop as a terminal event for the current frame queue.
private final class MetaDATStreamLifecycleObserver: @unchecked Sendable {
    private let lock = NSLock()
    private var didBegin = false

    func shouldTerminate(for state: StreamState) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        switch state {
        case .waitingForDevice, .starting, .streaming, .paused, .stopping:
            didBegin = true
            return false
        case .stopped:
            return didBegin
        }
    }
}
#endif
