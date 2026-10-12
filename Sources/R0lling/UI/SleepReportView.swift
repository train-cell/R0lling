import SwiftUI

/// Bevel-inspired sleep detail, populated only from real HealthKit sleep-stage samples.
public struct SleepReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedVitalMetric: SleepVitalMetric = .heartRate
    public let report: SleepReportSnapshot

    public init(report: SleepReportSnapshot) {
        self.report = report
    }

    private var recordedStageSeconds: TimeInterval {
        report.stageDurations.reduce(0) { $0 + $1.durationSeconds }
    }

    private var emptyVitalMessage: String {
        if report.vitalQueryFailures.contains(selectedVitalMetric) {
            return "Δεν ήταν δυνατή η ανάκτηση των μετρήσεων \(selectedVitalMetric.displayName.lowercased()) από το HealthKit. Δοκίμασε ξανά αργότερα."
        }
        return "Το HealthKit δεν επέστρεψε διαθέσιμες μετρήσεις \(selectedVitalMetric.displayName.lowercased()) για αυτόν τον ύπνο. Μπορεί να μην υπάρχουν δείγματα ή να μην είναι διαθέσιμα στην εφαρμογή."
    }

    private var stageGridColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var vitalMetricColumns: [GridItem] {
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 2 : SleepVitalMetric.allCases.count
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }

    private var timelineAccessibilitySummary: String {
        guard !report.timeline.isEmpty else { return "Δεν υπάρχουν καταγεγραμμένες φάσεις ύπνου." }

        var parts = ["Χρονολόγιο καταγεγραμμένων φάσεων ύπνου."]
        var previousEnd: Date?
        for segment in report.timeline {
            if let previousEnd, segment.startDate > previousEnd {
                parts.append("Κενό χωρίς καταγραφή, \(durationText(segment.startDate.timeIntervalSince(previousEnd))).")
            }
            let start = segment.startDate.formatted(date: .omitted, time: .shortened)
            let end = segment.endDate.formatted(date: .omitted, time: .shortened)
            parts.append("\(segment.stage.displayName), από \(start) έως \(end), \(durationText(segment.durationSeconds)).")
            previousEnd = segment.endDate
        }
        return parts.joined(separator: " ")
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        sleepSummary
                        stageTimeline
                        stageBreakdown
                        overnightVitals
                        sourceDisclosure
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                }
            }
            .background(R0llingTheme.sleepCanvas.ignoresSafeArea())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    closeButton
                    headerTitle
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ZStack {
                    HStack {
                        closeButton
                        Spacer(minLength: 44)
                    }

                    headerTitle
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }
                .frame(minHeight: 48)
            }
        }
        .padding(.bottom, 2)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(R0llingTheme.textPrimary)
                .frame(width: 44, height: 44)
                .r0llingSleepInsetSurface(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Κλείσιμο λεπτομερειών ύπνου")
    }

    private var headerTitle: some View {
            VStack(spacing: 3) {
                Text("Κύριος ύπνος")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(R0llingTheme.textPrimary)
                Text(report.startedAt.formatted(date: .complete, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(R0llingTheme.textSecondary)
            }
    }

    private var sleepSummary: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Χρόνος ύπνου")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(R0llingTheme.textSecondary)
                Text(durationText(report.asleepSeconds))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit())
                    .foregroundStyle(R0llingTheme.textPrimary)
            }
            Spacer(minLength: 8)
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(R0llingTheme.sleepAccent)
                .frame(width: 48, height: 48)
                .r0llingSleepInsetSurface(cornerRadius: 15)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .r0llingSleepSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private var stageTimeline: some View {
        VStack(alignment: .leading, spacing: 11) {
            timelineTitle

            Text("Εμφανίζονται μόνο οι φάσεις που κατέγραψε το Apple Health.")
                .font(.caption)
                .foregroundStyle(R0llingTheme.textSecondary)

            SleepStageChart(report: report)
                .frame(height: 166)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(timelineAccessibilitySummary)

            HStack {
                sleepTimeBadge(report.startedAt, symbol: "moon.fill")
                Spacer()
                sleepTimeBadge(report.endedAt, symbol: "sun.max.fill")
            }

            HStack {
                Spacer()
                timelineDuration
            }

            Text("Δεν υπολογίζεται Sleep Score, χρόνος στο κρεβάτι ή Heart Rate Dip.")
                .font(.caption2)
                .foregroundStyle(R0llingTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var timelineTitle: some View {
        Text("Φάσεις ύπνου")
            .font(.headline.weight(.semibold))
            .foregroundStyle(R0llingTheme.textPrimary)
    }

    private var timelineDuration: some View {
        Text("Διάρκεια: \(durationText(report.observedSpanSeconds))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(R0llingTheme.textSecondary)
    }

    private var stageBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Σύνοψη σταδίων")
                .font(.headline.weight(.semibold))
                .foregroundStyle(R0llingTheme.textPrimary)

            LazyVGrid(columns: stageGridColumns, spacing: 10) {
                ForEach(report.stageDurations) { stageDuration in
                    SleepStageSummaryCard(
                        stage: stageDuration.stage,
                        seconds: stageDuration.durationSeconds,
                        percent: recordedStageSeconds > 0
                            ? stageDuration.durationSeconds / recordedStageSeconds
                            : 0
                    )
                }
            }

            Text("Τα ποσοστά αφορούν μόνο τις φάσεις που καταγράφηκαν.")
                .font(.caption2)
                .foregroundStyle(R0llingTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overnightVitals: some View {
        let samples = report.vitalSamples.filter { $0.metric == selectedVitalMetric }
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Νυχτερινές μετρήσεις")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(R0llingTheme.textPrimary)
                Text("Καταγραφές Apple Health μέσα στον κύριο ύπνο")
                    .font(.caption)
                    .foregroundStyle(R0llingTheme.textSecondary)
            }

            LazyVGrid(columns: vitalMetricColumns, spacing: 8) {
                ForEach(SleepVitalMetric.allCases, id: \.self) { metric in
                    vitalMetricButton(metric)
                }
            }
            .accessibilityLabel("Επιλογή νυχτερινής μέτρησης")

            if samples.isEmpty {
                Text(emptyVitalMessage)
                    .font(.subheadline)
                    .foregroundStyle(R0llingTheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                    .accessibilityLabel(emptyVitalMessage)
            } else {
                HStack {
                    Text("min \(formattedVitalValue(samples.map(\.value).min() ?? 0)) \(selectedVitalMetric.unitName)")
                    Spacer()
                    Text("max \(formattedVitalValue(samples.map(\.value).max() ?? 0)) \(selectedVitalMetric.unitName)")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(R0llingTheme.textMuted)

                SleepVitalChart(
                    samples: samples,
                    metric: selectedVitalMetric,
                    startedAt: report.startedAt,
                    endedAt: report.endedAt
                )
                .frame(height: 150)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(vitalChartAccessibilityLabel(samples, metric: selectedVitalMetric))

                HStack {
                    sleepTimeBadge(report.startedAt, symbol: "moon.fill")
                    Spacer()
                    Text("\(samples.count) καταγραφές")
                    Spacer()
                    sleepTimeBadge(report.endedAt, symbol: "sun.max.fill")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(R0llingTheme.textMuted)
                .accessibilityHidden(true)
            }

            Text("Τα κενά δείχνουν διαστήματα χωρίς μέτρηση· δεν παρεμβάλλονται δεδομένα.")
                .font(.caption2)
                .foregroundStyle(R0llingTheme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sleepTimeBadge(_ date: Date, symbol: String) -> some View {
        Label(date.formatted(date: .omitted, time: .shortened), systemImage: symbol)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(R0llingTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                R0llingTheme.sleepTimeBadgeSurface,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
    }

    private func vitalChartAccessibilityLabel(_ samples: [SleepVitalSample], metric: SleepVitalMetric) -> String {
        guard let minimum = samples.map(\.value).min(), let maximum = samples.map(\.value).max() else {
            return "Το HealthKit δεν επέστρεψε διαθέσιμες μετρήσεις."
        }
        let lower = formattedVitalValue(minimum)
        let upper = formattedVitalValue(maximum)
        return "\(metric.displayName), \(samples.count) πραγματικές καταγραφές, από \(lower) έως \(upper) \(metric.unitName). Τα κενά δεν συμπληρώνονται."
    }

    private func vitalMetricButton(_ metric: SleepVitalMetric) -> some View {
        let isSelected = selectedVitalMetric == metric
        let color = vitalMetricColor(metric, isSelected: isSelected)
        return Button {
            selectedVitalMetric = metric
        } label: {
            VStack(spacing: 6) {
                Group {
                    if metric == .heartRate {
                        Image(systemName: "heart.fill")
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(R0llingTheme.sleepCanvas)
                                    .padding(1)
                                    .background(color, in: Circle())
                                    .overlay {
                                        Circle().stroke(R0llingTheme.sleepCanvas, lineWidth: 0.7)
                                    }
                                    .offset(x: 2, y: 2)
                            }
                    } else {
                        Image(systemName: vitalMetricSymbol(metric))
                    }
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
                Text(metric.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? R0llingTheme.textPrimary : R0llingTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? color.opacity(0.09) : R0llingTheme.sleepMetricSurface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(isSelected ? 0.92 : 1), lineWidth: isSelected ? 1.3 : 0.9)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(metric.displayName)
        .accessibilityValue(isSelected ? "Επιλεγμένη" : "")
        .accessibilityHint("Εμφανίζει μόνο τις μετρήσεις που κατέγραψε το Apple Health.")
    }

    private func vitalMetricSymbol(_ metric: SleepVitalMetric) -> String {
        switch metric {
        case .heartRate: "heart.fill"
        case .heartRateVariability: "waveform.path.ecg"
        case .respiratoryRate: "lungs.fill"
        case .oxygenSaturation: "drop.fill"
        }
    }

    private func vitalMetricColor(_ metric: SleepVitalMetric, isSelected: Bool) -> Color {
        switch metric {
        case .heartRate: isSelected ? R0llingTheme.sleepHeartRate : R0llingTheme.sleepHeartRate.opacity(0.5)
        case .heartRateVariability: isSelected ? R0llingTheme.sleepHRV : R0llingTheme.sleepHRVMuted
        case .respiratoryRate: isSelected ? R0llingTheme.sleepRespiratory : R0llingTheme.sleepRespiratoryMuted
        case .oxygenSaturation: isSelected ? R0llingTheme.sleepOxygen : R0llingTheme.sleepOxygenMuted
        }
    }

    private func formattedVitalValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var sourceDisclosure: some View {
        Label {
            Text(report.sourceNames.isEmpty ? "Πηγή: Apple Health" : "Πηγή: \(report.sourceNames.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(R0llingTheme.textSecondary)
        } icon: {
            Image(systemName: "heart.text.square")
                .foregroundStyle(R0llingTheme.sleepAccent)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    fileprivate static func color(for stage: SleepStageCategory) -> Color {
        switch stage {
        case .awake: R0llingTheme.sleepAwake
        case .rem: R0llingTheme.sleepREM
        case .deep: R0llingTheme.sleepDeep
        case .core: R0llingTheme.sleepCore
        case .asleepUnspecified: R0llingTheme.textMuted
        }
    }

    fileprivate func durationText(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let totalMinutes = Int((seconds / 60).rounded())
        return "\(totalMinutes / 60)ω \(totalMinutes % 60)λ"
    }
}

private struct SleepVitalChart: View {
    let samples: [SleepVitalSample]
    let metric: SleepVitalMetric
    let startedAt: Date
    let endedAt: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var safeSamples: [SleepVitalSample] {
        samples.filter { $0.value.isFinite && $0.value > 0 }.sorted { $0.measuredAt < $1.measuredAt }
    }

    private var span: TimeInterval {
        let value = endedAt.timeIntervalSince(startedAt)
        return value.isFinite && value > 0 ? value : 1
    }

    private var chartColor: Color {
        switch metric {
        case .heartRate: R0llingTheme.sleepHeartRate
        case .heartRateVariability: R0llingTheme.sleepHRV
        case .respiratoryRate: R0llingTheme.sleepRespiratory
        case .oxygenSaturation: R0llingTheme.sleepOxygen
        }
    }

    private var trendLineColor: Color {
        R0llingTheme.sleepVitalTrace
    }

    var body: some View {
        GeometryReader { geometry in
            let values = safeSamples.map(\.value)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 1
            let padding = max((maximum - minimum) * 0.12, max(abs(maximum) * 0.015, 0.5))
            let lowerBound = minimum - padding
            let upperBound = maximum + padding
            let range = max(upperBound - lowerBound, 1)
            let showsAxisLabels = !dynamicTypeSize.isAccessibilitySize
            let axisWidth: CGFloat = showsAxisLabels ? 32 : 0
            let axisSpacing: CGFloat = showsAxisLabels ? 4 : 0
            let chartWidth = max(geometry.size.width - axisWidth - axisSpacing, 1)
            let plotWidth = max(chartWidth - 16, 1)
            let plotHeight = max(geometry.size.height - 16, 1)
            let axisLabels = axisTickLabels(
                lowerBound: lowerBound,
                range: range,
                hasSamples: !values.isEmpty
            )

            HStack(alignment: .top, spacing: axisSpacing) {
                Canvas { context, _ in
                    let inset: CGFloat = 8
                    for row in 0..<4 {
                        let y = inset + (plotHeight * CGFloat(row) / 3)
                        var grid = Path()
                        grid.move(to: CGPoint(x: inset, y: y))
                        grid.addLine(to: CGPoint(x: inset + plotWidth, y: y))
                        context.stroke(grid, with: .color(Color.white.opacity(0.12)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    }

                    var segment = Path()
                    var previousSample: SleepVitalSample?
                    var plottedPoints: [CGPoint] = []
                    for sample in safeSamples {
                        let x = inset + plotWidth * CGFloat(min(max(sample.measuredAt.timeIntervalSince(startedAt) / span, 0), 1))
                        let normalizedY = min(max((sample.value - lowerBound) / range, 0), 1)
                        let point = CGPoint(x: x, y: inset + plotHeight * CGFloat(1 - normalizedY))
                        if let previousSample,
                           sample.measuredAt.timeIntervalSince(previousSample.measuredAt) <= metric.maximumContinuousGap {
                            segment.addLine(to: point)
                        } else {
                            if !segment.isEmpty {
                                context.stroke(segment, with: .color(trendLineColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            }
                            segment = Path()
                            segment.move(to: point)
                        }
                        plottedPoints.append(point)
                        previousSample = sample
                    }
                    if !segment.isEmpty {
                        context.stroke(segment, with: .color(trendLineColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                    for point in plottedPoints {
                        let dot = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                        context.fill(Path(ellipseIn: dot), with: .color(chartColor))
                    }
                }
                .frame(width: chartWidth, height: geometry.size.height)

                if showsAxisLabels {
                    ZStack {
                        ForEach(axisLabels.indices, id: \.self) { row in
                            Text(axisLabels[row])
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(R0llingTheme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(width: axisWidth, height: 14, alignment: .trailing)
                                .position(
                                    x: axisWidth / 2,
                                    y: 8 + plotHeight * CGFloat(row) / 3
                                )
                        }
                    }
                    .frame(width: axisWidth, height: geometry.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func axisTickLabels(lowerBound: Double, range: Double, hasSamples: Bool) -> [String] {
        guard hasSamples, lowerBound.isFinite, range.isFinite, range > 0 else { return [] }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.maximumFractionDigits = 1

        return (0..<4).map { row in
            let value = lowerBound + range * (1 - Double(row) / 3)
            return formatter.string(from: NSNumber(value: value)) ?? "—"
        }
    }
}

private struct SleepStageChart: View {
    let report: SleepReportSnapshot

    private var span: TimeInterval {
        let value = report.endedAt.timeIntervalSince(report.startedAt)
        return value.isFinite && value > 0 ? value : 1
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack(alignment: .topLeading) {
                ForEach(1..<4, id: \.self) { line in
                    let y = height * CGFloat(line) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: width, y: 0))
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: width, y: height))
                }
                .stroke(Color.white.opacity(0.12), lineWidth: 1)

                ForEach(report.timeline.indices, id: \.self) { index in
                    let segment = report.timeline[index]
                    let startFraction = min(max(segment.startDate.timeIntervalSince(report.startedAt) / span, 0), 1)
                    let endFraction = min(max(segment.endDate.timeIntervalSince(report.startedAt) / span, 0), 1)
                    let xStart = width * startFraction
                    let xEnd = width * endFraction
                    let y = height * level(for: segment.stage)
                    let barWidth = max(0, xEnd - xStart)

                    if index > 0, report.timeline[index - 1].endDate == segment.startDate {
                        let previousY = height * level(for: report.timeline[index - 1].stage)
                        Rectangle()
                            .fill(Self.color(for: segment.stage).opacity(0.86))
                            .frame(width: 3, height: max(2, abs(y - previousY)))
                            .position(x: xStart, y: (y + previousY) / 2)
                    }

                    Rectangle()
                        .fill(Self.color(for: segment.stage))
                        .frame(width: barWidth, height: 18)
                        .position(x: xStart + barWidth / 2, y: y)
                }

                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.move(to: CGPoint(x: width, y: 0))
                    path.addLine(to: CGPoint(x: width, y: height))
                }
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            }
            .clipShape(Rectangle())
            .padding(.vertical, 5)
        }
        .padding(.horizontal, 2)
    }

    private func level(for stage: SleepStageCategory) -> CGFloat {
        switch stage {
        case .awake: 0.10
        case .rem: 0.34
        case .core: 0.56
        case .asleepUnspecified: 0.58
        case .deep: 0.84
        }
    }

    private static func color(for stage: SleepStageCategory) -> Color {
        SleepReportView.color(for: stage)
    }
}

private struct SleepStageSummaryCard: View {
    let stage: SleepStageCategory
    let seconds: TimeInterval
    let percent: Double

    private var safePercent: Double {
        percent.isFinite ? min(max(percent, 0), 1) : 0
    }

    private var formattedDuration: String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let minutes = Int((seconds / 60).rounded())
        return "\(minutes / 60)ω \(minutes % 60)λ"
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stage.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(R0llingTheme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(formattedDuration)
                    .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(R0llingTheme.textPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text("\(Int((safePercent * 100).rounded()))%")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(SleepReportView.color(for: stage))
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Color.white.opacity(0.09), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: safePercent)
                    .stroke(SleepReportView.color(for: stage), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .r0llingSleepSurface(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}
