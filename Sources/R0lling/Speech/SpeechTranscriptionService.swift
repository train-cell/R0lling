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
    public private(set) var isListening: Bool = false

    private let parser = VoiceCommandParser()
    private var commandHandler: (@Sendable (VoiceCommandType) -> Void)?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var accumulatedTranscript: String = ""
    /// Αποτρέπει διπλό dispatch (final callback + stopListening).
    private var didDispatchCommandThisUtterance: Bool = false
    private let stateLock = NSLock()

    public init() {}

    public func setCommandHandler(_ handler: @escaping @Sendable (VoiceCommandType) -> Void) {
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
                throw NSError(
                    domain: "R0lling.Speech",
                    code: 5001,
                    userInfo: [NSLocalizedDescriptionKey: "Η αναγνώριση ομιλίας δεν είναι διαθέσιμη στη συσκευή."]
                )
            }
            speechRecognizer = fallback
        }

        guard let recognizer = speechRecognizer else {
            throw NSError(
                domain: "R0lling.Speech",
                code: 5001,
                userInfo: [NSLocalizedDescriptionKey: "Η αναγνώριση ομιλίας δεν είναι διαθέσιμη στη συσκευή."]
            )
        }

        parser.resetDedup()
        accumulatedTranscript = ""
        didDispatchCommandThisUtterance = false
        isListening = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        // On-device όταν διαθέσιμο — μειώνει cloud leakage· όχι Meta path.
        if #available(iOS 13, macOS 10.15, *) {
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.accumulatedTranscript = result.bestTranscription.formattedString
                // A04: ΜΟΝΟ final — ποτέ command από partial (αποφυγή πολλαπλών notes).
                if result.isFinal {
                    self.dispatchCommandIfNeeded(from: self.accumulatedTranscript)
                    self.tearDownEnginePreservingTranscript()
                }
            }

            if error != nil {
                self.tearDownEnginePreservingTranscript()
            }
        }
    }

    /// Σταματά ακρόαση. Επιστρέφει `commandHandled` αν ήδη δρομολογήθηκε εντολή (όχι δεύτερο addNote).
    @discardableResult
    public func stopListening() -> SpeechStopResult {
        stateLock.lock()
        let wasListening = isListening
        let transcript = accumulatedTranscript
        let alreadyDispatched = didDispatchCommandThisUtterance
        stateLock.unlock()

        guard wasListening || !transcript.isEmpty else { return .empty }

        tearDownEnginePreservingTranscript()

        if alreadyDispatched {
            return .commandHandled(.unknown(raw: transcript))
        }

        // nil = κενό ή R3-006 dedup → ποτέ δεύτερη σημείωση (A04).
        guard let command = parser.parse(transcript: transcript) else {
            return .empty
        }

        switch command {
        case .unknown(let raw):
            return raw.isEmpty ? .empty : .dictation(raw)
        default:
            didDispatchCommandThisUtterance = true
            commandHandler?(command)
            return .commandHandled(command)
        }
    }

    // MARK: - Private

    private func dispatchCommandIfNeeded(from transcript: String) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !didDispatchCommandThisUtterance else { return }
        guard let command = parser.parse(transcript: transcript) else { return }

        switch command {
        case .unknown:
            // Dictation: αποθήκευση στο stopListening / UI toggle — όχι εδώ.
            break
        default:
            didDispatchCommandThisUtterance = true
            commandHandler?(command)
        }
    }

    private func tearDownEnginePreservingTranscript() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
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
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }
}
