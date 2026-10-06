import SwiftUI

/// Bevel-style Concentric 3-Ring Visualization (Buffer, Captures Target, Vault Status)
public struct BevelConcentricRingsView: View {
    public let bufferRatio: Double    // 0.0 ... 1.0 (Ring 1: Outer Cyan)
    public let clipsRatio: Double     // 0.0 ... 1.0 (Ring 2: Middle Orange)
    public let batteryRatio: Double   // 0.0 ... 1.0 (Ring 3: Inner Emerald)

    public init(bufferRatio: Double = 1.0, clipsRatio: Double = 0.6, batteryRatio: Double = 0.85) {
        self.bufferRatio = min(max(bufferRatio, 0.0), 1.0)
        self.clipsRatio = min(max(clipsRatio, 0.0), 1.0)
        self.batteryRatio = min(max(batteryRatio, 0.0), 1.0)
    }

    public var body: some View {
        ZStack {
            // Ring 1: Buffer Health (Outer - Bevel Cyan)
            Circle()
                .stroke(R0llingTheme.bevelCyan.opacity(0.18), lineWidth: 8)
                .frame(width: 96, height: 96)
            Circle()
                .trim(from: 0.0, to: CGFloat(bufferRatio))
                .stroke(
                    AngularGradient(
                        colors: [R0llingTheme.bevelCyan, R0llingTheme.bevelCyan.opacity(0.8)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)

            // Ring 2: Clips Target (Middle - Strava Orange)
            Circle()
                .stroke(R0llingTheme.stravaOrange.opacity(0.18), lineWidth: 8)
                .frame(width: 74, height: 74)
            Circle()
                .trim(from: 0.0, to: CGFloat(clipsRatio))
                .stroke(
                    R0llingTheme.stravaOrange,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 74, height: 74)

            // Ring 3: Hardware Battery / Vault (Inner - Bevel Emerald)
            Circle()
                .stroke(R0llingTheme.bevelEmerald.opacity(0.18), lineWidth: 8)
                .frame(width: 52, height: 52)
            Circle()
                .trim(from: 0.0, to: CGFloat(batteryRatio))
                .stroke(
                    R0llingTheme.bevelEmerald,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 52, height: 52)

            // Central Icon
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(R0llingTheme.stravaOrange)
        }
        .frame(width: 104, height: 104)
    }
}

/// Hero Telemetry Card (Bevel 3-Metrics Summary + Strava Athletic Card)
public struct BevelTelemetryCard: View {
    public let bufferDuration: Double
    public let todayClipsCount: Int
    public let isStreaming: Bool
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
                        .fill(isStreaming ? R0llingTheme.stravaOrange : R0llingTheme.bevelEmerald)
                        .frame(width: 8, height: 8)
                    Text(glassesStatus.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(R0llingTheme.textPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(R0llingTheme.bgElevated)
                .clipShape(Capsule())

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
                    batteryRatio: 0.88
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
                            .fill(R0llingTheme.stravaOrange)
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
                            Text("1080p · 30 FPS · AAC")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(R0llingTheme.textPrimary)
                        }
                    }
                }

                Spacer()
            }

            // Coaching Target Strip (Bevel-style target range)
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(R0llingTheme.stravaOrange)
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
    public var onFavoriteToggle: (() -> Void)?
    public var onDelete: (() -> Void)?

    public init(entry: JournalEntry, onFavoriteToggle: (() -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.onFavoriteToggle = onFavoriteToggle
        self.onDelete = onDelete
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
                        .foregroundColor(R0llingTheme.stravaOrange)

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
                        accentColor: R0llingTheme.stravaOrange
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
                    value: "1080p",
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
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineSpacing(3.5)
            }

            // 4. Attachments Previews (Media / Clip Player container)
            if !entry.attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(entry.attachments) { att in
                        MediaPreviewCard(attachment: att)
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

            // 6. Strava Activity Footer (Kudos / Sync status)
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(R0llingTheme.bevelEmerald)
                    Text("Synced to Obsidian Local Vault")
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
                            .foregroundColor(entry.isFavorite ? R0llingTheme.stravaOrange : R0llingTheme.textMuted)
                        Text(entry.isFavorite ? "Favorited" : "Kudos")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(entry.isFavorite ? R0llingTheme.stravaOrange : R0llingTheme.textMuted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(R0llingTheme.bgElevated)
                    .clipShape(Capsule())
                }
            }
            .padding(.top, 4)
        }
        .r0llingCard()
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
    }
}

/// Strava Athletic Video / Media Preview Card
public struct MediaPreviewCard: View {
    public let attachment: MediaAttachment

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Media Container Box
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(R0llingTheme.bgElevated)
                .frame(height: 140)
                .overlay(
                    // Grid subtle lines simulating video frame
                    Image(systemName: "video.fill")
                        .font(.system(size: 44))
                        .foregroundColor(R0llingTheme.textMuted.opacity(0.18))
                )

            // Top-right Strava Orange Duration Pill
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
                        .background(R0llingTheme.stravaOrange)
                        .clipShape(Capsule())
                        .shadow(color: R0llingTheme.stravaOrange.opacity(0.4), radius: 6, x: 0, y: 2)
                    }
                }
                Spacer()
            }
            .padding(10)

            // Center: Play Button Overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: 48, height: 48)
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 4)
                    Spacer()
                }
                Spacer()
            }

            // Bottom Overlay Strip: File Info & Codec Details
            HStack(spacing: 8) {
                Image(systemName: "film.stack")
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

                Text("H.264 / AAC")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(R0llingTheme.bevelEmerald)
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
    }
}

/// Ένδειξη LIVE ροής κάμερας με Strava Pulse
public struct LiveStreamBadge: View {
    @State private var isPulsing = false

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(R0llingTheme.stravaOrange)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.35 : 1.0)
                .opacity(isPulsing ? 0.6 : 1.0)

            Text("REC LIVE")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundColor(R0llingTheme.stravaOrange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(R0llingTheme.stravaOrange.opacity(0.15))
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
    public var onClipTapped: () -> Void

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isStreaming {
                        LiveStreamBadge()
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
                .background(R0llingTheme.stravaButtonGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: R0llingTheme.stravaOrange.opacity(0.45), radius: 10, x: 0, y: 4)
            }
            .disabled(!isStreaming || bufferDuration < 0.5)
        }
        .padding(14)
        .background(R0llingTheme.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .foregroundColor(R0llingTheme.stravaFlame)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(R0llingTheme.stravaOrange.opacity(0.12))
            .clipShape(Capsule())
    }
}
