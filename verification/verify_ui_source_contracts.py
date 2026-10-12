#!/usr/bin/env python3
"""Catch a few UI source mismatches that a non-Apple host cannot type-check."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "Sources" / "R0lling"
APP_FILE = SOURCE_ROOT / "App" / "R0llingApp.swift"


def switch_cases(source: str, marker: str, search_from: int = 0) -> set[str]:
    start = source.index(marker, search_from)
    opening = source.index("{", start)
    depth = 0
    closing = opening
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                closing = index
                break
    body = source[opening + 1 : closing]
    return set(re.findall(r"^\s*case\s+\.([A-Za-z_]\w*)\s*:", body, re.MULTILINE))


def main() -> None:
    swift_files = sorted(SOURCE_ROOT.rglob("*.swift"))
    duplicate_builder = re.compile(r"@ViewBuilder\s*@ViewBuilder")
    duplicate_paths = [
        path.relative_to(ROOT).as_posix()
        for path in swift_files
        if duplicate_builder.search(path.read_text(encoding="utf-8"))
    ]
    if duplicate_paths:
        raise SystemExit(f"Duplicate @ViewBuilder attributes: {duplicate_paths}")

    app = APP_FILE.read_text(encoding="utf-8")
    enum_start = app.index("private enum QuickAction:")
    enum_open = app.index("{", enum_start)
    enum_depth = 0
    enum_close = enum_open
    for index in range(enum_open, len(app)):
        if app[index] == "{":
            enum_depth += 1
        elif app[index] == "}":
            enum_depth -= 1
            if enum_depth == 0:
                enum_close = index
                break
    enum_body = app[enum_open + 1 : enum_close]
    enum_cases = set(re.findall(r"^\s*case\s+([A-Za-z_]\w*)\s*$", enum_body, re.MULTILINE))
    expected_switches = {"openQuickAction": switch_cases(app, "switch action {")}

    # The enum has two separate `switch self` blocks; identify them in source order.
    self_switches = []
    search_from = 0
    while True:
        try:
            marker_index = enum_body.index("switch self {", search_from)
        except ValueError:
            break
        self_switches.append(switch_cases(enum_body, "switch self {", search_from))
        search_from = marker_index + len("switch self {")
    if len(self_switches) != 2:
        raise SystemExit(f"Expected two QuickAction presentation switches, found {len(self_switches)}")
    expected_switches["QuickAction.title"] = self_switches[0]
    expected_switches["QuickAction.symbol"] = self_switches[1]

    mismatches = {
        name: sorted(cases ^ enum_cases)
        for name, cases in expected_switches.items()
        if cases is None or cases != enum_cases
    }
    if mismatches:
        raise SystemExit(f"QuickAction enum/switch case mismatch: {mismatches}; enum={sorted(enum_cases)}")

    if "dynamicTypeSize.isAccessibilitySize ? 1 : 3" not in app:
        raise SystemExit("QuickAction grid must use three columns except at accessibility text sizes")

    fitness = (SOURCE_ROOT / "UI" / "FitnessView.swift").read_text(encoding="utf-8")
    fitness_grid_contract = (
        "case .xSmall, .small, .medium, .large, .xLarge: true",
        "private var dayCellSize: CGFloat { usesCompactMonthGrid ? 20.5 : 44 }",
        "private var monthGridSpacing: CGFloat { usesCompactMonthGrid ? 10 : 14 }",
        "private var monthGridWidth: CGFloat { dayCellSize * 7 }",
        "ScrollView(.horizontal, showsIndicators: true)",
    )
    missing_fitness_grid_contract = [item for item in fitness_grid_contract if item not in fitness]
    if missing_fitness_grid_contract:
        raise SystemExit(
            "Fitness must fit two compact months at standard text sizes, expand cells for XXL/accessibility text, "
            f"and retain a narrow-width horizontal fallback: {missing_fitness_grid_contract}"
        )

    today = (SOURCE_ROOT / "UI" / "TodayView.swift").read_text(encoding="utf-8")
    composer = (SOURCE_ROOT / "UI" / "TodayShareComposerView.swift").read_text(encoding="utf-8")
    header_start = today.index("private var headerView: some View {")
    header_end = today.index("private var glassesControlAccessibilityLabel:", header_start)
    header = today[header_start:header_end]
    if "ViewThatFits(in: .horizontal)" not in header or "lineLimit: 2" not in header or ".minimumScaleFactor(0.72)" in header:
        raise SystemExit("Today date header must wrap at narrow/accessibility widths without shrinking its large-title text")
    if "DatePicker(" not in today or "selection: $appState.selectedDate" not in today:
        raise SystemExit("Today date title must open a real date picker backed by the selected journal date")
    if ".onChange(of: appState.selectedDate)" not in today or "await appState.refreshEntries()" not in today:
        raise SystemExit("Changing the Today date must reload the selected day's journal entries")
    if "if isSelectedDayToday {" not in today or "historicalDayFooter" not in today:
        raise SystemExit("Historical Today browsing must not expose current-day note/share actions as historical data")
    if "if appState.isStreaming && isSelectedDayToday" not in today or "if isSelectedDayToday {\n                            DisclosureGroup" not in today:
        raise SystemExit("Historical Today browsing must hide current-day capture and productivity tools")
    if "isShareComposerPresented = true" not in today or "square.and.arrow.up" not in today:
        raise SystemExit("Today header must open the Bevel-style share composer")
    if 'Image(systemName: "gearshape.fill")' not in today or '.accessibilityLabel("Ρυθμίσεις")' not in today:
        raise SystemExit("The Today header settings action must use a truthful settings symbol and accessibility label")
    if "TodayShareComposerView(" not in today or "entries: appState.todayEntries" not in today or "health: appState.liveHealthSnapshot" not in today:
        raise SystemExit("Today share composer must receive the current journal and HealthKit snapshot")
    wellness = (SOURCE_ROOT / "UI" / "BiohackingHubView.swift").read_text(encoding="utf-8")
    if "HealthKitTelemetryCardView(" in today:
        raise SystemExit("Today must keep the Bevel-style daily summary uncluttered; detailed HealthKit metrics belong in the wellness tab")
    if "HealthKitTelemetryCardView(" not in wellness:
        raise SystemExit("The wellness tab must retain the detailed HealthKit metrics removed from Today")
    if "TodayHealthSummaryCard(" not in today or "onOpenHealth: onOpenHealth" not in today:
        raise SystemExit("Today must show the compact real-measurement preview and route to detailed HealthKit metrics")
    if today.index("BevelConcentricTelemetryCard(") > today.index("TodayHealthSummaryCard("):
        raise SystemExit("Today must lead with its three-ring Bevel-style hero before the compact health preview")
    assistant = (SOURCE_ROOT / "UI" / "AssistantView.swift").read_text(encoding="utf-8")
    observation_start = assistant.index("public struct ObservationGameSheet:")
    observation_end = assistant.index("private func trexeAxiologisiGyalion", observation_start)
    observation_game = assistant[observation_start:observation_end]
    if "if appState.isSimulationMode" not in observation_game:
        raise SystemExit("Observation Game must disclose when glasses capture is unavailable in simulation mode")
    if ".disabled(isEvaluating || appState.isSimulationMode || appState.currentMission?.isCompleted == true)" not in observation_game:
        raise SystemExit("Observation Game must disable the glasses camera action in simulation mode")
    if "Κάμερα γυαλιών μη διαθέσιμη σε Simulation" not in observation_game or "PhotosPicker(" not in observation_game:
        raise SystemExit("Simulation camera state must be accessible and keep photo-picker fallback available")
    settings = (SOURCE_ROOT / "UI" / "SettingsView.swift").read_text(encoding="utf-8")
    app_state = (SOURCE_ROOT / "App" / "AppState.swift").read_text(encoding="utf-8")
    if "await appState.setGlassesSimulationMode(enabled: val)" not in settings or "isSimulationMode = await glassesAdapter.isSimulationMode" not in app_state:
        raise SystemExit("Simulation setting changes must update the published state used by Observation Game")
    sleep_view = (SOURCE_ROOT / "UI" / "SleepReportView.swift").read_text(encoding="utf-8")
    sleep_service = (SOURCE_ROOT / "Core" / "HealthKitService.swift").read_text(encoding="utf-8")
    if "predicateForSamples(withStart: windowStart, end: windowEnd, options: [])" not in sleep_service:
        raise SystemExit("Overnight sleep queries must include all samples overlapping the report window")
    if "options: .strictStartDate)" in sleep_service:
        raise SystemExit("Overnight sleep queries must not drop samples that begin before the window")
    health_components = (SOURCE_ROOT / "UI" / "SovereignOSComponents.swift").read_text(encoding="utf-8")
    health_models = (SOURCE_ROOT / "Core" / "SovereignOSServices.swift").read_text(encoding="utf-8")
    if "error == nil" not in sleep_service or "didFailQuery: true" not in sleep_service:
        raise SystemExit("Sleep-stage HealthKit query errors must be distinct from successful no-data results")
    if "sleepQueryFailed: sleepResult.didFailQuery" not in sleep_service or "public let sleepQueryFailed: Bool?" not in health_models:
        raise SystemExit("Sleep-stage query status must survive in the telemetry snapshot")
    if "snapshot.sleepQueryFailed == true" not in health_components or "Δεν ήταν δυνατή η ανάκτηση δεδομένων ύπνου" not in health_components:
        raise SystemExit("A sleep-stage query failure must be visible in the Health UI")
    for expected in (
        "ForEach(SleepVitalMetric.allCases",
        "report.vitalSamples.filter { $0.metric == selectedVitalMetric }",
        "Το HealthKit δεν επέστρεψε διαθέσιμες μετρήσεις",
        "report.vitalQueryFailures.contains(selectedVitalMetric)",
        "Τα κενά δείχνουν διαστήματα χωρίς μέτρηση",
        "metric.maximumContinuousGap",
        ".accessibilityLabel(vitalChartAccessibilityLabel",
    ):
        if expected not in sleep_view:
            raise SystemExit(f"Sleep detail must provide an accessible source-backed vital chart: {expected}")
    sleep_body = sleep_view.split("public var body", 1)[1].split("private var header", 1)[0]
    if not (
        sleep_body.index("stageTimeline") <
        sleep_body.index("stageBreakdown") <
        sleep_body.index("overnightVitals")
    ):
        raise SystemExit("Sleep detail must follow the Bevel order: timeline, stage breakdown, overnight vitals")
    for expected in (
        "identifier = .heartRate",
        "identifier = .heartRateVariabilitySDNN",
        "identifier = .respiratoryRate",
        "identifier = .oxygenSaturation",
        "from: stageReport.startedAt",
        "to: stageReport.endedAt",
        "queryFailures: vitals.failures",
        "SleepEpisodeAggregator.attachingVitalSamples(",
    ):
        if expected not in sleep_service:
            raise SystemExit(f"Sleep vital channels must query real HealthKit samples within the primary episode: {expected}")
    info_plist = (ROOT / "Apps" / "R0llingApp" / "Info.plist").read_text(encoding="utf-8")
    if "καρδιακών παλμών ηρεμίας και κατά τον ύπνο" not in info_plist:
        raise SystemExit("HealthKit purpose text must explain the overnight heart-rate data used by sleep detail")
    podcast = (SOURCE_ROOT / "AI" / "DailyPodcastGenerator.swift").read_text(encoding="utf-8")
    if "pendingCompletion" in podcast or "completionRegistry.register(completion, for: utterance)" not in podcast:
        raise SystemExit("Daily Podcast completion handlers must be owned by their utterances")
    if "completionRegistry.discardAll()" not in podcast or "completionRegistry.take(for: utterance)?()" not in podcast:
        raise SystemExit("Daily Podcast completion lifecycle must distinguish stop, finish, and cancel callbacks")
    health_summary = (SOURCE_ROOT / "UI" / "SovereignOSComponents.swift").read_text(encoding="utf-8")
    if "public struct TodayHealthSummaryCard" not in health_summary or "Πρόσφατες μετρήσεις Apple Health" not in health_summary:
        raise SystemExit("Today HealthKit summary must label its values as recent readings, independent of selected journal date")
    if "glassesStatusChip" not in today or "Text(appState.glassesState.statusDescription)" not in today:
        raise SystemExit("Today must show the real glasses connection state in a visible status chip")
    assistant_view = (SOURCE_ROOT / "UI" / "AssistantView.swift").read_text(encoding="utf-8")
    meal_logger = (SOURCE_ROOT / "AI" / "MealNutritionVisionLogger.swift").read_text(encoding="utf-8")
    if "mealNutritionReview(estimate)" not in assistant_view or "savePendingNutritionEstimate()" not in assistant_view:
        raise SystemExit("The Assistant must offer a review card and explicit save action for OCR meal estimates")
    if "pendingNutritionEstimate" not in app_state or "prepareMealEstimateForReview(ocrTokens)" not in app_state:
        raise SystemExit("OCR food estimates from selected photos and real captures must enter the review state")
    if "await logMealFromDetectedTokens" in app_state or "try await storage.saveEntry(entry)" not in app_state:
        raise SystemExit("OCR analysis must not automatically persist a meal; persistence belongs to explicit confirmation")
    for expected in (
        "Ενδεικτική εκτίμηση γεύματος",
        "χρειάζεται έλεγχο και επιβεβαίωση πριν αποθηκευτεί",
        "δεν μετρήθηκαν",
    ):
        if expected not in assistant_view + meal_logger + app_state:
            raise SystemExit(f"Meal estimates must be labeled as heuristic and reviewable: {expected}")
    if "activeAITask?.cancel()\n        pendingNutritionEstimate = nil\n        pendingNutritionEstimateIsSaved = false" not in app_state:
        raise SystemExit("Starting a new vision analysis must invalidate any prior image's pending meal estimate")
    if "timestamp: snapshot.timestamp" not in app_state:
        raise SystemExit("A reviewed meal estimate must keep the analysis timestamp when it is saved later")
    for expected in (
        "estimate.mealType.rawValue", "estimate.timestamp.formatted",
        "item.estimatedGrams", "item.proteinGrams", "item.carbsGrams", "item.fatGrams",
        "estimate.totalProtein", "estimate.totalCarbs", "estimate.totalFat",
    ):
        if expected not in assistant_view:
            raise SystemExit(f"Meal review must expose every heuristic quantity that will be persisted: {expected}")
    for expected in (
        "private var overviewMetrics: [ShareComposerMetric]",
        "let firstMetricIndex = (page / 2 * 2) % metrics.count",
        "metrics[(firstMetricIndex + offset) % metrics.count]",
        "metric.visualProgress",
        "Κλίμακα απεικόνισης · όχι κλινικό εύρος",
        "HealthMetricDisplayScale.progress(for:",
        "ViewThatFits(in: .horizontal)",
        "actionBarControls(compact: true)",
    ):
        if expected not in composer:
            raise SystemExit(f"Today share overview must show all measured values with disclosed, non-clinical rings: {expected}")
    for expected in (
        "Επισκόπηση", "Διατροφή", "Σύνοψη", "Στρες", "Προσαρμογή",
        "Αποθήκευση εικόνας", "Αντιγραφή εικόνας", "ShareLink(",
        "@State private var includeJournalText = false", "Δεν υπάρχουν διαθέσιμες μετρήσεις στρες",
        "accessibilityReduceMotion", "frame(width: 44, height: 44)",
        "Δεν ήταν δυνατή η προετοιμασία της εικόνας.",
    ):
        if expected not in composer:
            raise SystemExit(f"Today share composer is missing expected source contract: {expected}")
    category_picker_start = composer.index("private var categoryPicker: some View {")
    category_picker_end = composer.index("private var previewCarousel: some View {", category_picker_start)
    category_picker = composer[category_picker_start:category_picker_end]
    if "ViewThatFits(in: .horizontal)" not in category_picker or ".scrollIndicators(.visible)" not in category_picker:
        raise SystemExit("Share categories must fit in one row when possible and expose scrolling when they do not")
    if "private func categoryButton(_ category: ShareComposerCategory" not in category_picker or "LinearGradient(" not in category_picker:
        raise SystemExit("Share category pills must keep their bevel-style treatment in both fitted and scrolling layouts")
    if "guard category != .stress" in category_picker or ".disabled(category == .stress)" in category_picker:
        raise SystemExit("The Stress tab must be selectable and show its honest no-data state")
    if "min(UIScreenSharePreview.maximumHeight, geometry.size.height)" not in composer:
        raise SystemExit("Today share preview cards must fit within the available vertical space without clipping")
    if "private var effectivePalette: ShareComposerPalette" not in composer or "category == .overview, page == 1" not in composer:
        raise SystemExit("The second default overview card must match the monochrome Bevel reference while preserving palette customization")
    preview_start = composer.index(".frame(width: geometry.size.width * 0.90")
    preview_end = composer.index(".frame(maxWidth: .infinity, maxHeight: .infinity)", preview_start)
    preview_card = composer[preview_start:preview_end]
    if "if page == 0" in preview_card or "Color.clear" in preview_card:
        raise SystemExit("Every Today share carousel card must retain a visible Bevel-style card surface")
    if '"Σχέδιο \\(selectedPage + 1) από 6"' in composer or '"Κάρτα \\(selectedPage + 1) από 6"' not in composer:
        raise SystemExit("Today share carousel accessibility must describe the pages as cards, not design variants")
    if not re.search(r"#if os\(iOS\)\s*\.presentationCornerRadius\(30\)\s*#endif", composer):
        raise SystemExit("Presentation corner-radius styling must be guarded to avoid the unsupported macOS modifier")
    if 'Image(systemName: "gearshape.fill")' not in today or '.accessibilityLabel("Ρυθμίσεις")' not in today:
        raise SystemExit("Today header must expose the truthful settings control")
    if "HStack(spacing: 4)" not in today or ".r0llingBevelSurface(cornerRadius: 28)" not in today:
        raise SystemExit("Today share/settings actions must share the upper-right bevel capsule")
    if "onOpenSettings: { selectedDestination = .settings }" not in app:
        raise SystemExit("Today settings control must route to Settings")
    if "glassesControlAccessibilityLabel" not in today or "eyeglasses" not in today:
        raise SystemExit("Today glasses action must remain accessible after header restyling")

    settings = (SOURCE_ROOT / "UI" / "SettingsView.swift").read_text(encoding="utf-8")
    state = (SOURCE_ROOT / "App" / "AppState.swift").read_text(encoding="utf-8")
    if "let telemetryDate = selectedDate" not in state or "includeActiveSession: selectedDateIsToday" not in state:
        raise SystemExit("Today productivity telemetry must use the selected date and exclude today's active focus from history")
    if "Παρακολούθηση δραστηριότητας φακέλου ενεργή" not in settings:
        raise SystemExit("Obsidian watcher must expose its active status in Settings")
    if "obsidianVaultChangeDetected" not in settings or "Η εισαγωγή και ο συγχρονισμός παραμένουν χειροκίνητα" not in settings:
        raise SystemExit("Obsidian watcher UI must describe its change hint and manual sync behavior")
    if "configureObsidianVaultWatcher(url:" not in state:
        raise SystemExit("AppState must connect the Obsidian watcher to vault selection/restoration")

    print(f"UI source contracts passed ({len(swift_files)} Swift files; {len(enum_cases)} QuickAction cases; Today share composer/header, controls, and Obsidian watcher status).")


if __name__ == "__main__":
    main()
