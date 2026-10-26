import Foundation
import os

#if canImport(OSLog)
import OSLog
#endif

/// Kentriko Systima Parakolouthisis (Observability), Telemetry kai Structured Logging gia to R0lling.
/// Ylopoiei:
/// - Zero-Allocation OSLog integration gia kathe ypodyoma (UI, Storage, Glasses, AI, Obsidian, Health)
/// - Asfaleia Dedomenwn (Zero PII Logging - oute euaistheto periexomeno shmeiwsewn oute tokens)
/// - Performance Spans (Xronometrisi leitourgiwn se milliseconds)
/// - In-Memory Ring Buffer gia eksagwgi diagnwstikwn bundles (Developer Telemetry Dashboard)
public final class R0llingTelemetry: @unchecked Sendable {
    public static let shared = R0llingTelemetry()

    public static let subsystem = "com.personal.r0lling"

    // MARK: - Katigories Loggers
    public enum Katigoria: String, Sendable, CaseIterable {
        case ui = "UI"
        case journal = "Journal"
        case storage = "Storage"
        case glasses = "Glasses"
        case media = "Media"
        case ai = "AI"
        case obsidian = "Obsidian"
        case health = "Health"
        case backup = "Backup"
        case security = "Security"
    }

    public enum StathmiLog: String, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case notice = "NOTICE"
        case warning = "WARNING"
        case error = "ERROR"
        case fault = "FAULT"
    }

    /// Domi gia apothikeysi telemetry event sto in-memory ring buffer.
    public struct TelemetrySimvan: Identifiable, Sendable, Codable {
        public let id: UUID
        public let xronosigmh: Date
        public let katigoria: String
        public let stathmi: String
        public let minima: String
        public let diarkeiaMs: Double?

        public init(katigoria: Katigoria, stathmi: StathmiLog, minima: String, diarkeiaMs: Double? = nil) {
            self.id = UUID()
            self.xronosigmh = Date()
            self.katigoria = katigoria.rawValue
            self.stathmi = stathmi.rawValue
            self.minima = minima
            self.diarkeiaMs = diarkeiaMs
        }
    }

    private let kleidaria = NSLock()
    private var bufferSimvantwn: [TelemetrySimvan] = []
    private let megistoOrioBuffer = 250

    #if canImport(OSLog)
    private var osLoggers: [Katigoria: Logger] = [:]
    #endif

    private init() {
        #if canImport(OSLog)
        for kat in Katigoria.allCases {
            osLoggers[kat] = Logger(subsystem: Self.subsystem, category: kat.rawValue)
        }
        #endif
    }

    // MARK: - Katagrafi Simvantos
    public func log(_ katigoria: Katigoria, stathmi: StathmiLog = .info, _ minima: String) {
        #if canImport(OSLog)
        if let logger = osLoggers[katigoria] {
            switch stathmi {
            case .debug:
                logger.debug("\(minima, privacy: .public)")
            case .info:
                logger.info("\(minima, privacy: .public)")
            case .notice:
                logger.notice("\(minima, privacy: .public)")
            case .warning:
                logger.warning("\(minima, privacy: .public)")
            case .error:
                logger.error("\(minima, privacy: .public)")
            case .fault:
                logger.fault("\(minima, privacy: .public)")
            }
        }
        #endif

        let simvan = TelemetrySimvan(katigoria: katigoria, stathmi: stathmi, minima: minima)
        prosthikiStoBuffer(simvan)
    }

    // MARK: - Xronometrisi Leitourgias (Performance Tracing)
    public func xronometrisi<T>(
        _ katigoria: Katigoria,
        leitourgia: String,
        block: () throws -> T
    ) rethrows -> T {
        let ksekinima = DispatchTime.now()
        do {
            let apotelesma = try block()
            let teleioma = DispatchTime.now()
            let nanos = teleioma.uptimeNanoseconds - ksekinima.uptimeNanoseconds
            let ms = Double(nanos) / 1_000_000.0
            log(katigoria, stathmi: .info, "[\(leitourgia)] ολοκληρώθηκε σε \(String(format: "%.2f", ms))ms")
            let simvan = TelemetrySimvan(katigoria: katigoria, stathmi: .info, minima: "[\(leitourgia)] SUCCESS", diarkeiaMs: ms)
            prosthikiStoBuffer(simvan)
            return apotelesma
        } catch {
            let teleioma = DispatchTime.now()
            let nanos = teleioma.uptimeNanoseconds - ksekinima.uptimeNanoseconds
            let ms = Double(nanos) / 1_000_000.0
            log(katigoria, stathmi: .error, "[\(leitourgia)] ΑΠΟΤΥΧΙΑ μετά από \(String(format: "%.2f", ms))ms: \(error.localizedDescription)")
            let simvan = TelemetrySimvan(katigoria: katigoria, stathmi: .error, minima: "[\(leitourgia)] ERROR: \(error.localizedDescription)", diarkeiaMs: ms)
            prosthikiStoBuffer(simvan)
            throw error
        }
    }

    public func xronometrisiAsync<T>(
        _ katigoria: Katigoria,
        leitourgia: String,
        block: () async throws -> T
    ) async rethrows -> T {
        let ksekinima = DispatchTime.now()
        do {
            let apotelesma = try await block()
            let teleioma = DispatchTime.now()
            let nanos = teleioma.uptimeNanoseconds - ksekinima.uptimeNanoseconds
            let ms = Double(nanos) / 1_000_000.0
            log(katigoria, stathmi: .info, "[\(leitourgia)] ολοκληρώθηκε σε \(String(format: "%.2f", ms))ms")
            let simvan = TelemetrySimvan(katigoria: katigoria, stathmi: .info, minima: "[\(leitourgia)] SUCCESS", diarkeiaMs: ms)
            prosthikiStoBuffer(simvan)
            return apotelesma
        } catch {
            let teleioma = DispatchTime.now()
            let nanos = teleioma.uptimeNanoseconds - ksekinima.uptimeNanoseconds
            let ms = Double(nanos) / 1_000_000.0
            log(katigoria, stathmi: .error, "[\(leitourgia)] ΑΠΟΤΥΧΙΑ μετά από \(String(format: "%.2f", ms))ms: \(error.localizedDescription)")
            let simvan = TelemetrySimvan(katigoria: katigoria, stathmi: .error, minima: "[\(leitourgia)] ERROR: \(error.localizedDescription)", diarkeiaMs: ms)
            prosthikiStoBuffer(simvan)
            throw error
        }
    }

    // MARK: - Ring Buffer Gia Diagnwstika
    private func prosthikiStoBuffer(_ simvan: TelemetrySimvan) {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        bufferSimvantwn.append(simvan)
        if bufferSimvantwn.count > megistoOrioBuffer {
            bufferSimvantwn.removeFirst(bufferSimvantwn.count - megistoOrioBuffer)
        }
    }

    /// Epistrefei ola ta kataxwrimena simvanta telemetry gia diagnwstiko bundle.
    public func eksagwgiDiagnwstikwn() -> [TelemetrySimvan] {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        return bufferSimvantwn
    }

    /// Katharismos tou in-memory ring buffer.
    public func katharismosBuffer() {
        kleidaria.lock()
        defer { kleidaria.unlock() }
        bufferSimvantwn.removeAll()
    }
}
