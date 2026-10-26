import Foundation

/// Adapter για Meta Glasses Gen 2.
/// R3-003: Το non-simulation path μένει κλειστό μέχρι να ολοκληρωθεί και να επικυρωθεί η camera/media ροή.
/// A06: disconnect / interrupt → clear buffer + νέα generation.
/// A07: background/lock → PAUSED + honest UI message (όχι continuous capture χωρίς proof).
/// Simulation may emit synthetic acoustic/IMU samples to the sink; live DAT callbacks are not wired, and product triggers stay gated off.
public actor MetaGlassesAdapter: MetaGlassesAdapterProtocol {
    private var state: GlassesConnectionState = .disconnected
    /// Simulation είναι υποχρεωτικό όταν δεν υπάρχει DAT SDK στο build.
    private var simulationEnabled: Bool
    private var streamTask: Task<Void, Never>?
    private weak var bufferService: (any RollingBufferServiceProtocol)?
    private weak var sensorFeedSink: (any GlassesSensorFeedSink)?
    private var bufferTargetSeconds: Double
    private var policy: GlassesReconnectPolicy = .proepilogiR0lling
    /// Θυμάται αν έτρεχε streaming πριν το background pause (για auto-resume).
    private var itanStreamingPrinPause: Bool = false
    private var reconnectAttempts: Int = 0
    private var lastDATFrameTimestamp: Double?
    private var datFrameIntervals: [Double] = []
    /// Invalidates an in-flight connection when it is cancelled or disconnected.
    private var connectionAttemptGeneration: UInt64 = 0

    /// `true` όταν το build έχει πρόσβαση στο Meta Wearables DAT module.
    nonisolated public static var einaiDatSDKDiathesimo: Bool {
        MetaDATStreamBridge.einaiSDKDiathesimo
    }

    public init(
        bufferService: (any RollingBufferServiceProtocol)? = nil,
        initialBufferTargetSeconds: Double = 10.0
    ) {
        self.bufferService = bufferService
        self.bufferTargetSeconds = Self.normalizedBufferTarget(initialBufferTargetSeconds)
        // Χωρίς SDK: simulation υποχρεωτικό. Με SDK: default simulation για ασφαλή local dev.
        self.simulationEnabled = true
    }

    /// Shared with the Today clip labels so they show the same 5s/10s window the stream uses.
    static func normalizedBufferTarget(_ seconds: Double) -> Double {
        guard seconds.isFinite else { return 10.0 }
        return seconds < 7.5 ? 5.0 : 10.0
    }

    public func setBufferService(_ service: any RollingBufferServiceProtocol) {
        self.bufferService = service
    }

    /// The selected rolling window is applied on the next stream start.
    public var configuredBufferTargetSeconds: Double {
        bufferTargetSeconds
    }

    public func setBufferTargetSeconds(_ seconds: Double) {
        bufferTargetSeconds = Self.normalizedBufferTarget(seconds)
    }

    public var connectionState: GlassesConnectionState {
        return state
    }

    public var reconnectPolicy: GlassesReconnectPolicy {
        return policy
    }

    public func setReconnectPolicy(_ policy: GlassesReconnectPolicy) {
        self.policy = policy
    }

    public func setSensorFeedSink(_ sink: (any GlassesSensorFeedSink)?) {
        self.sensorFeedSink = sink
    }

    public func currentBatteryLevel() -> Int? {
        // CQ-P0-006: χωρίς σύνδεση → nil (όχι ψεύτικο 94%).
        switch state {
        case .connected(_, let bat):
            return bat
        case .streaming:
            return nil
        case .paused:
            return nil
        default:
            return nil
        }
    }

    public var isSimulationMode: Bool {
        return simulationEnabled
    }

    public func toggleSimulationMode(enabled: Bool) {
        guard state == .disconnected else { return }
        if !enabled && !MetaDATStreamBridge.einaiLiveYlopoiimeno {
            // R3-003: Κρατάμε simulation μέχρι να ολοκληρωθεί και να επικυρωθεί το live path.
            self.simulationEnabled = true
            print("[MetaGlassesAdapter] Live DAT camera/media path remains gated — παραμένει Simulation.")
            return
        }
        self.simulationEnabled = enabled
    }

    public func connectDevice() async throws {
        R0llingTelemetry.shared.log(.glasses, stathmi: .info, "Έναρξη διαδικασίας σύνδεσης Meta Glasses (simulation=\(simulationEnabled))")
        connectionAttemptGeneration &+= 1
        let attemptGeneration = connectionAttemptGeneration
        state = .connecting
        do {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 300_000_000) // 300ms handshake / UI feedback
            try Task.checkCancellation()
            guard connectionAttemptGeneration == attemptGeneration else {
                throw CancellationError()
            }

            if simulationEnabled {
                // ΡΗΤΑ labeled simulation — όχι ψευδής hardware σύνδεση ούτε επινοημένη μπαταρία.
                state = .connected(
                    deviceName: "Meta Ray-Ban Gen 2 (SIMULATION — όχι φυσική συσκευή)",
                    batteryPercent: nil
                )
                reconnectAttempts = 0
                return
            }

            #if canImport(MWDATCore) && canImport(MWDATCamera)
            let session = try await MetaDATStreamBridge.anoixeLiveSession()
            try Task.checkCancellation()
            guard connectionAttemptGeneration == attemptGeneration else {
                throw CancellationError()
            }
            state = .connected(
                deviceName: session.deviceName,
                batteryPercent: session.batteryPercent
            )
            reconnectAttempts = 0
            #else
            state = .disconnected
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4002,
                userInfo: [NSLocalizedDescriptionKey:
                    "Το Meta Wearables DAT SDK δεν είναι διαθέσιμο σε αυτό το build. Χρειάζεται συμβατό iOS build ή ενεργοποίησε Simulation Mode."]
            )
            #endif
        } catch {
            // A cancelled/stale attempt must not overwrite a newer connection attempt.
            if connectionAttemptGeneration == attemptGeneration {
#if canImport(MWDATCore) && canImport(MWDATCamera)
                if !simulationEnabled {
                    await MetaDATStreamBridge.kleiseLiveSession()
                }
#endif
                state = error is CancellationError ? .disconnected : .error(error.localizedDescription)
            }
            throw error
        }
    }

    public func disconnectDevice() async {
        R0llingTelemetry.shared.log(.glasses, stathmi: .info, "Αποσύνδεση Meta Glasses")
        connectionAttemptGeneration &+= 1
        await stopStreaming()
        if policy.clearBufferOnDisconnect {
            await bufferService?.markStreamInterrupted(reason: "disconnect")
        }
        await MetaDATStreamBridge.kleiseLiveSession()
        itanStreamingPrinPause = false
        state = .disconnected
    }

    public func requestCameraPermissionAfterUserConfirmation() async throws {
        guard !simulationEnabled else { return }
        guard MetaDATStreamBridge.einaiLiveYlopoiimeno else {
            throw NSError(
                domain: MetaDATStreamBridge.errorDomain,
                code: MetaDATStreamBridge.kodikosSessionApotyxia,
                userInfo: [NSLocalizedDescriptionKey: "Το live DAT camera path παραμένει κλειστό."]
            )
        }
        try await MetaDATStreamBridge.zitaCameraPermissionMetaAIHandoff()
    }

    public func startStreaming() async throws {
        switch state {
        case .connected, .paused:
            break
        case .streaming:
            return
        default:
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Δεν είναι δυνατή η εκκίνηση της ροής: Τα γυαλιά δεν είναι συνδεδεμένα."]
            )
        }

        if !simulationEnabled {
            #if canImport(MWDATCore) && canImport(MWDATCamera)
            guard MetaDATStreamBridge.einaiLiveYlopoiimeno else {
                throw NSError(
                    domain: MetaDATStreamBridge.errorDomain,
                    code: MetaDATStreamBridge.kodikosSessionApotyxia,
                    userInfo: [NSLocalizedDescriptionKey: "Το live DAT stream hook δεν είναι υλοποιημένο."]
                )
            }
            // connectDevice already owns the live session. Do not open a second session here.
            #else
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4002,
                userInfo: [NSLocalizedDescriptionKey: "Το live stream απαιτεί τα MWDATCore + MWDATCamera σε συμβατό iOS build ή ενεργή Simulation Mode."]
            )
            #endif
        }

        try await bufferService?.startBuffering(targetSeconds: bufferTargetSeconds)

        do {
            if simulationEnabled {
                state = .streaming(fps: 30.0, isBuffering: true)
                itanStreamingPrinPause = true
                startSimulationIngestionLoop()
            } else {
                try await MetaDATStreamBridge.arxiseLiveCameraStream()
                lastDATFrameTimestamp = nil
                datFrameIntervals.removeAll(keepingCapacity: true)
                state = .streaming(fps: 0.0, isBuffering: true)
                itanStreamingPrinPause = true
                startDATIngestionLoop()
            }
        } catch {
            await bufferService?.stopBuffering()
            await MetaDATStreamBridge.stamataLiveCameraStream()
            throw error
        }
    }

    public func stopStreaming() async {
        streamTask?.cancel()
        streamTask = nil
        lastDATFrameTimestamp = nil
        datFrameIntervals.removeAll(keepingCapacity: true)
        if !simulationEnabled {
            await MetaDATStreamBridge.stamataLiveCameraStream()
        }
        await bufferService?.stopBuffering()
        itanStreamingPrinPause = false

        if case .streaming = state {
            let onoma = simulationEnabled
                ? "Meta Ray-Ban Gen 2 (SIMULATION — όχι φυσική συσκευή)"
                : "Meta Ray-Ban Gen 2"
            state = .connected(deviceName: onoma, batteryPercent: nil)
        } else if case .paused = state {
            let onoma = simulationEnabled
                ? "Meta Ray-Ban Gen 2 (SIMULATION — όχι φυσική συσκευή)"
                : "Meta Ray-Ban Gen 2"
            state = .connected(deviceName: onoma, batteryPercent: nil)
        }
    }

    /// A07: background / lock / foreground lifecycle.
    public func handleAppLifecycle(_ event: GlassesAppLifecycleEvent) async -> GlassesLifecycleOutcome {
        let isStreamingNow: Bool
        if case .streaming = state {
            isStreamingNow = true
        } else {
            isStreamingNow = false
        }

        let outcome = GlassesLifecyclePolicy.apofasiGia(
            event: event,
            isCurrentlyStreaming: isStreamingNow || (itanStreamingPrinPause && state.isPaused),
            policy: policy
        )

        switch event {
        case .willEnterBackground, .willResignActiveForLock:
            if isStreamingNow {
                streamTask?.cancel()
                streamTask = nil
                await bufferService?.pauseBuffering()
                if policy.clearBufferOnBackgroundPause {
                    await bufferService?.clearBuffer()
                    await bufferService?.markStreamInterrupted(reason: "background_or_lock")
                }
                if !simulationEnabled {
                    await MetaDATStreamBridge.kleiseLiveSession()
                }
                let reason = event == .willEnterBackground ? "background" : "lock"
                state = .paused(reason: reason)
            } else if !simulationEnabled, case .connected = state {
                // DAT sessions are terminal after stop; reconnect on the next user action.
                await MetaDATStreamBridge.kleiseLiveSession()
                state = .disconnected
            } else if !simulationEnabled, case .connecting = state {
                // Do not allow a session opened while the app is inactive to outlive A07.
                connectionAttemptGeneration &+= 1
                await MetaDATStreamBridge.kleiseLiveSession()
                state = .disconnected
            }

        case .didBecomeActive:
            if case .paused = state {
                if simulationEnabled {
                    state = .connected(
                        deviceName: "Meta Ray-Ban Gen 2 (SIMULATION — όχι φυσική συσκευή)",
                        batteryPercent: nil
                    )
                } else {
                    guard policy.autoResumeStreamOnForeground && itanStreamingPrinPause else {
                        itanStreamingPrinPause = false
                        state = .disconnected
                        return outcome
                    }
                    do {
                        let session = try await MetaDATStreamBridge.anoixeLiveSession()
                        state = .connected(
                            deviceName: session.deviceName,
                            batteryPercent: session.batteryPercent
                        )
                    } catch {
                        itanStreamingPrinPause = false
                        state = .error("Auto-resume session απέτυχε: \(error.localizedDescription)")
                        return outcome
                    }
                }

                if policy.autoResumeStreamOnForeground && itanStreamingPrinPause {
                    do {
                        try await startStreaming()
                    } catch {
                        state = .error("Auto-resume απέτυχε: \(error.localizedDescription)")
                    }
                }
            }
        }

        return outcome
    }

    public func capturePhoto() async throws -> Data {
        // R3-007: Το enum δεν μπορεί να είναι ταυτόχρονα .connected ΚΑΙ .streaming.
        switch state {
        case .connected, .streaming, .paused:
            if simulationEnabled {
                return generateSyntheticJPEG()
            }
            #if canImport(MWDATCore) && canImport(MWDATCamera)
            throw NSError(domain: MetaDATStreamBridge.errorDomain, code: 4011, userInfo: [
                NSLocalizedDescriptionKey: "Η πραγματική λήψη φωτογραφίας DAT δεν έχει υλοποιηθεί."
            ])
            #else
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4003,
                userInfo: [NSLocalizedDescriptionKey: "Λήψη φωτογραφίας χωρίς DAT/simulation μη διαθέσιμη."]
            )
            #endif
        default:
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4003,
                userInfo: [NSLocalizedDescriptionKey: "Λήψη φωτογραφίας απαιτεί συνδεδεμένα ή streaming γυαλιά."]
            )
        }
    }

    public var isAdaptiveBatterySaverEnabled: Bool = true

    // MARK: - Simulation ingestion (ΡΗΤΑ labeled)

    private func startSimulationIngestionLoop() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            var frameIndex: Int = 0

            while !Task.isCancelled {
                guard let self = self else { break }

                let currentBattery = await self.currentBatteryLevel()
                let batterySaver = await self.isAdaptiveBatterySaverEnabled
                let isLowBattery = (currentBattery ?? 100) < 20 && batterySaver
                let frameInterval: UInt64 = isLowBattery ? 66_666_666 : 33_333_333
                let step = isLowBattery ? 0.0666 : 0.0333
                let generation = await self.bufferService?.streamGeneration ?? 0

                let timestamp = Double(frameIndex) * step
                let isKeyframe = (frameIndex % (isLowBattery ? 15 : 30) == 0)

                // Synthetic compressed frame — ΟΧΙ πραγματικό H.264 NAL (χωρίς start codes).
                let frameSize = isLowBattery ? (isKeyframe ? 8000 : 2000) : (isKeyframe ? 15000 : 4000)
                let frameBytes = [UInt8](repeating: UInt8(frameIndex % 255), count: frameSize)
                let sample = BufferedSample(
                    timestampSeconds: timestamp,
                    isKeyframe: isKeyframe,
                    isAudio: false,
                    data: Data(frameBytes),
                    streamGeneration: generation
                )
                await self.bufferService?.appendSample(sample: sample)

                if frameIndex % 3 == 0 {
                    let audioBytes = [UInt8](repeating: 0xAA, count: 512)
                    let audioSample = BufferedSample(
                        timestampSeconds: timestamp,
                        isKeyframe: true,
                        isAudio: true,
                        data: Data(audioBytes),
                        streamGeneration: generation
                    )
                    await self.bufferService?.appendSample(sample: audioSample)
                }

                // Feed API end-to-end: synthetic acoustic + IMU (triggers gated στο AppState).
                await self.steileSensorFeeds(frameIndex: frameIndex, timestamp: timestamp)

                frameIndex += 1
                try? await Task.sleep(nanoseconds: frameInterval)
            }
        }
    }

    // MARK: - DAT ingestion (real path structure)

    private func startDATIngestionLoop() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                do {
                    if let video = try await MetaDATStreamBridge.diavaseEpomenoVideoFrame() {
                        await self.recordDATFrameTimestamp(video.timestampSeconds)
                        let generation = await self.bufferService?.streamGeneration ?? 0
                        let tagged = BufferedSample(
                            timestampSeconds: video.timestampSeconds,
                            isKeyframe: video.isKeyframe,
                            isAudio: false,
                            data: video.data,
                            streamGeneration: generation
                        )
                        await self.bufferService?.appendSample(sample: tagged)
                    }
                } catch {
                    // Σε DAT frame error: προσπάθεια reconnect κατά policy, αλλιώς paused/error.
                    let attempts = await self.reconnectAttempts
                    let maxAttempts = await self.policy.maxReconnectAttempts
                    if attempts < maxAttempts {
                        await self.auxIncreaseReconnect()
                        let delay = await self.policy.reconnectDelayNanoseconds
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    await self.bufferService?.markStreamInterrupted(reason: "dat_stream_lost")
                    await self.auxSetError("DAT stream χάθηκε: \(error.localizedDescription)")
                    break
                }
                try? await Task.sleep(nanoseconds: 8_000_000)
            }
        }
    }

    private func auxIncreaseReconnect() {
        reconnectAttempts += 1
    }

    private func recordDATFrameTimestamp(_ timestamp: Double) {
        guard timestamp.isFinite else { return }
        if let previousTimestamp = lastDATFrameTimestamp {
            let interval = timestamp - previousTimestamp
            if interval > 0, interval <= 1.0 {
                datFrameIntervals.append(interval)
                if datFrameIntervals.count > 12 { datFrameIntervals.removeFirst() }
            } else {
                datFrameIntervals.removeAll(keepingCapacity: true)
            }
        }
        lastDATFrameTimestamp = timestamp

        guard !datFrameIntervals.isEmpty,
              case .streaming(_, let isBuffering) = state else { return }
        let totalInterval = datFrameIntervals.reduce(0, +)
        guard totalInterval > 0 else { return }
        state = .streaming(
            fps: Double(datFrameIntervals.count) / totalInterval,
            isBuffering: isBuffering
        )
    }

    private func auxSetError(_ message: String) {
        state = .error(message)
        itanStreamingPrinPause = false
    }

    private func steileSensorFeeds(frameIndex: Int, timestamp: Double) {
        guard let sink = sensorFeedSink else { return }

        // Synthetic mic: ήσυχο ambient με περιστασιακό spike κάθε ~5s (για feed path proof).
        let ambient: Float = -35.0
        let spike: Float = frameIndex % 150 == 0 ? -8.0 : ambient
        sink.receiveAcousticLevel(decibels: spike)

        // Synthetic IMU: μικρή ταλάντωση pitch (όχι auto double-nod χωρίς έντονο πλάτος).
        let pitch = 0.05 * sin(timestamp * 2.0)
        let imu = HeadGestureDetector.IMUSample(
            pitch: pitch,
            roll: 0.0,
            yaw: 0.0,
            timestamp: timestamp
        )
        sink.receiveIMUSample(imu)
    }

    private func generateSyntheticJPEG() -> Data {
        // Ελάχιστο έγκυρο 1x1 JPEG για simulation / fallback
        return Data([
            0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
            0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
            0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
            0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
            0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
            0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
            0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
            0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
            0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
            0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
            0x00, 0xBF, 0x80, 0xFF, 0xD9
        ])
    }
}
