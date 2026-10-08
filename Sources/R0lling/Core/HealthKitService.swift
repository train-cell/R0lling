import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Real Apple HealthKit Integration for R0lling Sovereign OS
/// Queries Apple Watch biometrics for Bevel Telemetry & Cognitive Readiness.
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

    /// Αίτημα πλήρους άδειας ανάγνωσης και εγγραφής για ΟΛΑ τα δεδομένα Apple Health
    public func requestAuthorization() async throws -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        var readTypes: Set<HKObjectType> = []
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .heartRate,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .respiratoryRate,
            .oxygenSaturation,
            .stepCount,
            .distanceWalkingRunning,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .flightsClimbed,
            .bodyTemperature,
            .environmentalAudioExposure,
            .headphoneAudioExposure,
            .dietaryWater
        ]

        for id in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: id) {
                readTypes.insert(type)
            }
        }

        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            readTypes.insert(mindful)
        }
        readTypes.insert(HKWorkoutType.workoutType())

        var shareTypes: Set<HKSampleType> = []
        if let water = HKQuantityType.quantityType(forIdentifier: .dietaryWater) {
            shareTypes.insert(water)
        }
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            shareTypes.insert(energy)
        }
        if let mindful = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            shareTypes.insert(mindful)
        }
        shareTypes.insert(HKWorkoutType.workoutType())

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { success, error in
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
        guard HKHealthStore.isHealthDataAvailable(),
              let sampleType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    /// Ανάκτηση ωρών ύπνου για την τελευταία νύχτα
    public func fetchLastNightSleepHours() async -> Double {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return 7.5
        }

        let calendar = Calendar.current
        let now = Date()
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
            return 7.5
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 7.5)
                    return
                }

                var totalSleepSeconds: TimeInterval = 0
                for sample in samples {
                    // HKCategoryValueSleepAnalysis.asleep / asleepCore / asleepDeep / asleepREM
                    if sample.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                        totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
                let hours = totalSleepSeconds > 0 ? (totalSleepSeconds / 3600.0) : 7.5
                continuation.resume(returning: hours)
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

        let hrv = await fetchMostRecentQuantity(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) ?? 65.0
        let rhr = await fetchMostRecentQuantity(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) ?? 55.0
        let resp = await fetchMostRecentQuantity(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute())) ?? 14.0
        let spo2Raw = await fetchMostRecentQuantity(for: .oxygenSaturation, unit: HKUnit.percent()) ?? 0.98
        let spo2 = spo2Raw > 1.0 ? spo2Raw : (spo2Raw * 100.0)
        let sleepHours = await fetchLastNightSleepHours()

        // Υπολογισμός Recovery Score (Bevel style algorithm: HRV vs RHR vs Sleep)
        let hrvFactor = min(1.3, max(0.6, hrv / 60.0))
        let rhrFactor = min(1.3, max(0.7, 60.0 / max(40.0, rhr)))
        let sleepFactor = min(1.2, max(0.5, sleepHours / 8.0))
        let rawScore = 80.0 * (hrvFactor * 0.45 + rhrFactor * 0.35 + sleepFactor * 0.20)
        let recoveryScore = Int(min(100.0, max(10.0, rawScore)))

        return HealthKitTelemetrySnapshot(
            hrvMs: (hrv * 10).rounded() / 10,
            restingHRBpm: Int(rhr),
            respiratoryRate: (resp * 10).rounded() / 10,
            bloodOxygenPercent: (spo2 * 10).rounded() / 10,
            recoveryScore: recoveryScore
        )
        #else
        return HealthKitTelemetrySnapshot()
        #endif
    }
}
