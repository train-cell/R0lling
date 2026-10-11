import Foundation

@main
enum HealthMetricDisplayScaleProbe {
    static func main() {
        let checks: [(String, Bool)] = [
            ("midpoint", HealthMetricDisplayScale.progress(for: 50, within: 0...100) == 0.5),
            ("lower clamp", HealthMetricDisplayScale.progress(for: -5, within: 0...100) == 0),
            ("upper clamp", HealthMetricDisplayScale.progress(for: 150, within: 0...100) == 1),
            ("nil input", HealthMetricDisplayScale.progress(for: nil, within: 0...100) == nil),
            ("NaN input", HealthMetricDisplayScale.progress(for: .nan, within: 0...100) == nil),
            ("degenerate range", HealthMetricDisplayScale.progress(for: 1, within: 5...5) == nil)
        ]

        for (name, passed) in checks {
            print("\(passed ? "PASS" : "FAIL"): \(name)")
            precondition(passed, "\(name) failed")
        }
    }
}
