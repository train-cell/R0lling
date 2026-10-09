import Foundation
import Speech
import AVFAudio

public protocol SpeechTranscriptionServiceProtocol: AnyObject, Sendable {
    var isListening: Bool { get }
    func startListening(localeIdentifier: String) throws
    func stopListening() -> SpeechStopResult
    func setCommandHandler(_ handler: @escaping @Sendable (VoiceCommandType) -> Void)
}

/// iOS Speech Framework (el-GR → en-US fallback). Χωρίς Meta mic / Hey Meta wake.
/// A04: εντολές μόνο σε final transcript · dedup · χωρίς διπλή σημείωση.
public final class SpeechTranscriptionService: SpeechTranscriptionServiceProtocol, @unchecked Sendable {
    private var listening = false
    public var isListening: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return listening
    }
    private var recognitionGeneration = UUID()
    private var hasInputTap = false

    private let utteranceResolver = VoiceCommandUtteranceResolver()
    private var commandHandler: (@Sendable (VoiceCommandType) -> Void)?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var accumulatedTranscript: String = ""
    private let stateLock = NSRecursiveLock()
    #if os(iOS)
    private var previousAudioSession: (
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    )?
    #endif

    public init() {}

    public func setCommandHandler(_ handler: @escaping @Sendable (VoiceCommandType) -> Void) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.commandHandler = handler
    }

    /// Ξεκινά ακρόαση iOS mic. Απαιτεί `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` στο host app.
    public func startListening(localeIdentifier: String = "el-GR") throws {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isListening else { return }

        try ensureSpeechAuthorized()
        try configureAudioSession()

        let primary = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        if let primary, primary.isAvailable {
            speechRecognizer = primary
        } else {
            let fallback = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            guard let fallback, fallback.isAvailable else {
                deactivateAudioSession()
                throw NSError(
                    domain: "R0lling.Speech",
                    code: 5001,
                    userInfo: [NSLocalizedDescriptionKey: "Η αναγνώριση ομιλίας δεν είναι διαθέσιμη στη συσκευή."]
                )
            }
            speechRecognizer = fallback
        }

        guard let recognizer = speechRecognizer else {
            deactivateAudioSession()
            throw NSError(
                domain: "R0lling.Speech",
                code: 5001,
                userInfo: [NSLocalizedDescriptionKey: "Η αναγνώριση ομιλίας δεν είναι διαθέσιμη στη συσκευή."]
            )
        }

        utteranceResolver.beginUtterance()
        accumulatedTranscript = ""
        listening = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // Fail closed rather than silently sending dictation to Apple servers.
        guard recognizer.supportsOnDeviceRecognition else {
            listening = false
            deactivateAudioSession()
            throw NSError(domain: "R0lling.Speech", code: 5004, userInfo: [
                NSLocalizedDescriptionKey: "Η τοπική αναγνώριση ομιλίας δεν υποστηρίζεται για αυτή τη γλώσσα/συσκευή."
            ])
        }
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        if hasInputTap { inputNode.removeTap(onBus: 0); hasInputTap = false }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        hasInputTap = true

        audioEngine.prepare()
        do { try audioEngine.start() }
        catch {
            tearDownEnginePreservingTranscript()
            throw error
        }
        recognitionGeneration = UUID()
        let generation = recognitionGeneration

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            self.stateLock.lock()
            defer { self.stateLock.unlock() }
            guard generation == self.recognitionGeneration else { return }

            if let result = result {
                self.accumulatedTranscript = result.bestTranscription.formattedString
                // A04: ΜΟΝΟ final — ποτέ command από partial (αποφυγή πολλαπλών notes).
                if result.isFinal {
                    if let command = self.utteranceResolver.processFinalTranscript(self.accumulatedTranscript) {
                        self.commandHandler?(command)
                    }
                    self.tearDownEnginePreservingTranscript()
                }
            }

            if error != nil && self.listening {
                self.tearDownEnginePreservingTranscript()
            }
        }
    }

    /// Σταματά ακρόαση. Επιστρέφει το αποθηκευμένο final result ή αναλύει μία φορά το τελευταίο transcript.
    @discardableResult
    public func stopListening() -> SpeechStopResult {
        stateLock.lock()
        defer { stateLock.unlock() }
        let wasListening = listening
        let transcript = accumulatedTranscript
        guard wasListening || !transcript.isEmpty else { return .empty }

        tearDownEnginePreservingTranscript()
        let resolution = utteranceResolver.stop(transcript: transcript)
        if let command = resolution.commandToDispatch {
            commandHandler?(command)
        }
        return resolution.result
    }

    // MARK: - Private

    private func tearDownEnginePreservingTranscript() {
        stateLock.lock()
        defer { stateLock.unlock() }
        recognitionGeneration = UUID()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if hasInputTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        listening = false
        deactivateAudioSession()
    }

    private func ensureSpeechAuthorized() throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return
        case .denied, .restricted:
            throw NSError(
                domain: "R0lling.Speech",
                code: 5002,
                userInfo: [NSLocalizedDescriptionKey: "Δεν υπάρχει άδεια αναγνώρισης ομιλίας. Ενεργοποίησέ την στις Ρυθμίσεις."]
            )
        case .notDetermined:
            // Synchronous wait όχι ασφαλές στο main· ζητάμε async και αποτυγχάνουμε με σαφές μήνυμα.
            SFSpeechRecognizer.requestAuthorization { _ in }
            throw NSError(
                domain: "R0lling.Speech",
                code: 5003,
                userInfo: [NSLocalizedDescriptionKey: "Ζητήθηκε άδεια ομιλίας — πάτησε ξανά το μικρόφωνο μετά την αποδοχή."]
            )
        @unknown default:
            throw NSError(
                domain: "R0lling.Speech",
                code: 5001,
                userInfo: [NSLocalizedDescriptionKey: "Άγνωστη κατάσταση άδειας ομιλίας."]
            )
        }
    }

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if previousAudioSession == nil {
            previousAudioSession = (session.category, session.mode, session.categoryOptions)
        }
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            deactivateAudioSession()
            throw error
        }
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        if let previousAudioSession {
            try? session.setCategory(
                previousAudioSession.category,
                mode: previousAudioSession.mode,
                options: previousAudioSession.options
            )
            self.previousAudioSession = nil
        }
        #endif
    }
}
