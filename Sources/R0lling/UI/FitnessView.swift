import SwiftUI

/// Activity-first Fitness surface inspired by Bevel's 30-day activity screen.
/// Every cell and total is derived from HealthKit workouts; no sample data is shown.
public struct FitnessView: View {
    @EnvironmentObject private var appState: AppState
    private let onOpenQuickActions: (() -> Void)?

    public init(onOpenQuickActions: (() -> Void)? = nil) {
        self.onOpenQuickActions = onOpenQuickActions
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fitness")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(R0llingTheme.textPrimary)
                        Text("Τελευταίες 30 ημέρες")
                            .font(.subheadline)
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    Spacer(minLength: 4)

                    if let onOpenQuickActions {
                        Button(action: onOpenQuickActions) {
                            Image(systemName: "plus")
                                .font(.system(size: 21, weight: .medium))
                                .foregroundColor(R0llingTheme.textPrimary)
                                .frame(width: 54, height: 54)
                                .background {
                                    Circle().fill(
                                        LinearGradient(
                                            colors: [R0llingTheme.bgElevated, R0llingTheme.bgSurface],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                }
                                .overlay {
                                    Circle().stroke(R0llingTheme.borderSubtle, lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Περισσότερες λειτουργίες")
                        .accessibilityHint("Ανοίγει το μενού γρήγορων ενεργειών.")
                    }
                }

                FitnessActivityCalendarCard(snapshot: appState.fitnessActivitySnapshot)

                if appState.fitnessActivitySnapshot.hasCurrentWorkouts {
                    FitnessActivitySummaryCard(snapshot: appState.fitnessActivitySnapshot)
                } else {
                    noWorkoutDataCard
                }
            }
            .padding(16)
        }
        .background(R0llingTheme.bgPrimary.ignoresSafeArea())
        .task { await appState.refreshFitnessActivity() }
        .refreshable { await appState.refreshFitnessActivity() }
    }

    private var noWorkoutDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Activity Summary", systemImage: "chart.xyaxis.line")
                .font(.headline.weight(.semibold))
                .foregroundColor(R0llingTheme.textPrimary)

            if !appState.fitnessActivitySnapshot.querySucceeded {
                Text("Το Apple Health δεν είναι διαθέσιμο ή δεν ολοκληρώθηκε η ανάγνωση προπονήσεων.")
                    .font(.body)
                    .foregroundColor(R0llingTheme.textSecondary)
            } else if appState.didCompleteHealthKitAccessRequest {
                Text("Δεν επιστράφηκαν προπονήσεις για αυτό το διάστημα. Το HealthKit δεν αποκαλύπτει αν η ανάγνωση εγκρίθηκε ή αν δεν υπάρχουν καταγραφές.")
                    .font(.body)
                    .foregroundColor(R0llingTheme.textSecondary)
            } else {
                Text("Σύνδεσε τις καταγραφές προπόνησης του Apple Health για να εμφανιστούν οι δραστηριότητες και η τάση 30 ημερών.")
                    .font(.body)
                    .foregroundColor(R0llingTheme.textSecondary)
                Button {
                    Task { await appState.requestHealthKitAccess() }
                } label: {
                    Label("Σύνδεση Apple Health", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .r0llingBevelCapsule()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 20)
    }
}

private struct FitnessActivityCalendarCard: View {
    let snapshot: FitnessActivitySnapshot
    private let weekdays = FitnessActivityWeekdayLabels.greekMondayFirst
    private let dayTargetSize: CGFloat = 44
    @State private var selectedDate: Date? = FitnessActivityCalendar.athensCalendar.startOfDay(for: .now)

    private var monthGridWidth: CGFloat { dayTargetSize * 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(monthBuckets) { month in
                        monthGrid(month)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(monthBuckets) { month in
                            monthGrid(month)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let selectedDay {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(R0llingTheme.accentCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FitnessActivityCalendar.formatted(selectedDay.date, template: "EEEE, d MMMM yyyy"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(R0llingTheme.textPrimary)
                            Text(selectedDay.workoutCount == 0
                                 ? "Δεν υπάρχουν προπονήσεις σε αυτή την ημέρα."
                                 : "\(selectedDay.workoutCount) προπονήσεις · \(FitnessActivitySummaryCard.durationText(selectedDay.durationSeconds))")
                                .font(.caption2)
                                .foregroundColor(R0llingTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)

                    ForEach(selectedDay.workouts) { workout in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(R0llingTheme.accentCyan)
                                .frame(width: 8, height: 8)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.activityName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(R0llingTheme.textPrimary)
                                Text("\(FitnessActivityCalendar.formatted(workout.startedAt, template: "HH:mm")) · \(FitnessActivitySummaryCard.durationText(workout.durationSeconds))")
                                    .font(.caption)
                                    .foregroundColor(R0llingTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(workout.activityName), ώρα \(FitnessActivityCalendar.formatted(workout.startedAt, template: "HH:mm")), διάρκεια \(FitnessActivitySummaryCard.durationText(workout.durationSeconds))")
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .r0llingBevelInsetSurface(cornerRadius: 12)
            }

            HStack(spacing: 10) {
                legend(color: R0llingTheme.accentLime, title: "1")
                legend(color: R0llingTheme.statusSuccess, title: "2")
                legend(color: R0llingTheme.accentCyan, title: "3+")
                Spacer(minLength: 0)
                Text("προπονήσεις / ημέρα")
                    .font(.caption2)
                    .foregroundColor(R0llingTheme.textMuted)
            }
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 20)
        .onChange(of: snapshot.currentDays) { previousDays, currentDays in
            let selectedDateIsInWindow = selectedDate.map { selected in
                currentDays.contains { $0.date == selected }
            } ?? false
            if !selectedDateIsInWindow || selectedDate == previousDays.last?.date {
                selectedDate = currentDays.last?.date
            }
        }
    }

    private func monthGrid(_ month: FitnessActivityMonthGrid) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(monthTitle(month.monthStart))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(R0llingTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(dayTargetSize), spacing: 0), count: 7), spacing: 0) {
                ForEach(weekdays.indices, id: \.self) { index in
                    Text(weekdays[index])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(R0llingTheme.textMuted)
                        .frame(width: dayTargetSize, height: dayTargetSize)
                        .accessibilityHidden(true)
                }

                ForEach(month.cells.indices, id: \.self) { index in
                    if let day = month.cells[index] {
                        dayButton(day)
                    } else {
                        Color.clear
                            .frame(width: dayTargetSize, height: dayTargetSize)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(width: monthGridWidth, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func dayButton(_ day: FitnessActivityDay) -> some View {
        let isSelected = selectedDate == day.date
        return Button {
            selectedDate = day.date
        } label: {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(activityColor(for: day.workoutCount))
                .frame(height: 13)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(R0llingTheme.accentCyan, lineWidth: 1.5)
                            .padding(-2)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(width: dayTargetSize, height: dayTargetSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedDay: FitnessActivityDay? {
        guard let selectedDate else { return nil }
        return snapshot.currentDays.first { $0.date == selectedDate }
    }

    private var monthBuckets: [FitnessActivityMonthGrid] {
        FitnessActivityMonthGrid.make(from: snapshot.currentDays)
    }

    private func monthTitle(_ date: Date) -> String {
        FitnessActivityCalendar.formatted(date, template: "MMM yyyy")
    }

    private func activityColor(for count: Int) -> Color {
        switch count {
        case 1: R0llingTheme.accentLime
        case 2: R0llingTheme.statusSuccess
        case 3...: R0llingTheme.accentCyan
        default: R0llingTheme.bgElevated.opacity(0.72)
        }
    }

    private func legend(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func accessibilityLabel(for day: FitnessActivityDay) -> String {
        let date = FitnessActivityCalendar.formatted(day.date, template: "EEEE, d MMMM yyyy")
        guard day.workoutCount > 0 else { return "\(date): καμία καταγεγραμμένη προπόνηση" }
        return "\(date): \(day.workoutCount) προπονήσεις, \(FitnessActivitySummaryCard.durationText(day.durationSeconds))"
    }
}

private struct FitnessActivitySummaryCard: View {
    let snapshot: FitnessActivitySnapshot
    @State private var isTrendExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Activity Summary", systemImage: "chart.xyaxis.line")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isTrendExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(R0llingTheme.textMuted)
                        .rotationEffect(isTrendExpanded ? .degrees(90) : .zero)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTrendExpanded ? "Σύμπτυξη γραφήματος δραστηριότητας" : "Ανάπτυξη γραφήματος δραστηριότητας")
            }

            Text(Self.durationText(snapshot.totalDurationSeconds))
                .font(.largeTitle.weight(.bold).monospacedDigit())
                .foregroundColor(R0llingTheme.textPrimary)
                .accessibilityLabel("Συνολική διάρκεια προπονήσεων: \(Self.durationText(snapshot.totalDurationSeconds))")

            HStack(alignment: .firstTextBaseline) {
                Text(dateRangeText)
                    .font(.footnote)
                    .foregroundColor(R0llingTheme.textSecondary)
                Spacer(minLength: 8)
                Text(comparisonText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(comparisonColor)
                    .multilineTextAlignment(.trailing)
            }

            FitnessActivityTrendChart(
                snapshot: snapshot,
                plotHeight: isTrendExpanded ? 190 : 100
            )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chartAccessibilityLabel)

            HStack(spacing: 16) {
                trendLegend(color: R0llingTheme.accentAmber, title: "Τρέχον διάστημα")
                trendLegend(color: R0llingTheme.textMuted, title: "Προηγούμενο διάστημα")
            }

            HStack {
                Text("\(snapshot.totalWorkoutCount) καταγεγραμμένες προπονήσεις")
                Spacer()
                Text("Σύγκριση 30 ημερών")
            }
            .font(.caption)
            .foregroundColor(R0llingTheme.textMuted)
        }
        .padding(16)
        .r0llingBevelSurface(cornerRadius: 20)
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return "\(minutes / 60)ω \(String(format: "%02d", minutes % 60))λ"
    }

    private var dateRangeText: String {
        guard let first = snapshot.currentDays.first?.date else { return "Τελευταίες 30 ημέρες" }
        return "\(FitnessActivityCalendar.formatted(first, template: "d MMM")) – \(FitnessActivityCalendar.formatted(snapshot.referenceDate, template: "d MMM"))"
    }

    private var comparisonText: String {
        guard snapshot.previousWorkoutCount > 0 else { return "Χωρίς προηγούμενες καταγραφές" }
        let delta = snapshot.totalDurationSeconds - snapshot.previousDurationSeconds
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(Self.durationText(abs(delta)))"
    }

    private var comparisonColor: Color {
        guard snapshot.previousWorkoutCount > 0 else { return R0llingTheme.textMuted }
        return snapshot.totalDurationSeconds >= snapshot.previousDurationSeconds
            ? R0llingTheme.statusSuccess
            : R0llingTheme.accentAmber
    }

    private var chartAccessibilityLabel: String {
        "Σωρευτική διάρκεια προπονήσεων 30 ημερών: \(Self.durationText(snapshot.totalDurationSeconds)). Προηγούμενο διάστημα: \(Self.durationText(snapshot.previousDurationSeconds))."
    }

    private func trendLegend(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 16, height: 3)
            Text(title)
                .font(.caption2)
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FitnessActivityTrendChart: View {
    let snapshot: FitnessActivitySnapshot
    let plotHeight: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Σωρευτική διάρκεια")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(R0llingTheme.textSecondary)
                Spacer()
                Text("ώρες")
                    .font(.caption2)
                    .foregroundColor(R0llingTheme.textMuted)
            }

            HStack(alignment: .top, spacing: 6) {
                GeometryReader { geometry in
                    let current = FitnessActivitySnapshot.cumulativeDurationHours(for: snapshot.currentDays)
                    let previous = FitnessActivitySnapshot.cumulativeDurationHours(for: snapshot.previousDays)
                    let maximum = trendScaleMaximumHours
                    let size = geometry.size

                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: size.height * 0.25))
                            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.25))
                            path.move(to: CGPoint(x: 0, y: size.height * 0.75))
                            path.addLine(to: CGPoint(x: size.width, y: size.height * 0.75))
                        }
                        .stroke(R0llingTheme.borderSubtle.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))

                        trendArea(current, size: size, maximum: maximum)
                            .fill(
                                LinearGradient(
                                    colors: [R0llingTheme.accentAmber.opacity(0.18), R0llingTheme.stravaFlame.opacity(0.025)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        trendPath(previous, size: size, maximum: maximum)
                            .stroke(R0llingTheme.textMuted.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        trendPath(current, size: size, maximum: maximum)
                            .stroke(
                                LinearGradient(
                                    colors: [R0llingTheme.accentAmber, R0llingTheme.stravaFlame],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        ForEach(snapshot.currentDays.indices.filter { snapshot.currentDays[$0].durationSeconds > 0 }, id: \.self) { index in
                            Circle()
                                .fill(R0llingTheme.stravaFlame)
                                .frame(width: 5, height: 5)
                                .position(point(at: index, value: current[index], size: size, maximum: maximum, count: current.count))
                        }
                    }
                }
                .frame(height: plotHeight)

                VStack(alignment: .trailing) {
                    Text("\(Int(ceil(trendScaleMaximumHours)))ω")
                    Spacer(minLength: 0)
                    Text("0ω")
                }
                .font(.caption2)
                .foregroundColor(R0llingTheme.textMuted)
                .frame(height: plotHeight)
            }

            HStack {
                Text(axisDate(snapshot.currentDays.first?.date))
                Spacer(minLength: 8)
                Text(axisDate(snapshot.currentDays.dropFirst(14).first?.date))
                Spacer(minLength: 8)
                Text(axisDate(snapshot.referenceDate))
            }
            .font(.caption2)
            .foregroundColor(R0llingTheme.textMuted)
        }
        .accessibilityHidden(true)
    }

    private var trendScaleMaximumHours: Double {
        let totalHours = max(snapshot.totalDurationSeconds, snapshot.previousDurationSeconds) / 3_600
        return max(totalHours * 1.18, 1)
    }

    private func axisDate(_ date: Date?) -> String {
        guard let date else { return "" }
        FitnessActivityCalendar.formatted(date, template: "d MMM")
    }

    private func point(
        at index: Int,
        value: Double,
        size: CGSize,
        maximum: Double,
        count: Int
    ) -> CGPoint {
        let x = size.width * CGFloat(index) / CGFloat(max(count - 1, 1))
        let y = size.height * (1 - CGFloat(value / maximum))
        return CGPoint(x: x, y: y)
    }

    private func trendArea(_ values: [Double], size: CGSize, maximum: Double) -> Path {
        Path { path in
            guard !values.isEmpty else { return }
            let first = point(at: 0, value: values[0], size: size, maximum: maximum, count: values.count)
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            for index in values.indices.dropFirst() {
                path.addLine(to: point(at: index, value: values[index], size: size, maximum: maximum, count: values.count))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: first.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func trendPath(_ values: [Double], size: CGSize, maximum: Double) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let chartPoint = point(at: index, value: value, size: size, maximum: maximum, count: values.count)
                if index == 0 {
                    path.move(to: chartPoint)
                } else {
                    path.addLine(to: chartPoint)
                }
            }
        }
    }
}
