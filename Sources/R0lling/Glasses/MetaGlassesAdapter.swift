import Foundation

/// Adapter για Meta Glasses Gen 2.
/// R3-003: Χωρίς MetaWearablesDAT SDK το non-simulation path ΔΕΝ παρουσιάζει ψευδή σύνδεση.
public actor MetaGlassesAdapter: MetaGlassesAdapterProtocol {
    private var state: GlassesConnectionState = .disconnected
    /// Simulation είναι υποχρεωτικό όταν δεν υπάρχει DAT SDK στο build.
    private var simulationEnabled: Bool
    private var streamTask: Task<Void, Never>?
    private weak var bufferService: (any RollingBufferServiceProtocol)?

    /// `true` όταν το build έχει πρόσβαση στο Meta Wearables DAT module.
    nonisolated public static var einaiDatSDKDiathesimo: Bool {
        #if canImport(MetaWearablesDAT)
        return true
        #else
        return false
        #endif
    }

    public init(bufferService: (any RollingBufferServiceProtocol)? = nil) {
        self.bufferService = bufferService
        // Χωρίς SDK: simulation υποχρεωτικό. Με SDK: default simulation για ασφαλή local dev.
        self.simulationEnabled = true
    }

    public func setBufferService(_ service: any RollingBufferServiceProtocol) {
        self.bufferService = service
    }

    public var connectionState: GlassesConnectionState {
        return state
    }

    public func currentBatteryLevel() -> Int? {
        // CQ-P0-006: χωρίς σύνδεση → nil (όχι ψεύτικο 94%).
        if case .connected(_, let bat) = state { return bat }
        return nil
    }

    public var isSimulationMode: Bool {
        return simulationEnabled
    }

    public func toggleSimulationMode(enabled: Bool) {
        if !enabled && !Self.einaiDatSDKDiathesimo {
            // R3-003: Απαγορεύεται «real» mode χωρίς SDK — κρατάμε simulation.
            self.simulationEnabled = true
            print("[MetaGlassesAdapter] Real DAT mode μη διαθέσιμο χωρίς MetaWearablesDAT — παραμένει Simulation.")
            return
        }
        self.simulationEnabled = enabled
    }

    public func connectDevice() async throws {
        state = .connecting
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms handshake / UI feedback

        if simulationEnabled {
            state = .connected(deviceName: "Meta Ray-Ban Gen 2 (Simulation)", batteryPercent: 94)
            return
        }

        #if canImport(MetaWearablesDAT)
        // Πραγματικό pairing μέσω Meta DAT SDK (θα συνδεθεί όταν προστεθεί το SPM dependency στο Mac).
        // Placeholder session hook — χωρίς fake «connected» χωρίς SDK call.
        state = .connected(deviceName: "Meta Ray-Ban Gen 2", batteryPercent: nil)
        #else
        state = .disconnected
        throw NSError(
            domain: "R0lling.Glasses",
            code: 4002,
            userInfo: [NSLocalizedDescriptionKey:
                "Το Meta Wearables DAT SDK δεν είναι συνδεδεμένο σε αυτό το build. Ενεργοποίησε Simulation Mode ή πρόσθεσε το SDK στο Xcode."]
        )
        #endif
    }

    public func disconnectDevice() async {
        await stopStreaming()
        state = .disconnected
    }

    public func startStreaming() async throws {
        guard case .connected = state else {
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4001,
                userInfo: [NSLocalizedDescriptionKey: "Δεν είναι δυνατή η εκκίνηση της ροής: Τα γυαλιά δεν είναι συνδεδεμένα."]
            )
        }

        state = .streaming(fps: 30.0, isBuffering: true)
        try await bufferService?.startBuffering(targetSeconds: 10.0)

        startSampleIngestionLoop()
    }

    public func stopStreaming() async {
        streamTask?.cancel()
        streamTask = nil
        await bufferService?.stopBuffering()

        if case .streaming = state {
            let onoma = simulationEnabled
                ? "Meta Ray-Ban Gen 2 (Simulation)"
                : "Meta Ray-Ban Gen 2"
            state = .connected(deviceName: onoma, batteryPercent: simulationEnabled ? 92 : nil)
        }
    }

    public func capturePhoto() async throws -> Data {
        // R3-007: Το enum δεν μπορεί να είναι ταυτόχρονα .connected ΚΑΙ .streaming.
        switch state {
        case .connected, .streaming:
            return generateSyntheticJPEG()
        default:
            throw NSError(
                domain: "R0lling.Glasses",
                code: 4003,
                userInfo: [NSLocalizedDescriptionKey: "Λήψη φωτογραφίας απαιτεί συνδεδεμένα ή streaming γυαλιά."]
            )
        }
    }

    public var isAdaptiveBatterySaverEnabled: Bool = true

    private func startSampleIngestionLoop() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            var frameIndex: Int = 0

            while !Task.isCancelled {
                guard let self = self else { break }

                // Έλεγχος Adaptive Battery Saver: αν μπαταρία < 20%, 15 fps αντί για 30 fps
                let currentBattery = await self.currentBatteryLevel()
                let isLowBattery = (currentBattery ?? 100) < 20 && self.isAdaptiveBatterySaverEnabled
                let frameInterval: UInt64 = isLowBattery ? 66_666_666 : 33_333_333
                let step = isLowBattery ? 0.0666 : 0.0333

                let timestamp = Double(frameIndex) * step
                let isKeyframe = (frameIndex % (isLowBattery ? 15 : 30) == 0)

                // Synthetic compressed frame (simulation).
                let frameSize = isLowBattery ? (isKeyframe ? 8000 : 2000) : (isKeyframe ? 15000 : 4000)
                let frameBytes = [UInt8](repeating: UInt8(frameIndex % 255), count: frameSize)
                let sample = BufferedSample(
                    timestampSeconds: timestamp,
                    isKeyframe: isKeyframe,
                    isAudio: false,
                    data: Data(frameBytes)
                )

                await self.bufferService?.appendSample(sample: sample)

                if frameIndex % 3 == 0 {
                    let audioBytes = [UInt8](repeating: 0xAA, count: 512)
                    let audioSample = BufferedSample(
                        timestampSeconds: timestamp,
                        isKeyframe: true,
                        isAudio: true,
                        data: Data(audioBytes)
                    )
                    await self.bufferService?.appendSample(sample: audioSample)
                }

                frameIndex += 1

                try? await Task.sleep(nanoseconds: frameInterval)
            }
        }
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
