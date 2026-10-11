import CoreLocation
import XCTest
@testable import R0lling

final class HyperlapseTripCompressorTests: XCTestCase {
    func testRejectsNonPositiveTargetFrameRate() {
        XCTAssertThrowsError(try HyperlapseTripCompressor(targetFps: 0))
        XCTAssertThrowsError(try HyperlapseTripCompressor(targetFps: -1))
    }

    func testRejectsNonFiniteOrNonPositiveDisplacement() {
        XCTAssertThrowsError(try HyperlapseTripCompressor(minDisplacementMeters: .nan))
        XCTAssertThrowsError(try HyperlapseTripCompressor(minDisplacementMeters: .infinity))
        XCTAssertThrowsError(try HyperlapseTripCompressor(minDisplacementMeters: 0))
        XCTAssertThrowsError(try HyperlapseTripCompressor(minDisplacementMeters: -1))
    }

    func testRejectsNonPositiveFrameLimit() throws {
        let compressor = try HyperlapseTripCompressor()
        XCTAssertThrowsError(try compressor.compressRoute(samples: makeSamples(count: 1), maxResultFrames: 0))
        XCTAssertThrowsError(try compressor.compressRoute(samples: makeSamples(count: 1), maxResultFrames: -1))
    }

    func testRejectsNonFiniteAndDecreasingSampleTimestamps() throws {
        let compressor = try HyperlapseTripCompressor()
        var badSamples = makeSamples(count: 3)
        badSamples[1] = makeSample(index: 1, timestamp: .nan)
        XCTAssertThrowsError(try compressor.compressRoute(samples: badSamples))

        badSamples = makeSamples(count: 3)
        badSamples[2] = makeSample(index: 2, timestamp: 0.5)
        XCTAssertThrowsError(try compressor.compressRoute(samples: badSamples))
    }

    func testRejectsInvalidCoordinatesAndFrameIndices() throws {
        let compressor = try HyperlapseTripCompressor()
        var badSamples = makeSamples(count: 2)
        badSamples[1] = HyperlapseTripCompressor.GeoFrameSample(
            frameIndex: 1,
            timestamp: 1,
            coordinate: CLLocationCoordinate2D(latitude: 91, longitude: 0),
            imageRelativePath: "Media/Images/frame-1.jpg"
        )
        XCTAssertThrowsError(try compressor.compressRoute(samples: badSamples))

        badSamples = makeSamples(count: 2)
        badSamples[1] = makeSample(index: -1, timestamp: 1)
        XCTAssertThrowsError(try compressor.compressRoute(samples: badSamples))
    }

    func testRejectsNonIncreasingFrameIndices() throws {
        let compressor = try HyperlapseTripCompressor()
        let samples = [
            makeSample(index: 2, timestamp: 0),
            makeSample(index: 2, timestamp: 1)
        ]

        XCTAssertThrowsError(try compressor.compressRoute(samples: samples))
    }

    func testRejectsInvalidHeadingAndEmptyImagePath() throws {
        let compressor = try HyperlapseTripCompressor()
        var samples = makeSamples(count: 2)
        samples[1] = HyperlapseTripCompressor.GeoFrameSample(
            frameIndex: 1,
            timestamp: 1,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            heading: .infinity,
            imageRelativePath: "Media/Images/frame-1.jpg"
        )
        XCTAssertThrowsError(try compressor.compressRoute(samples: samples))

        samples[1] = HyperlapseTripCompressor.GeoFrameSample(
            frameIndex: 1,
            timestamp: 1,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            heading: 0,
            imageRelativePath: "  "
        )
        XCTAssertThrowsError(try compressor.compressRoute(samples: samples))
    }

    func testRejectsFrameLimitThatCannotPreserveBothRouteEndpoints() throws {
        let compressor = try HyperlapseTripCompressor()
        XCTAssertThrowsError(try compressor.compressRoute(samples: makeSamples(count: 2), maxResultFrames: 1))
    }

    func testDownsamplingPreservesRouteEndpointsWithinFrameLimit() throws {
        let compressor = try HyperlapseTripCompressor(minDisplacementMeters: 10, targetFps: 30)
        let result = try compressor.compressRoute(samples: makeSamples(count: 10), maxResultFrames: 3)

        XCTAssertEqual(result.selectedFrames.count, 3)
        XCTAssertEqual(result.selectedFrames.first?.frameIndex, 0)
        XCTAssertEqual(result.selectedFrames.last?.frameIndex, 9)
        XCTAssertTrue(zip(result.selectedFrames, result.selectedFrames.dropFirst()).allSatisfy { $0.frameIndex < $1.frameIndex })
        XCTAssertTrue(result.hyperlapseDurationSeconds.isFinite)
        XCTAssertTrue(result.speedupFactor.isFinite)
    }

    func testTotalDistanceIncludesEveryRecordedLegEvenWhenFramesAreFiltered() throws {
        let compressor = try HyperlapseTripCompressor(minDisplacementMeters: 1_000, targetFps: 30)
        let route = [
            makeSample(index: 0, timestamp: 0, latitude: 0, longitude: 0),
            makeSample(index: 1, timestamp: 1, latitude: 0, longitude: 0.0002),
            makeSample(index: 2, timestamp: 2, latitude: 0.0002, longitude: 0.0002),
            makeSample(index: 3, timestamp: 3, latitude: 0.0002, longitude: 0)
        ]

        let result = try compressor.compressRoute(samples: route)
        let directDistance = HyperlapseTripCompressor.distanceInMeters(
            from: route[0].coordinate,
            to: route[3].coordinate
        )

        XCTAssertEqual(result.selectedFrames.map(\.frameIndex), [0, 3])
        XCTAssertGreaterThan(result.totalDistanceMeters, directDistance * 2)
        XCTAssertEqual(result.originalDurationSeconds, 3, accuracy: 0.001)
    }

    func testRouteEndpointIsPreservedWhenFinalMovementIsBelowThreshold() throws {
        let compressor = try HyperlapseTripCompressor(minDisplacementMeters: 12, targetFps: 30)
        let route = [
            makeSample(index: 0, timestamp: 0, longitude: 0),
            makeSample(index: 1, timestamp: 1, longitude: 0.00001),
            makeSample(index: 2, timestamp: 2, longitude: 0.00002)
        ]

        let result = try compressor.compressRoute(samples: route)

        XCTAssertEqual(result.selectedFrames.map(\.frameIndex), [0, 2])
    }

    func testEmptyRouteReturnsFiniteZeroMetrics() throws {
        let compressor = try HyperlapseTripCompressor()
        let result = try compressor.compressRoute(samples: [])

        XCTAssertTrue(result.selectedFrames.isEmpty)
        XCTAssertEqual(result.totalDistanceMeters, 0)
        XCTAssertEqual(result.originalDurationSeconds, 0)
        XCTAssertEqual(result.hyperlapseDurationSeconds, 0)
        XCTAssertEqual(result.speedupFactor, 1)
    }

    private func makeSamples(count: Int) -> [HyperlapseTripCompressor.GeoFrameSample] {
        (0..<count).map { index in
            makeSample(index: index, timestamp: Double(index), longitude: Double(index) * 0.0002)
        }
    }

    private func makeSample(
        index: Int,
        timestamp: Double,
        latitude: Double = 0,
        longitude: Double = 0
    ) -> HyperlapseTripCompressor.GeoFrameSample {
        HyperlapseTripCompressor.GeoFrameSample(
            frameIndex: index,
            timestamp: timestamp,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            imageRelativePath: "Media/Images/frame-\(index).jpg"
        )
    }
}
