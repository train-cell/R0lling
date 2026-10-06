import Foundation
import Speech
import AVFAudio

public protocol SpeechTranscriptionServiceProtocol: AnyObject, Sendable {
    var isListening: Bool { get }
    func startListening(localeIdentifier: String) async throws
    func stopListening() async -> String?
    func setCommandHandler(_ handler: @escaping @Sendable (VoiceCommandType) -> Void)
}

/// Υπηρεσία μετατροπής ομιλίας σε κείμενο μέσω Apple Speech Framework με υποστήριξη Ελληνικών (el-GR)
public final class SpeechTranscriptionService: SpeechTranscriptionServiceProtocol, @unchecked Sendable {
    public private(set) var isListening: Bool = false
    private let parser = VoiceCommandParser()
    private var commandHandler: (@Sendable (VoiceCommandType) -> Void)?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var accumulatedTranscript: String = ""

    public init() {}

    public func setCommandHandler(_ handler: @escaping @Sendable (VoiceCommandType) -> Void) {
        self.commandHandler = handler
    }

    public func startListening(localeIdentifier: String = "el-GR") throws {
        guard !isListening else { return }

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            // Fallback σε en-US αν δεν είναι διαθέσιμο το el-GR
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            guard let fallback = speechRecognizer, fallback.isAvailable else {
                throw NSError(domain: "R0lling.Speech", code: 5001, userInfo: [NSLocalizedDescriptionKey: "Η αναγνώριση ομιλίας δεν είναι διαθέσιμη στη συσκευή."])
            }
            return
        }

        accumulatedTranscript = ""
        isListening = true

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.accumulatedTranscript = result.bestTranscription.formattedString

                // Αν εντοπιστεί ρητή εντολή στο partial ή final αποτέλεσμα
                if let command = self.parser.parse(transcript: self.accumulatedTranscript) {
                    if result.isFinal {
                        self.commandHandler?(command)
                    }
                }
            }

            if error != nil || result?.isFinal == true {
                Task {
                    await self.stopListening()
                }
            }
        }
    }

    @discardableResult
    public func stopListening() -> String? {
        guard isListening else { return nil }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
        let finalTranscript = accumulatedTranscript

        if let command = parser.parse(transcript: finalTranscript) {
            commandHandler?(command)
        }

        return finalTranscript
    }
}
