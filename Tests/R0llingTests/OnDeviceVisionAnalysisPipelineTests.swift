import XCTest
@testable import R0lling

final class OnDeviceVisionAnalysisPipelineTests: XCTestCase {
    private actor CallRecorder {
        private var calls: [String] = []

        func append(_ value: String) { calls.append(value) }
        func snapshot() -> [String] { calls }
    }

    private struct ProviderError: LocalizedError {
        var errorDescription: String? { "Provider unavailable" }
    }

    func testLocalOCRCompletesBeforeCloudDescription() async throws {
        let recorder = CallRecorder()
        let result = try await OnDeviceVisionAnalysisPipeline.analyze(
            imageData: Data([1, 2, 3]),
            recognizeText: { image in
                XCTAssertEqual(image, Data([1, 2, 3]))
                await recorder.append("ocr")
                return ["menu", "coffee"]
            },
            prepareForCloud: { image in
                await recorder.append("prepare")
                return image
            },
            describeWithCloud: { _ in
                await recorder.append("cloud")
                return "A menu on a table."
            }
        )

        let callOrder = await recorder.snapshot()
        XCTAssertEqual(callOrder, ["ocr", "prepare", "cloud"])
        XCTAssertEqual(result.recognizedText, ["menu", "coffee"])
        XCTAssertEqual(result.cloudDescription, "A menu on a table.")
        XCTAssertNil(result.cloudFailureMessage)
        XCTAssertTrue(result.hasUsableResult)
    }

    func testLocalOCRResultSurvivesUnavailableCloudProvider() async throws {
        let result = try await OnDeviceVisionAnalysisPipeline.analyze(
            imageData: Data([4, 5]),
            recognizeText: { _ in ["ingredients", "oats"] },
            describeWithCloud: { _ in throw ProviderError() }
        )

        XCTAssertEqual(result.recognizedText, ["ingredients", "oats"])
        XCTAssertNil(result.cloudDescription)
        XCTAssertEqual(result.cloudFailureMessage, "Provider unavailable")
        XCTAssertTrue(result.hasUsableResult)
    }

    func testEmptyProviderReplyIsNotReportedAsAResult() async throws {
        let result = try await OnDeviceVisionAnalysisPipeline.analyze(
            imageData: Data([1]),
            recognizeText: { _ in [] },
            describeWithCloud: { _ in " \n " }
        )

        XCTAssertNil(result.cloudDescription)
        XCTAssertFalse(result.hasUsableResult)
    }

    func testCancellationStopsBeforeStartingCloudRequest() async {
        let recorder = CallRecorder()
        let task = Task {
            try await OnDeviceVisionAnalysisPipeline.analyze(
                imageData: Data([1]),
                recognizeText: { _ in
                    await recorder.append("ocr")
                    return ["text"]
                },
                describeWithCloud: { _ in
                    await recorder.append("cloud")
                    return "description"
                }
            )
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            let calls = await recorder.snapshot()
            XCTAssertEqual(calls, [])
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCloudImagePreparationFailureDoesNotDiscardLocalOCR() async throws {
        let result = try await OnDeviceVisionAnalysisPipeline.analyze(
            imageData: Data([9]),
            recognizeText: { _ in ["local"] },
            prepareForCloud: { _ in throw ProviderError() },
            describeWithCloud: { _ in "Should not run" }
        )

        XCTAssertEqual(result.recognizedText, ["local"])
        XCTAssertNil(result.cloudDescription)
        XCTAssertEqual(result.cloudFailureMessage, "Provider unavailable")
        XCTAssertTrue(result.hasUsableResult)
    }
}
