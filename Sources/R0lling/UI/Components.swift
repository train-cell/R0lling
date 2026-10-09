import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(AVKit)
import AVKit
#endif

#if canImport(ImageIO)
import ImageIO
#endif

/// Visible label for sample-only UI cards.
public struct PrototypeNotice: View {
    public init() {}
    public var body: some View {
        Text("ΠΡΟΕΠΙΣΚΟΠΗΣΗ — Τα παρακάτω είναι δείγματα UI. Δεν είναι προσωπικές μετρήσεις ή συνδεδεμένες υπηρεσίες.")
            .font(.caption)
            .foregroundColor(R0llingTheme.accentLavender)
            .padding(12)
            .r0llingCard()
    }
}

/// Decode a bounded display-size thumbnail without first loading the full source file into memory.
private func imageThumbnail(from url: URL, maximumPixelSize: Int) -> Image? {
    #if canImport(ImageIO) && canImport(UIKit)
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(1, maximumPixelSize),
        kCGImageSourceShouldCacheImmediately: true
    ] as CFDictionary
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    return Image(uiImage: UIImage(cgImage: thumbnail))
    #elseif canImport(ImageIO) && canImport(AppKit)
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(1, maximumPixelSize),
        kCGImageSourceShouldCacheImmediately: true
    ] as CFDictionary
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
    let size = NSSize(width: CGFloat(thumbnail.width), height: CGFloat(thumbnail.height))
    return Image(nsImage: NSImage(cgImage: thumbnail, size: size))
    #else
    return nil
    #endif
}

/// Bevel-style Concentric 3-Ring Visualization (Buffer, Captures Target, Vault Status)
public struct BevelConcentricRingsView: View {
    public let bufferRatio: Double    // 0.0 ... 1.0 (Ring 1: Outer Cyan)
    public let clipsRatio: Double     // 0.0 ... 1.0 (Ring 2: Middle Purple)
    public let batteryRatio: Double   // 0.0 ... 1.0 (Ring 3: Inner Emerald)

    public init(bufferRatio: Double = 0, clipsRatio: Double = 0, batteryRatio: Double = 0) {
        self.bufferRatio = min(max(bufferRatio, 0.0), 1.0)
        self.clipsRatio = min(max(clipsRatio, 0.0), 1.0)
        self.batteryRatio = min(max(batteryRatio, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            // Ring 1: Buffer Health (Outer - warm amber)
            Circle()
                .stroke(R0llingTheme.accentAmber.opacity(0.18), lineWidth: 8)
                .frame(width: 96, height: 96)
            Circle()
                .trim(from: 0.0, to: CGFloat(bufferRatio))
                .stroke(
                    R0llingTheme.accentAmber,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)

            // Ring 2: Clips Target (Middle - lime)
            Circle()
                .stroke(R0llingTheme.accentLime.opacity(0.18), lineWidth: 8)
                .frame(width: 74, height: 74)
            Circle()
                .trim(from: 0.0, to: CGFloat(clipsRatio))
                .stroke(
                    R0llingTheme.accentLime,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 74, height: 74)

            // Ring 3: Hardware Battery / Vault (Inner - periwinkle)
            Circle()
                .stroke(R0llingTheme.accentCyan.opacity(0.18), lineWidth: 8)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0.0, to: CGFloat(batteryRatio))
                .stroke(
                    R0llingTheme.accentCyan,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 52)

            // Central Icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(R0llingTheme.accentLavender)
        }
        .frame(width: 104, height: 104)
    }
}

/// Hero Telemetry Card (Bevel 3-Metrics Summary + Strava Athletic Card)
public struct BevelTelemetryCard: View {
    public let bufferDuration: Double
    public let todayClipsCount: Int
    public let isStreaming: Bool
    public var isSimulation: Bool = true
    public let glassesStatus: String

    public init(
        bufferDuration: Double,
        todayClipsCount: Int,
        isStreaming: Bool,
        glassesStatus: String
    ) {
        self.bufferDuration = bufferDuration
        self.todayClipsCount = todayClipsCount
        self.isStreaming = isStreaming
        self.glassesStatus = glassesStatus
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Top Status Bar: Hardware Chip & Telemetry Pill
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isStreaming ? R0llingTheme.accentPurple : R0llingTheme.bevelEmerald)
                        .frame(width: 8, height: 8)
                    Text(glassesStatus.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(R0llingTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(R0llingTheme.bgElevated)
                .clipShape(Capsule())
                .r0llingBevelCapsule()

                Spacer()

                // Strava Style "ACTIVE TELEMETRY"
                Text("POV ROLLING BUFFER")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
                    .tracking(1.2)
            }

            // Middle: Concentric Rings + 3 Key Metrics
            HStack(spacing: 20) {
                // Bevel 3-Ring Chart
                BevelConcentricRingsView(
                    bufferRatio: min(bufferDuration / 10.0, 1.0),
                    clipsRatio: min(Double(todayClipsCount) / 10.0, 1.0),
                    batteryRatio: 0
                )

                // 3 Metrics Breakdown
                VStack(alignment: .leading, spacing: 10) {
                    // Metric 1: Buffer
                    HStack(spacing: 8) {
                        Circle()
                            .fill(R0llingTheme.bevelCyan)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("BUFFER CAPACITY")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(R0llingTheme.textMuted)
                            Text(String(format: "%.1fs / 10.0s", bufferDuration))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }

                    // Metric 2: Today Clips
                    HStack(spacing: 8) {
                        Circle()
                            .fill(R0llingTheme.accentPurple)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TODAY'S CLIPS")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(R0llingTheme.textMuted)
                            Text("\(todayClipsCount) CLIPS CAPTURED")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }

                    // Metric 3: Resolution & Storage
                    HStack(spacing: 8) {
                        Circle()
                            .fill(R0llingTheme.bevelEmerald)
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("VIDEO STREAM")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(R0llingTheme.textMuted)
                            Text(isSimulation ? "SYNTHETIC BUFFER" : "FORMAT UNAVAILABLE")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }
                }

                Spacer()
            }

            // Coaching Target Strip (Bevel-style target range)
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(R0llingTheme.accentLavender)
                    .font(.system(size: 12))
                Text("Rolling Target: 10s Circular Ring actively caching keyframes in RAM.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
                Spacer()
            }
            .padding(10)
            .background(R0llingTheme.bgElevated.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(R0llingTheme.heroCardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

/// Κάρτα καταχώρισης στο στυλ Strava Activity Card
public struct TimelineEntryCard: View {
    public let entry: JournalEntry
    /// `true` μόνο αν έχει γίνει πραγματικό Obsidian export σε αυτή τη συνεδρία/config.
    public var einaiObsidianSync: Bool
    public var onFavoriteToggle: (() -> Void)?
    public var onDelete: (() -> Void)?
    public var onEdit: (() -> Void)?
    public var resolveMediaURL: ((String) async -> URL?)?

    public init(
        entry: JournalEntry,
        einaiObsidianSync: Bool = false,
        onFavoriteToggle: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        resolveMediaURL: ((String) async -> URL?)? = nil
    ) {
        self.entry = entry
        self.einaiObsidianSync = einaiObsidianSync
        self.onFavoriteToggle = onFavoriteToggle
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.resolveMediaURL = resolveMediaURL
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Activity Header (Athlete / Hardware source, Time, Favorite)
            HStack(alignment: .center, spacing: 10) {
                // Device Avatar with live badge
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(R0llingTheme.bgElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.source.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(R0llingTheme.accentPurple)

                    Circle()
                        .fill(R0llingTheme.bevelEmerald)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(R0llingTheme.bgSurface, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(entry.source.displayName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(R0llingTheme.textPrimary)

                        Text("•")
                            .foregroundColor(R0llingTheme.textMuted)

                        Text(entry.formattedTime)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(R0llingTheme.textSecondary)
                    }

                    Text("POV FIRST-PERSON CAPTURE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundColor(R0llingTheme.textMuted)
                }

                Spacer()

                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundColor(R0llingTheme.bevelAmber)
                }
            }

            // 2. Strava Telemetry Metrics Row (Duration, Video, Audio, Size)
            HStack(spacing: 12) {
                if let firstAtt = entry.attachments.first, let dur = firstAtt.durationSeconds {
                    BevelStatPill(
                        icon: "stopwatch.fill",
                        value: String(format: "%.1fs", dur),
                        label: "DURATION",
                        accentColor: R0llingTheme.accentPurple
                    )
                } else {
                    BevelStatPill(
                        icon: "note.text",
                        value: "\(entry.content.count) chars",
                        label: "LENGTH",
                        accentColor: R0llingTheme.bevelCyan
                    )
                }

                BevelStatPill(
                    icon: "video.badge.waveform.fill",
                    value: entry.attachments.first.flatMap { attachment in
                        attachment.width.flatMap { width in attachment.height.map { "\(width)×\($0)" } }
                    } ?? "—",
                    label: "QUALITY",
                    accentColor: R0llingTheme.bevelEmerald
                )

                if let firstAtt = entry.attachments.first {
                    BevelStatPill(
                        icon: "internaldrive.fill",
                        value: firstAtt.byteSize.formattedByteCount(),
                        label: "STORAGE",
                        accentColor: R0llingTheme.textSecondary
                    )
                }
                Spacer()
            }
            .padding(.vertical, 2)

            // 3. Entry Text / Note
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.body)
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineSpacing(3.5)
            }

            // 4. Attachments Previews (Media / Clip Player container)
            if !entry.attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(entry.attachments) { att in
                        MediaPreviewCard(
                            attachment: att,
                            resolveURL: resolveMediaURL.map { resolver in
                                { await resolver(att.relativePath) }
                            }
                        )
                    }
                }
            }

            // 5. Tags Strip
            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags, id: \.self) { tag in
                        TagChip(text: "#\(tag)")
                    }
                }
            }

            // 6. Footer — honest local/Obsidian status (no fake vault sync)
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: einaiObsidianSync ? "checkmark.seal.fill" : "internaldrive.fill")
                        .font(.system(size: 11))
                        .foregroundColor(einaiObsidianSync ? R0llingTheme.bevelEmerald : R0llingTheme.textMuted)
                    Text(einaiObsidianSync ? "Obsidian export OK" : "Τοπικό ημερολόγιο")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(R0llingTheme.textSecondary)
                }

                Spacer()

                Button(action: {
                    R0llingTheme.triggerHapticFeedback()
                    onFavoriteToggle?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(entry.isFavorite ? R0llingTheme.accentPurple : R0llingTheme.textMuted)
                        Text(entry.isFavorite ? "Favorited" : "Kudos")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(entry.isFavorite ? R0llingTheme.accentPurple : R0llingTheme.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .frame(minHeight: 44)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                    .r0llingBevelCapsule()
                }
            }
            .padding(.top, 4)
        }
        .r0llingCard()
        .contextMenu {
            if let onEdit {
                Button("Επεξεργασία…", systemImage: "pencil") {
                    onEdit()
                }
            }
            if let onFavoriteToggle {
                Button(entry.isFavorite ? "Αφαίρεση αγαπημένου" : "Αγαπημένο", systemImage: "heart") {
                    onFavoriteToggle()
                }
            }
            if let onDelete {
                Button("Διαγραφή", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            }
        }
    }
}

/// Compact Athletic Telemetry Pill (Bevel/Strava style)
public struct BevelStatPill: View {
    public let icon: String
    public let value: String
    public let label: String
    public let accentColor: Color

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(R0llingTheme.textMuted)
            }
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(R0llingTheme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .r0llingBevelSurface(cornerRadius: 10)
    }
}

/// Media preview με πραγματικό τοπικό αρχείο όταν υπάρχει URL — αλλιώς honest error/placeholder.
public struct MediaPreviewCard: View {
    public let attachment: MediaAttachment
    public var resolveURL: (() async -> URL?)?

    @State private var photoImage: Image?
    @State private var resolvedURL: URL?
    @State private var loadError: String?
    @State private var isLoading = false
    @State private var isShowingViewer = false

    public init(
        attachment: MediaAttachment,
        resolveURL: (() async -> URL?)? = nil
    ) {
        self.attachment = attachment
        self.resolveURL = resolveURL
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(R0llingTheme.bgElevated)
                .frame(height: 140)
                .overlay(previewOverlay)

            VStack {
                HStack {
                    Spacer()
                    if let dur = attachment.durationSeconds {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                            Text(String(format: "00:%02d", Int(dur)))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(R0llingTheme.accentPurple)
                        .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(10)

            if attachment.mediaType == .video || attachment.mediaType == .clip || attachment.mediaType == .audio {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            if resolvedURL != nil {
                                R0llingTheme.triggerHapticFeedback()
                                isShowingViewer = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.65))
                                    .frame(width: 48, height: 48)
                                Image(systemName: attachment.mediaType == .audio ? "waveform" : "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .offset(x: attachment.mediaType == .audio ? 0 : 2)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(attachment.mediaType == .audio ? "Άνοιγμα αναπαραγωγής ήχου" : "Άνοιγμα αναπαραγωγής βίντεο")
                        Spacer()
                    }
                    Spacer()
                }
            }

            HStack(spacing: 8) {
                Image(systemName: eikonaTypou)
                    .font(.system(size: 12))
                    .foregroundColor(R0llingTheme.bevelCyan)

                Text(attachment.mediaType.folderName.uppercased())
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(R0llingTheme.textPrimary)

                Text("•")
                    .foregroundColor(R0llingTheme.textMuted)

                Text(attachment.byteSize.formattedByteCount())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)

                Spacer()

                Text(katastasiArxeiou)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(loadError == nil ? R0llingTheme.bevelEmerald : R0llingTheme.statusError)
            }
            .padding(10)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.85), Color.black.opacity(0.4), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(height: 140)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(attachment.originalFilename), \(attachment.mediaType.folderName)")
        .accessibilityHint("Άνοιγμα προεπισκόπησης πολυμέσου")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {
            guard resolvedURL != nil else { return }
            R0llingTheme.triggerHapticFeedback()
            isShowingViewer = true
        }
        .onTapGesture {
            if resolvedURL != nil {
                R0llingTheme.triggerHapticFeedback()
                isShowingViewer = true
            }
        }
        .sheet(isPresented: $isShowingViewer) {
            if let resolvedURL {
                MediaViewerSheet(url: resolvedURL, attachment: attachment)
            }
        }
        .task(id: attachment.id) {
            await fortoseMedia()
        }
    }

    @ViewBuilder
    private var previewOverlay: some View {
        if let photoImage {
            photoImage
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if isLoading {
            ProgressView()
        } else if let loadError {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(R0llingTheme.statusError)
                Text(loadError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        } else {
            Image(systemName: eikonaTypou)
                .font(.system(size: 44))
                .foregroundColor(R0llingTheme.textMuted.opacity(0.18))
        }
    }

    private var eikonaTypou: String {
        switch attachment.mediaType {
        case .photo: return "photo.fill"
        case .video, .clip: return "video.fill"
        case .audio: return "waveform"
        }
    }

    private var katastasiArxeiou: String {
        if loadError != nil { return "MISSING" }
        if resolvedURL != nil { return "LOCAL FILE" }
        return "NO RESOLVER"
    }

    private func fortoseMedia() async {
        guard let resolveURL else {
            loadError = nil
            resolvedURL = nil
            photoImage = nil
            return
        }
        isLoading = true
        defer { isLoading = false }

        guard let url = await resolveURL() else {
            loadError = "Αρχείο μη διαθέσιμο"
            resolvedURL = nil
            photoImage = nil
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            loadError = "Λείπει από δίσκο"
            resolvedURL = nil
            photoImage = nil
            return
        }

        resolvedURL = url
        loadError = nil

        guard attachment.mediaType == .photo else { return }

        photoImage = imageThumbnail(from: url, maximumPixelSize: 512)
        if photoImage == nil {
            photoImage = nil
            loadError = "Δεν αποκωδικοποιήθηκε η εικόνα"
        }
    }
}

/// Ένδειξη LIVE ροής κάμερας με Strava Pulse
public struct LiveStreamBadge: View {
    public var isSimulation: Bool = true
    @State private var isPulsing = false

    public init(isSimulation: Bool = true) { self.isSimulation = isSimulation }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(R0llingTheme.accentPurple)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.35 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)

            Text(isSimulation ? "SIMULATION" : "REC LIVE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(R0llingTheme.accentPurple)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(R0llingTheme.accentPurple.opacity(0.15))
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

/// Υπερυψωμένη μπάρα άμεσης αποκοπής σε στυλ Strava Workout / Record Bar
public struct FloatingClipBar: View {
    public let bufferDuration: Double
    public let isStreaming: Bool
    public var isSimulation: Bool = true
    public var onClipTapped: () -> Void

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isStreaming {
                        LiveStreamBadge(isSimulation: isSimulation)
                    }
                    Text(String(format: "BUFFER: %.1fs", bufferDuration))
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(R0llingTheme.textPrimary)
                }
                Text("Pre-roll circular cache ready in RAM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(R0llingTheme.textSecondary)
            }

            Spacer()

            // Large Strava Action Button
            Button(action: {
                R0llingTheme.triggerSuccessHaptic()
                onClipTapped()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "scissors")
                        .font(.system(size: 15, weight: .black))
                    Text("CAPTURE 10s")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(R0llingTheme.primaryButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.32), radius: 4, x: 0, y: 3)
            }
            .disabled(!isStreaming || bufferDuration < 0.5)
        }
        .padding(14)
        .r0llingBevelSurface(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(R0llingTheme.borderFocus, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 16, x: 0, y: 8)
    }
}

/// Tag Chip σε athletic Bevel/Strava style
public struct TagChip: View {
    public let text: String

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(R0llingTheme.accentLavender)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(R0llingTheme.accentPurple.opacity(0.15))
            .clipShape(Capsule())
    }
}

/// Viewfinder HUD Overlay με vector γωνίες και crosshair
public struct ViewfinderHUDOverlay: View {
    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cornerLen: CGFloat = 16

            Path { path in
                // Top-Left corner
                path.move(to: CGPoint(x: 14, y: 14 + cornerLen))
                path.addLine(to: CGPoint(x: 14, y: 14))
                path.addLine(to: CGPoint(x: 14 + cornerLen, y: 14))

                // Top-Right corner
                path.move(to: CGPoint(x: w - 14 - cornerLen, y: 14))
                path.addLine(to: CGPoint(x: w - 14, y: 14))
                path.addLine(to: CGPoint(x: w - 14, y: 14 + cornerLen))

                // Bottom-Left corner
                path.move(to: CGPoint(x: 14, y: h - 14 - cornerLen))
                path.addLine(to: CGPoint(x: 14, y: h - 14))
                path.addLine(to: CGPoint(x: 14 + cornerLen, y: h - 14))

                // Bottom-Right corner
                path.move(to: CGPoint(x: w - 14 - cornerLen, y: h - 14))
                path.addLine(to: CGPoint(x: w - 14, y: h - 14))
                path.addLine(to: CGPoint(x: w - 14, y: h - 14 - cornerLen))

                // Center crosshair
                let cx = w / 2
                let cy = h / 2
                path.move(to: CGPoint(x: cx - 8, y: cy))
                path.addLine(to: CGPoint(x: cx + 8, y: cy))
                path.move(to: CGPoint(x: cx, y: cy - 8))
                path.addLine(to: CGPoint(x: cx, y: cy + 8))
            }
            .stroke(R0llingTheme.accentCyan.opacity(0.65), lineWidth: 1.5)
        }
    }
}

/// Cyberpunk Viewfinder HUD Card για ενεργή ροή κάμερας
public struct LiveViewfinderCard: View {
    public let isStreaming: Bool
    public var isSimulation: Bool = true
    public let bufferDuration: Double
    public var onClipTap: () -> Void

    @State private var scanOffset: CGFloat = -60

    public init(
        isStreaming: Bool,
        isSimulation: Bool = true,
        bufferDuration: Double,
        onClipTap: @escaping () -> Void
    ) {
        self.isStreaming = isStreaming
        self.isSimulation = isSimulation
        self.bufferDuration = bufferDuration
        self.onClipTap = onClipTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LiveStreamBadge(isSimulation: isSimulation)
                Spacer()
                Text(isSimulation ? "SYNTHETIC DATA" : "PREVIEW UNAVAILABLE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(R0llingTheme.textMuted)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: 0x0E0E14))
                    .frame(height: 150)

                ViewfinderHUDOverlay()
                    .frame(height: 150)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, R0llingTheme.accentPurple.opacity(0.4), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 14)
                    .offset(y: scanOffset)

                VStack(spacing: 6) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(R0llingTheme.accentLavender.opacity(0.85))

                    Text(isSimulation ? "SIMULATION — NO CAMERA FEED" : "CAMERA PREVIEW UNAVAILABLE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(R0llingTheme.textPrimary)

                    Text("Κυκλική αποθήκευση: \(String(format: "%.1fs", bufferDuration)) / 10.0s")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(R0llingTheme.accentLavender)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(R0llingTheme.accentPurple.opacity(0.4), lineWidth: 1)
            )
        }
        .r0llingCard()
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                scanOffset = 60
            }
        }
    }
}

/// Πλήρης προβολέας/αναπαραγωγέας πολυμέσων (VideoPlayer, AudioPlayer, Image Viewer)
public struct MediaViewerSheet: View {
    public let url: URL
    public let attachment: MediaAttachment
    @Environment(\.dismiss) private var dismiss

    #if canImport(AVKit)
    @State private var player: AVPlayer?
    @State private var isPlayingAudio: Bool = true
    #endif

    public init(url: URL, attachment: MediaAttachment) {
        self.url = url
        self.attachment = attachment
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                R0llingTheme.bgPrimary.ignoresSafeArea()

                switch attachment.mediaType {
                case .photo:
                    photoView
                case .video, .clip:
                    videoView
                case .audio:
                    audioView
                }
            }
            .navigationTitle(attachment.originalFilename)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Κλείσιμο") {
                        #if canImport(AVKit)
                        player?.pause()
                        #endif
                        dismiss()
                    }
                    .foregroundColor(R0llingTheme.accentLavender)
                }
            }
            .onAppear {
                #if canImport(AVKit)
                if attachment.mediaType == .video || attachment.mediaType == .clip || attachment.mediaType == .audio {
                    player = AVPlayer(url: url)
                    player?.play()
                }
                #endif
            }
            .onDisappear {
                #if canImport(AVKit)
                player?.pause()
                player = nil
                #endif
            }
        }
    }

    private var photoView: some View {
        VStack {
            Spacer()
            if let img = loadCrossPlatformImage() {
                img
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding()
            } else {
                Text("Αδυναμία προβολής εικόνας")
                    .foregroundColor(R0llingTheme.textMuted)
            }
            Spacer()
        }
    }

    private var videoView: some View {
        VStack {
            #if canImport(AVKit)
            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding()
            } else {
                ProgressView()
                    .tint(R0llingTheme.accentLavender)
            }
            #else
            Text("Video playback μη διαθέσιμο σε αυτή την πλατφόρμα")
                .foregroundColor(R0llingTheme.textMuted)
            #endif
        }
    }

    private var audioView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(R0llingTheme.accentPurple)

            Text(attachment.originalFilename)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(R0llingTheme.textPrimary)

            #if canImport(AVKit)
            if let player {
                Button(action: {
                    if isPlayingAudio {
                        player.pause()
                        isPlayingAudio = false
                    } else {
                        player.play()
                        isPlayingAudio = true
                    }
                }) {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(R0llingTheme.accentPurple)
                }
            }
            #endif
        }
        .padding()
    }

    private func loadCrossPlatformImage() -> Image? {
        imageThumbnail(from: url, maximumPixelSize: 2048)
    }
}

