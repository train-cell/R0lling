import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(HealthKit)
private struct HealthKitQuantityReading: Sendable {
    let value: Double
    let metadata: HealthKitReadingMetadata
}

private struct HealthKitSleepReading: Sendable {
    let hours: Double
    let metadata: HealthKitReadingMetadata
}
#endif

/// Reads optional recent HealthKit measurements for display in the Bevel-inspired UI.
/// This service does not calculate a clinical recovery or readiness score.
public actor HealthKitService {
    public static let shared = HealthKitService()

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    public init() {}

    /// Ελέγχει αν το HealthKit είναι διαθέσιμο στη συσκευή (π.χ. iPhone vs Mac/Simulator)
    public func isAvailable() -> Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    /// Requests the listed HealthKit types. Success means the request completed, not that reads were granted.
    public func requestAuthorization() async throws -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        var readTypes: Set<HKObjectType> = []
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .respiratoryRate,
            .oxygenSaturation,
            .bodyTemperature
        ]

        for id in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }

        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        readTypes.insert(HKWorkoutType.workoutType())

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        #else
        return false
        #endif
    }

    /// Ανάκτηση της πιο πρόσφατης τιμής ποσοτικού δείκτη
    #if canImport(HealthKit)
    public func fetchMostRecentQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await fetchMostRecentQuantityReading(for: identifier, unit: unit)?.value
    }

    private func fetchMostRecentQuantityReading(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> HealthKitQuantityReading? {
        guard HKHealthStore.isHealthDataAvailable(),
              let sampleType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-86400), end: Date(), options: .strictEndDate),
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: HealthKitQuantityReading(
                    value: sample.quantity.doubleValue(for: unit),
                    metadata: HealthKitReadingMetadata(
                        measuredAt: sample.endDate,
                        sourceName: sample.sourceRevision.source.name
                    )
                ))
            }
            healthStore.execute(query)
        }
    }

    /// Ανάκτηση ωρών ύπνου για την τελευταία νύχτα
    public func fetchLastNightSleepHours() async -> Double? {
        await fetchLastNightSleepReading()?.hours
    }

    private func fetchLastNightSleepReading() async -> HealthKitSleepReading? {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let windowStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
              let noonToday = calendar.date(byAdding: .hour, value: 12, to: today) else {
            return nil
        }
        let windowEnd = min(now, noonToday)
        guard windowEnd > windowStart else { return nil }

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let asleepSamples = samples.filter { asleepValues.contains($0.value) }
                let intervals = asleepSamples.map {
                    SleepInterval(
                        startDate: $0.startDate,
                        endDate: $0.endDate,
                        sourceName: $0.sourceRevision.source.name
                    )
                }
                guard let episode = SleepEpisodeAggregator.longestEpisode(
                    from: intervals,
                    windowStart: windowStart,
                    windowEnd: windowEnd
                ) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: HealthKitSleepReading(
                    hours: episode.asleepSeconds / 3600,
                    metadata: HealthKitReadingMetadata(
                        measuredAt: episode.endedAt,
                        sourceName: episode.sourceNames.joined(separator: ", ")
                    )
                ))
            }
            healthStore.execute(query)
        }
    }
    #endif

    /// Πλήρες snapshot τηλεμετρίας συνδυάζοντας πραγματικές μετρήσεις HealthKit
    public func fetchLiveTelemetrySnapshot() async -> HealthKitTelemetrySnapshot {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthKitTelemetrySnapshot()
        }

        let hrv = await fetchMostRecentQuantityReading(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli))
        let rhr = await fetchMostRecentQuantityReading(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        let resp = await fetchMostRecentQuantityReading(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()))
        let spo2 = await fetchMostRecentQuantityReading(for: .oxygenSaturation, unit: HKUnit.percent())
        let temperature = await fetchMostRecentQuantityReading(for: .bodyTemperature, unit: HKUnit.degreeCelsius())
        let sleep = await fetchLastNightSleepReading()
        // No clinical recovery score: the earlier formula was an unvalidated heuristic.
        return HealthKitTelemetrySnapshot(
            hrvMs: hrv?.value,
            restingHRBpm: rhr.map { Int($0.value) },
            respiratoryRate: resp?.value,
            bloodOxygenPercent: spo2.map { $0.value * 100 },
            sleepHours: sleep?.hours,
            bodyTemperatureCelsius: temperature?.value,
            hrvMetadata: hrv?.metadata,
            restingHRMetadata: rhr?.metadata,
            respiratoryRateMetadata: resp?.metadata,
            bloodOxygenMetadata: spo2?.metadata,
            bodyTemperatureMetadata: temperature?.metadata,
            sleepMetadata: sleep?.metadata
        )
        #else
        return HealthKitTelemetrySnapshot()
        #endif
    }

    /// Returns real workouts for the visible and immediately preceding 30-day windows.
    public func fetchFitnessActivitySnapshot(referenceDate: Date = Date()) async -> FitnessActivitySnapshot {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable(at: referenceDate)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        guard let currentStart = calendar.date(byAdding: .day, value: -29, to: today),
              let queryStart = calendar.date(byAdding: .day, value: -30, to: currentStart) else {
            return .unavailable(at: referenceDate, calendar: calendar)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: referenceDate,
            options: []
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil, let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: .unavailable(at: referenceDate, calendar: calendar))
                    return
                }

                let records = workouts.map {
                    FitnessWorkoutSample(startedAt: $0.startDate, durationSeconds: $0.duration)
                }
                continuation.resume(returning: FitnessActivitySnapshot(
                    samples: records,
                    referenceDate: referenceDate,
                    calendar: calendar
                ))
            }
            healthStore.execute(query)
        }
        #else
        return .unavailable(at: referenceDate)
        #endif
    }
}
