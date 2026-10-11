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
    let report: SleepReportSnapshot
}

private struct HealthKitSleepQueryResult: Sendable {
    let reading: HealthKitSleepReading?
    let didFailQuery: Bool?
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
            .heartRate,
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
        await fetchLastNightSleepReading().reading?.hours
    }

    private func fetchLastNightSleepReading() async -> HealthKitSleepQueryResult {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return HealthKitSleepQueryResult(reading: nil, didFailQuery: nil)
        }

        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let windowStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
              let noonToday = calendar.date(byAdding: .hour, value: 12, to: today) else {
            return HealthKitSleepQueryResult(reading: nil, didFailQuery: nil)
        }
        let windowEnd = min(now, noonToday)
        guard windowEnd > windowStart else {
            return HealthKitSleepQueryResult(reading: nil, didFailQuery: nil)
        }

        // Include every sample that overlaps the overnight window; the reducer clips
        // samples that start before 18:00 or end after the window's noon boundary.
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: HealthKitSleepQueryResult(reading: nil, didFailQuery: true))
                    return
                }
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: HealthKitSleepQueryResult(reading: nil, didFailQuery: true))
                    return
                }

                let stageSamples = samples.compactMap { sample -> SleepStageSample? in
                    guard let stage = Self.sleepStage(for: sample.value) else { return nil }
                    return SleepStageSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        stage: stage,
                        sourceName: sample.sourceRevision.source.name
                    )
                }
                guard let stageReport = SleepEpisodeAggregator.sleepReport(
                    from: stageSamples,
                    windowStart: windowStart,
                    windowEnd: windowEnd
                ) else {
                    continuation.resume(returning: HealthKitSleepQueryResult(reading: nil, didFailQuery: false))
                    return
                }

                Task { [weak self] in
                    guard let self else {
                        continuation.resume(returning: HealthKitSleepQueryResult(reading: nil, didFailQuery: false))
                        return
                    }
                    let vitals = await self.fetchSleepVitalSamples(
                        from: stageReport.startedAt,
                        to: stageReport.endedAt
                    )
                    let report = SleepEpisodeAggregator.attachingVitalSamples(
                        vitals.samples,
                        queryFailures: vitals.failures,
                        to: stageReport
                    )
                    let reading = HealthKitSleepReading(
                        hours: report.asleepSeconds / 3600,
                        metadata: HealthKitReadingMetadata(
                            measuredAt: report.endedAt,
                            sourceName: report.sourceNames.joined(separator: ", ")
                        ),
                        report: report
                    )
                    continuation.resume(returning: HealthKitSleepQueryResult(reading: reading, didFailQuery: false))
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepVitalSamples(
        from startDate: Date,
        to endDate: Date
    ) async -> (samples: [SleepVitalSample], failures: [SleepVitalMetric]) {
        var allSamples: [SleepVitalSample] = []
        var failures: [SleepVitalMetric] = []
        for metric in SleepVitalMetric.allCases {
            let result = await fetchSleepVitalSamples(for: metric, from: startDate, to: endDate)
            allSamples += result.samples
            if result.didFail {
                failures.append(metric)
            }
        }
        return (allSamples, failures)
    }

    private func fetchSleepVitalSamples(
        for metric: SleepVitalMetric,
        from startDate: Date,
        to endDate: Date
    ) async -> (samples: [SleepVitalSample], didFail: Bool) {
        let identifier: HKQuantityTypeIdentifier
        let unit: HKUnit
        switch metric {
        case .heartRate:
            identifier = .heartRate
            unit = HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariability:
            identifier = .heartRateVariabilitySDNN
            unit = HKUnit.second()
        case .respiratoryRate:
            identifier = .respiratoryRate
            unit = HKUnit.count().unitDivided(by: .minute())
        case .oxygenSaturation:
            identifier = .oxygenSaturation
            unit = HKUnit.percent()
        }
        guard HKHealthStore.isHealthDataAvailable(),
              endDate > startDate,
              let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return ([], true)
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard error == nil, let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: ([], true))
                    return
                }
                let readings = quantitySamples.compactMap { sample -> SleepVitalSample? in
                    let measuredAt = sample.endDate
                    guard measuredAt >= startDate, measuredAt <= endDate,
                          let value = metric.normalizedValue(
                            fromHealthKitUnit: sample.quantity.doubleValue(for: unit)
                          ) else {
                        return nil
                    }
                    return SleepVitalSample(
                        metric: metric,
                        measuredAt: measuredAt,
                        value: value,
                        sourceName: sample.sourceRevision.source.name
                    )
                }
                continuation.resume(returning: (readings, false))
            }
            healthStore.execute(query)
        }
    }

    private static func sleepStage(for value: Int) -> SleepStageCategory? {
        switch value {
        case HKCategoryValueSleepAnalysis.awake.rawValue:
            .awake
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
            .rem
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
            .deep
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
            .core
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
            .asleepUnspecified
        default:
            nil
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
        let sleepResult = await fetchLastNightSleepReading()
        let sleep = sleepResult.reading
        // No clinical recovery score: the earlier formula was an unvalidated heuristic.
        return HealthKitTelemetrySnapshot(
            hrvMs: hrv?.value,
            restingHRBpm: rhr.map { Int($0.value) },
            respiratoryRate: resp?.value,
            bloodOxygenPercent: spo2.map { $0.value * 100 },
            sleepHours: sleep?.hours,
            sleepReport: sleep?.report,
            sleepQueryFailed: sleepResult.didFailQuery,
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

        let calendar = FitnessActivityCalendar.athensCalendar
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
                    FitnessWorkoutSample(
                        id: $0.uuid,
                        startedAt: $0.startDate,
                        durationSeconds: $0.duration,
                        activityName: Self.fitnessActivityName($0.workoutActivityType)
                    )
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

    #if canImport(HealthKit)
    private static func fitnessActivityName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .archery: "Τοξοβολία"
        case .bowling: "Μπόουλινγκ"
        case .fencing: "Ξιφασκία"
        case .gymnastics: "Γυμναστική"
        case .trackAndField: "Στίβος"
        case .americanFootball: "Αμερικανικό ποδόσφαιρο"
        case .australianFootball: "Αυστραλιανό ποδόσφαιρο"
        case .baseball: "Μπέιζμπολ"
        case .running: "Τρέξιμο"
        case .walking: "Περπάτημα"
        case .cycling: "Ποδηλασία"
        case .handCycling: "Χειροκίνητη ποδηλασία"
        case .wheelchairWalkPace: "Αμαξίδιο · ρυθμός βάδισης"
        case .wheelchairRunPace: "Αμαξίδιο · γρήγορος ρυθμός"
        case .swimming: "Κολύμβηση"
        case .hiking: "Πεζοπορία"
        case .yoga: "Yoga"
        case .preparationAndRecovery: "Προθέρμανση / αποκατάσταση"
        case .flexibility: "Ευλυγισία"
        case .cooldown: "Αποθεραπεία"
        case .traditionalStrengthTraining: "Ενδυνάμωση με βάρη"
        case .functionalStrengthTraining: "Λειτουργική ενδυνάμωση"
        case .coreTraining: "Ενδυνάμωση κορμού"
        case .highIntensityIntervalTraining: "Διαλειμματική υψηλής έντασης"
        case .crossTraining: "Cross training"
        case .mixedCardio: "Μικτή αερόβια άσκηση"
        case .jumpRope: "Σχοινάκι"
        case .rowing: "Κωπηλασία"
        case .elliptical: "Ελλειπτικό"
        case .basketball: "Μπάσκετ"
        case .cricket: "Κρίκετ"
        case .discSports: "Άθλημα με δίσκο"
        case .handball: "Χάντμπολ"
        case .lacrosse: "Λακρός"
        case .soccer: "Ποδόσφαιρο"
        case .softball: "Σόφτμπολ"
        case .rugby: "Ράγκμπι"
        case .tennis: "Τένις"
        case .golf: "Γκολφ"
        case .pilates: "Pilates"
        case .barre: "Barre"
        case .mindAndBody: "Νους και σώμα"
        case .socialDance, .cardioDance, .dance, .danceInspiredTraining: "Χορός"
        case .mixedMetabolicCardioTraining: "Μικτή αερόβια άσκηση"
        case .swimBikeRun: "Τρίαθλο"
        case .transition: "Μετάβαση τριάθλου"
        case .stairClimbing, .stairs, .stepTraining: "Άσκηση σε σκαλοπάτια"
        case .fitnessGaming: "Άσκηση με βιντεοπαιχνίδι"
        case .boxing, .kickboxing: "Πυγμαχία"
        case .martialArts: "Πολεμικές τέχνες"
        case .taiChi: "Τάι τσι"
        case .wrestling: "Πάλη"
        case .badminton, .pickleball, .racquetball, .squash, .tableTennis: "Άθλημα ρακέτας"
        case .paddleSports: "Κανό / καγιάκ"
        case .sailing: "Ιστιοπλοΐα"
        case .surfingSports: "Surf"
        case .underwaterDiving: "Καταδύσεις"
        case .waterFitness: "Αερόβια άσκηση στο νερό"
        case .waterPolo: "Υδατοσφαίριση"
        case .waterSports: "Θαλάσσια σπορ"
        case .volleyball: "Βόλεϊ"
        case .hockey: "Χόκεϊ"
        case .climbing: "Αναρρίχηση"
        case .equestrianSports: "Ιππασία"
        case .fishing: "Ψάρεμα"
        case .hunting: "Κυνήγι"
        case .play: "Παιχνίδι / ελεύθερη άσκηση"
        case .curling: "Κέρλινγκ"
        case .downhillSkiing, .crossCountrySkiing: "Σκι"
        case .snowSports: "Χειμερινά σπορ"
        case .snowboarding: "Snowboard"
        case .skatingSports: "Πατινάζ"
        case .other: "Άλλη προπόνηση"
        default: "Προπόνηση"
        }
    }
    #endif
}
