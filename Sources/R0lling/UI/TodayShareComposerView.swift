import SwiftUI
import UniformTypeIdentifiers

#if canImport(ImageIO)
import ImageIO
#endif

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Bevel-inspired image share composer. The cards use only journal and HealthKit values supplied by TodayView.
struct TodayShareComposerView: View {
    let entries: [JournalEntry]
    let health: HealthKitTelemetrySnapshot

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedCategory: ShareComposerCategory = .overview
    @State private var selectedPage = 0
    @State private var showingCustomize = false
    @State private var showingFileExporter = false
    @State private var includeDate = true
    @State private var includeBrand = true
    @State private var includeJournalText = false
    @State private var palette: ShareComposerPalette = .bevel
    @State private var renderedPNG: Data?
    @State private var exportDocument = ShareComposerPNGDocument(data: Data())
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    composerHeader
                    categoryPicker
                    previewCarousel
                    pageIndicators
                    customizeButton
                }
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(R0llingTheme.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #if os(iOS)
        .presentationCornerRadius(30)
        #endif
        .fileExporter(
            isPresented: $showingFileExporter,
            document: exportDocument,
            contentType: .png,
            defaultFilename: "R0lling-\(Date.now.formatted(.dateTime.year().month().day()))"
        ) { result in
            if case let .failure(error) = result {
                statusMessage = "Δεν αποθηκεύτηκε η εικόνα: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showingCustomize) {
            customizeSheet
        }
        .task(id: renderIdentity) {
            renderedPNG = nil
            statusMessage = nil
            await Task.yield()
            guard !Task.isCancelled else { return }
            let image = renderCurrentCard()
            guard !Task.isCancelled else { return }
            renderedPNG = image
            if image == nil {
                statusMessage = "Δεν ήταν δυνατή η προετοιμασία της εικόνας."
            }
        }
    }

    private var composerHeader: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .frame(width: 56, height: 56)
                    .r0llingBevelSurface(cornerRadius: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Κλείσιμο κοινοποίησης")

            Spacer(minLength: 8)
            VStack(spacing: 4) {
                Text("Κοινοποίηση")
                    .font(.title2.weight(.bold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Text("Η σύνοψή σου σε μια εικόνα")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(R0llingTheme.textSecondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)

            Color.clear
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
    }

    private var categoryPicker: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                ForEach(ShareComposerCategory.allCases) { category in
                    categoryButton(category, horizontalPadding: 8)
                }
            }
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(ShareComposerCategory.allCases) { category in
                        categoryButton(category, horizontalPadding: 13)
                    }
                }
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.visible)
        }
    }

    private func categoryButton(_ category: ShareComposerCategory, horizontalPadding: CGFloat) -> some View {
        Button {
            selectedCategory = category
            selectedPage = 0
            statusMessage = nil
        } label: {
            Text(category.title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(category == selectedCategory ? R0llingTheme.textPrimary : R0llingTheme.textSecondary)
                .padding(.horizontal, horizontalPadding)
                .frame(height: 44)
                .background {
                    Capsule()
                        .fill(category == selectedCategory ? R0llingTheme.bgElevated : R0llingTheme.bgSurface)
                }
                .overlay {
                    Capsule().stroke(
                        LinearGradient(
                            colors: category == selectedCategory
                                ? [Color.white.opacity(0.11), R0llingTheme.borderFocus, Color.black.opacity(0.25)]
                                : [Color.white.opacity(0.055), R0llingTheme.borderSubtle.opacity(0.55), Color.black.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: category == selectedCategory ? 1 : 0.7
                    )
                }
                .shadow(color: Color.black.opacity(category == selectedCategory ? 0.2 : 0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(category.title)
        .accessibilityHint(category == .stress ? "Επιλέγει την κατηγορία· δεν υπάρχουν διαθέσιμες μετρήσεις στρες." : "Επιλέγει αυτή την κατηγορία εικόνας.")
        .accessibilityAddTraits(category == selectedCategory ? .isSelected : [])
    }

    private var previewCarousel: some View {
        GeometryReader { geometry in
            let cardWidth = min(
                max(geometry.size.width * 0.80, 220),
                min(UIScreenSharePreview.maximumHeight, geometry.size.height)
            )
            let cardStride = cardWidth + 14

            HStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { page in
                    ZStack {
                        ShareComposerCheckerboard()
                        ShareComposerCardArtwork(
                            category: selectedCategory,
                            page: page,
                            date: Date(),
                            metrics: healthMetrics,
                            entries: visibleEntries,
                            nutritionCount: nutritionEntries.count,
                            includeDate: includeDate,
                            includeBrand: includeBrand,
                            includeJournalText: includeJournalText,
                            palette: palette
                        )
                    }
                    .frame(width: cardWidth, height: cardWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                    .scaleEffect(selectedPage == page ? 1 : 0.96)
                    .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.84), value: selectedPage)
                    .accessibilityHidden(selectedPage != page)
                }
            }
            .offset(x: (geometry.size.width - cardWidth) / 2 - CGFloat(selectedPage) * cardStride)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.width < -36 { selectedPage = min(5, selectedPage + 1) }
                        if value.translation.width > 36 { selectedPage = max(0, selectedPage - 1) }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Προεπισκόπηση εικόνας")
            .accessibilityValue("Κάρτα \(selectedPage + 1) από 6")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: selectedPage = min(5, selectedPage + 1)
                case .decrement: selectedPage = max(0, selectedPage - 1)
                @unknown default: break
                }
            }
        }
        .frame(height: min(UIScreenSharePreview.maximumHeight, UIScreenSharePreview.preferredHeight))
        .clipped()
    }

    private var pageIndicators: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { page in
                Button {
                    selectedPage = page
                } label: {
                    Circle()
                        .fill(page == selectedPage ? R0llingTheme.textPrimary : R0llingTheme.textMuted.opacity(0.58))
                        .frame(width: page == selectedPage ? 9 : 8, height: page == selectedPage ? 9 : 8)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Κάρτα \(page + 1) από 6")
                .accessibilityAddTraits(page == selectedPage ? .isSelected : [])
            }
        }
    }

    private var customizeButton: some View {
        Button {
            showingCustomize = true
        } label: {
            Label("Προσαρμογή", systemImage: "paintbrush.fill")
                .font(.headline.weight(.semibold))
                .foregroundColor(R0llingTheme.textPrimary)
                .padding(.horizontal, 26)
                .frame(height: 52)
                .r0llingBevelSurface(cornerRadius: 28)
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(R0llingTheme.borderSubtle.opacity(0.45))
                .frame(height: 1)

            ViewThatFits(in: .horizontal) {
                actionBarControls(compact: false)
                actionBarControls(compact: true)
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(R0llingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .accessibilityLiveRegion(.polite)
            }
        }
        .padding(.horizontal, 18)
        .background(R0llingTheme.bgPrimary)
    }

    @ViewBuilder
    private func actionBarControls(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 8 : 20) {
            actionButton(title: "Αποθήκευση", systemImage: "square.and.arrow.down", label: "Αποθήκευση εικόνας", compact: compact) {
                guard let renderedPNG else { return }
                exportDocument = ShareComposerPNGDocument(data: renderedPNG)
                showingFileExporter = true
                statusMessage = nil
            }
            .frame(maxWidth: compact ? .infinity : nil)

            actionButton(title: "Αντιγραφή", systemImage: "square.on.square", label: "Αντιγραφή εικόνας", compact: compact) {
                copyRenderedImage()
            }
            .frame(maxWidth: compact ? .infinity : nil)

            if let renderedPNG {
                ShareLink(
                    item: ShareComposerPNG(data: renderedPNG),
                    preview: SharePreview("R0lling — \(selectedCategory.title)")
                ) {
                    actionIcon(title: "Κοινοποίηση", systemImage: "square.and.arrow.up", compact: compact)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: compact ? .infinity : nil)
                .accessibilityLabel("Κοινοποίηση εικόνας")
                .accessibilityHint("Ανοίγει τις διαθέσιμες επιλογές κοινοποίησης.")
            } else {
                actionIcon(title: "Κοινοποίηση", systemImage: "square.and.arrow.up", compact: compact)
                    .opacity(0.45)
                    .frame(maxWidth: compact ? .infinity : nil)
                    .accessibilityLabel("Η εικόνα ετοιμάζεται")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(title: String, systemImage: String, label: String, compact: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionIcon(title: title, systemImage: systemImage, compact: compact)
        }
        .buttonStyle(.plain)
        .disabled(renderedPNG == nil)
        .opacity(renderedPNG == nil ? 0.45 : 1)
        .accessibilityLabel(label)
        .accessibilityHint("Χρησιμοποιεί την τρέχουσα προεπισκόπηση PNG.")
    }

    private func actionIcon(title: String, systemImage: String, compact: Bool = false) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(R0llingTheme.textPrimary)
                .frame(width: compact ? 56 : 68, height: compact ? 56 : 68)
                .r0llingBevelSurface(cornerRadius: compact ? 28 : 34)
            if compact {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 32)
            } else {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 88, minHeight: 32)
            }
        }
        .contentShape(Rectangle())
    }

    private var customizeSheet: some View {
        NavigationStack {
            Form {
                Toggle("Ημερομηνία", isOn: $includeDate)
                Toggle("Σήμανση R0lling", isOn: $includeBrand)
                Toggle("Κείμενο καταγραφών", isOn: $includeJournalText)
                Picker("Χρωματική εμφάνιση", selection: $palette) {
                    ForEach(ShareComposerPalette.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(R0llingTheme.bgPrimary)
            .tint(R0llingTheme.accentLavender)
            .navigationTitle("Προσαρμογή εικόνας")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Έτοιμο") { showingCustomize = false }
                        .foregroundColor(R0llingTheme.accentLavender)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var healthMetrics: [ShareComposerMetric] {
        var values: [ShareComposerMetric] = []
        if let seconds = health.sleepReport?.asleepSeconds, seconds > 0 {
            let hours = seconds / 3600
            values.append(.init(title: "Ύπνος", value: "\(formatted(hours, digits: 1)) h", measuredValue: hours, displayRange: 0...12))
        } else if let hours = health.sleepHours, hours > 0 {
            values.append(.init(title: "Ύπνος", value: "\(formatted(hours, digits: 1)) h", measuredValue: hours, displayRange: 0...12))
        }
        if let restingHR = health.restingHRBpm {
            values.append(.init(title: "Ηρεμία", value: "\(restingHR) bpm", measuredValue: Double(restingHR), displayRange: 0...220))
        }
        if let hrv = health.hrvMs {
            values.append(.init(title: "HRV", value: "\(formatted(hrv)) ms", measuredValue: hrv, displayRange: 0...200))
        }
        if let respiratory = health.respiratoryRate {
            values.append(.init(title: "Αναπνοές", value: "\(formatted(respiratory, digits: 1))/min", measuredValue: respiratory, displayRange: 0...60))
        }
        if let oxygen = health.bloodOxygenPercent {
            values.append(.init(title: "Οξυγόνο", value: "\(formatted(oxygen, digits: 1))%", measuredValue: oxygen, displayRange: 0...100))
        }
        if let temperature = health.bodyTemperatureCelsius {
            values.append(.init(title: "Θερμοκρασία", value: "\(formatted(temperature, digits: 1))°C", measuredValue: temperature, displayRange: 30...43))
        }
        return values
    }

    private var nutritionEntries: [JournalEntry] {
        let keywords = Set(["meal", "nutrition", "food", "φαγητο", "διατροφη", "γευμα"])
        return entries.filter { entry in
            entry.tags.contains { tag in
                let normalized = tag.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "el_GR"))
                return keywords.contains(normalized)
            }
        }
    }

    private var visibleEntries: [JournalEntry] {
        selectedCategory == .nutrition ? nutritionEntries : entries
    }

    private var renderIdentity: String {
        let journalRevision = visibleEntries.map { "\($0.id.uuidString):\($0.lastModified.timeIntervalSince1970)" }.joined(separator: ",")
        let readings = healthMetrics.map { "\($0.title)=\($0.value)" }.joined(separator: ",")
        return "\(selectedCategory.rawValue)|\(selectedPage)|\(includeDate)|\(includeBrand)|\(includeJournalText)|\(palette.rawValue)|\(journalRevision)|\(readings)|\(health.queriedAt.timeIntervalSince1970)"
    }

    private func formatted(_ value: Double, digits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.maximumFractionDigits = digits
        formatter.minimumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    @MainActor
    private func renderCurrentCard() -> Data? {
        #if canImport(ImageIO)
        let artwork = ShareComposerCardArtwork(
            category: selectedCategory,
            page: selectedPage,
            date: Date(),
            metrics: healthMetrics,
            entries: visibleEntries,
            nutritionCount: nutritionEntries.count,
            includeDate: includeDate,
            includeBrand: includeBrand,
            includeJournalText: includeJournalText,
            palette: palette
        )
        let renderer = ImageRenderer(content: artwork.frame(width: 1080, height: 1080))
        renderer.scale = 1
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
        #else
        return nil
        #endif
    }

    private func copyRenderedImage() {
        guard let renderedPNG else { return }
        #if canImport(UIKit)
        UIPasteboard.general.setData(renderedPNG, forPasteboardType: UTType.png.identifier)
        statusMessage = "Η εικόνα αντιγράφηκε."
        #elseif canImport(AppKit)
        if let image = NSImage(data: renderedPNG) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
            statusMessage = "Η εικόνα αντιγράφηκε."
        } else {
            statusMessage = "Δεν ήταν δυνατή η ανάγνωση της εικόνας."
        }
        #else
        statusMessage = "Η αντιγραφή εικόνας δεν είναι διαθέσιμη σε αυτή την πλατφόρμα."
        #endif
    }
}

private enum ShareComposerCategory: String, CaseIterable, Identifiable {
    case overview
    case nutrition
    case summary
    case stress

    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: "Επισκόπηση"
        case .nutrition: "Διατροφή"
        case .summary: "Σύνοψη"
        case .stress: "Στρες"
        }
    }
}

private enum ShareComposerPalette: String, CaseIterable, Identifiable {
    case bevel
    case monochrome

    var id: String { rawValue }
    var title: String { self == .bevel ? "Bevel" : "Μονόχρωμη" }
    func accent(for page: Int) -> Color {
        if self == .monochrome { return Color(hex: 0xE7E7EC) }
        return [R0llingTheme.accentAmber, R0llingTheme.accentLime, R0llingTheme.accentCyan, R0llingTheme.accentLavender][page % 4]
    }
}

private struct ShareComposerMetric: Identifiable {
    let title: String
    let value: String
    let visualProgress: Double?

    init(title: String, value: String, measuredValue: Double, displayRange: ClosedRange<Double>) {
        self.title = title
        self.value = value
        self.visualProgress = HealthMetricDisplayScale.progress(for: measuredValue, within: displayRange)
    }

    var id: String { title }
}

private struct ShareComposerCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 18
            let rows = Int(ceil(size.height / tile))
            let columns = Int(ceil(size.width / tile))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.13)))
                }
            }
        }
        .background(Color(hex: 0x3B3C43))
        .accessibilityHidden(true)
    }
}

private struct ShareComposerCardArtwork: View {
    let category: ShareComposerCategory
    let page: Int
    let date: Date
    let metrics: [ShareComposerMetric]
    let entries: [JournalEntry]
    let nutritionCount: Int
    let includeDate: Bool
    let includeBrand: Bool
    let includeJournalText: Bool
    let palette: ShareComposerPalette

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 1080
            let accent = effectivePalette.accent(for: page)
            VStack(spacing: 0) {
                HStack(spacing: 12 * scale) {
                    if includeBrand {
                        Text("R")
                            .font(.system(size: 34 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(R0llingTheme.bgPrimary)
                            .frame(width: 56 * scale, height: 56 * scale)
                            .background(accent, in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 3 * scale) {
                        if includeBrand {
                            Text("R0lling")
                                .font(.system(size: 28 * scale, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                        Text(category.title.uppercased())
                            .font(.system(size: 17 * scale, weight: .heavy, design: .monospaced))
                            .tracking(1.2 * scale)
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                    Spacer(minLength: 4 * scale)
                    if includeDate {
                        Text(greekDate(date))
                            .font(.system(size: 20 * scale, weight: .semibold))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }
                }

                Spacer(minLength: 18 * scale)
                cardContent(scale: scale, accent: accent)
                Spacer(minLength: 18 * scale)

                HStack(spacing: 8 * scale) {
                    Image(systemName: "waveform.path")
                    Text("Προσωπική σύνοψη")
                }
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundColor(R0llingTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(36 * scale)
            .frame(width: geometry.size.width * 0.90, height: geometry.size.height * 0.48)
            .background {
                RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                    .fill(LinearGradient(
                        colors: effectivePalette == .monochrome
                            ? [Color(hex: 0x17181C), Color(hex: 0x22232A)]
                            : [Color(hex: 0x202128), Color(hex: 0x111216)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 32 * scale, style: .continuous)
                    .stroke(Color.white.opacity(0.13), lineWidth: max(1, scale * 2))
            }
            .shadow(color: Color.black.opacity(0.28), radius: 18 * scale, x: 0, y: 10 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func cardContent(scale: CGFloat, accent: Color) -> some View {
        switch category {
        case .overview:
            if metrics.isEmpty {
                emptyDataMessage("Δεν υπάρχουν διαθέσιμες μετρήσεις")
            } else {
                VStack(spacing: 18 * scale) {
                    HStack(spacing: 6 * scale) {
                        ForEach(overviewMetrics.indices, id: \.self) { index in
                            let metric = overviewMetrics[index]
                            metricView(metric, scale: scale, accent: metricAccent(at: index))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    Text("Κλίμακα απεικόνισης · όχι κλινικό εύρος")
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundColor(R0llingTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12 * scale)
                .padding(.vertical, 12 * scale)
                .background {
                    if page == 0 {
                        RoundedRectangle(cornerRadius: 24 * scale, style: .continuous)
                            .fill(Color(hex: 0x101115))
                    } else {
                        Color.clear
                    }
                }
            }
        case .nutrition:
            if nutritionCount == 0 {
                emptyDataMessage("Δεν υπάρχουν καταγραφές διατροφής")
            } else {
                VStack(spacing: 10 * scale) {
                    Text("\(nutritionCount)")
                        .font(.system(size: 88 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                    Text(nutritionCount == 1 ? "ΚΑΤΑΓΡΑΦΗ ΓΕΥΜΑΤΟΣ" : "ΚΑΤΑΓΡΑΦΕΣ ΓΕΥΜΑΤΩΝ")
                        .font(.system(size: 18 * scale, weight: .heavy, design: .monospaced))
                        .foregroundColor(R0llingTheme.textPrimary)
                    if includeJournalText {
                        entryLines(scale: scale, limit: page == 4 ? 1 : 2)
                    }
                    if entries.contains(where: { $0.tags.contains("heuristic") }) {
                        Text("Περιλαμβάνει εκτιμήσεις από καταγραφές")
                            .font(.system(size: 13 * scale, weight: .medium))
                            .foregroundColor(R0llingTheme.textMuted)
                    }
                }
            }
        case .summary:
            VStack(alignment: .leading, spacing: 12 * scale) {
                HStack(alignment: .firstTextBaseline, spacing: 12 * scale) {
                    Text("\(entries.count)")
                        .font(.system(size: 76 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                    Text(entries.count == 1 ? "ΚΑΤΑΓΡΑΦΗ ΣΗΜΕΡΑ" : "ΚΑΤΑΓΡΑΦΕΣ ΣΗΜΕΡΑ")
                        .font(.system(size: 17 * scale, weight: .heavy, design: .monospaced))
                        .foregroundColor(R0llingTheme.textPrimary)
                }
                Text("\(metrics.count) διαθέσιμες μετρήσεις υγείας")
                    .font(.system(size: 18 * scale, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
                if includeJournalText { entryLines(scale: scale, limit: page == 4 ? 1 : 2) }
            }
        case .stress:
            emptyDataMessage("Δεν υπάρχουν διαθέσιμες μετρήσεις στρες")
        }
    }

    private var effectivePalette: ShareComposerPalette {
        if palette == .bevel, category == .overview, page == 1 {
            return .monochrome
        }
        return palette
    }

    private var overviewMetrics: [ShareComposerMetric] {
        guard !metrics.isEmpty else { return [] }
        let count = min(3, metrics.count)
        // Each adjacent pair presents the same readings as two share-card variants.
        let firstMetricIndex = (page / 2 * 2) % metrics.count
        return (0..<count).map { offset in
            metrics[(firstMetricIndex + offset) % metrics.count]
        }
    }

    private func metricAccent(at index: Int) -> Color {
        guard effectivePalette != .monochrome else { return Color(hex: 0xE7E7EC) }
        let colors = [R0llingTheme.accentAmber, R0llingTheme.accentLime, R0llingTheme.accentCyan, R0llingTheme.accentLavender]
        return colors[index % colors.count]
    }

    private func metricView(_ metric: ShareComposerMetric, scale: CGFloat, accent: Color) -> some View {
        VStack(spacing: 8 * scale) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x25262D))
                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 7 * scale)
                if let visualProgress = metric.visualProgress {
                    Circle()
                        .trim(from: 0, to: visualProgress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 7 * scale, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(metric.value)
                    .font(.system(size: 29 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .padding(.horizontal, 7 * scale)
            }
            .frame(width: 132 * scale, height: 132 * scale)
            Text(metric.title)
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundColor(R0llingTheme.textSecondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title), \(metric.value)")
        .accessibilityValue("Η κλίμακα είναι μόνο για απεικόνιση, όχι κλινικό εύρος.")
    }

    private func emptyDataMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(R0llingTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 90)
    }

    private func greekDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "el_GR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func entryLines(scale: CGFloat, limit: Int) -> some View {
        let lines = entries.prefix(limit).map { entry -> String in
            let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let text = title.flatMap { $0.isEmpty ? nil : $0 } ?? entry.content
            let safeText = text.replacingOccurrences(of: "\n", with: " ")
            let prefix = entry.tags.contains("heuristic") ? "Εκτίμηση · " : ""
            return prefix + String(safeText.prefix(74))
        }
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 6 * scale) {
                ForEach(lines.indices, id: \.self) { index in
                    Text("• \(lines[index])")
                        .font(.system(size: 15 * scale, weight: .regular))
                        .foregroundColor(R0llingTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private enum UIScreenSharePreview {
    static let preferredHeight: CGFloat = 380
    static let maximumHeight: CGFloat = 440
}

private struct ShareComposerPNG: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in image.data }
    }
}

private struct ShareComposerPNGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
