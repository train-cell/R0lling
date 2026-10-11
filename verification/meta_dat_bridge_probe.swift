import Foundation

// Minimal collaborator types let this compile the real bridge on Linux without Apple SDKs.
public struct BufferedSample: Sendable {}

public enum HeadGestureDetector {
    public struct IMUSample: Sendable {}
}

@main
struct MetaDATBridgeProbe {
    static func main() async {
        precondition(!MetaDATStreamBridge.einaiSDKDiathesimo)
        precondition(!MetaDATStreamBridge.einaiLiveYlopoiimeno)

        await assertUnavailable {
            _ = try await MetaDATStreamBridge.anoixeLiveSession()
        }
        await assertUnavailable {
            _ = try await MetaDATStreamBridge.diavaseEpomenoVideoFrame()
        }
        await assertUnavailable {
            _ = try await MetaDATStreamBridge.diavaseEpomenoAudioSample()
        }
        await assertUnavailable {
            _ = try await MetaDATStreamBridge.diavaseEpomenoIMU()
        }

        print("PASS: four DAT hooks reject unavailable SDK access with typed errors")
    }

    @MainActor
    private static func assertUnavailable(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            fatalError("An unwired DAT hook reported success")
        } catch let error as NSError {
            precondition(error.domain == MetaDATStreamBridge.errorDomain)
            precondition(error.code == MetaDATStreamBridge.kodikosSDKMiDiathesimo)
        } catch {
            fatalError("Unexpected error type: \(error)")
        }
    }
}
