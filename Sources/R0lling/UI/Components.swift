import SwiftUI

/// Κάρτα μηνύματος/καταχώρισης στο στυλ ροής συζήτησης του Discord
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
        HStack(alignment: .top, spacing: 12) {
            // Εικονίδιο πηγής / Avatar
            ZStack {
                Circle()
                    .fill(R0llingTheme.bgElevated)
                    .frame(width: 36, height: 36)
                Image(systemName: entry.source.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(R0llingTheme.accentLavender)
            }

            VStack(alignment: .leading, spacing: 6) {
                // Header: Ώρα, Πηγή, Favorite
                HStack {
                    Text(entry.source.displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(R0llingTheme.textPrimary)

                    Text(entry.formattedTime)
                        .font(.system(size: 12))
                        .foregroundColor(R0llingTheme.textSecondary)

                    Spacer()

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.yellow)
                    }
                }

                // Κείμενο σημείωσης
                Text(entry.content)
                    .font(.system(size: 15))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .lineSpacing(3)

                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            TagChip(text: "#\(tag)")
                        }
                    }
                    .padding(.top, 2)
                }

                // Attachments previews
                if !entry.attachments.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(entry.attachments) { att in
                            MediaPreviewCard(attachment: att)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .r0llingCard()
    }
}

/// Προεπισκόπηση αρχείου πολυμέσων (φωτογραφία ή Twitch-style clip)
public struct MediaPreviewCard: View {
    public let attachment: MediaAttachment

    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(R0llingTheme.bgElevated)
                    .frame(width: 70, height: 70)

                Image(systemName: iconForType(attachment.mediaType))
                    .font(.system(size: 24))
                    .foregroundColor(R0llingTheme.accentPurple)

                if attachment.mediaType == .clip || attachment.mediaType == .video {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.mediaType.folderName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)

                Text(attachment.byteSize.formattedByteCount())
                    .font(.system(size: 12))
                    .foregroundColor(R0llingTheme.textSecondary)

                if let dur = attachment.durationSeconds {
                    Text(String(format: "Διάρκεια: %.1fs", dur))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(R0llingTheme.accentLavender)
                }
            }

            Spacer()
        }
        .padding(8)
        .background(R0llingTheme.bgElevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func iconForType(_ type: MediaType) -> String {
        switch type {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .clip: return "scissors"
        case .audio: return "waveform"
        }
    }
}

/// Ένδειξη LIVE ροής κάμερας
public struct LiveStreamBadge: View {
    @State private var isPulsing = false

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(R0llingTheme.statusLive)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.3 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)

            Text("LIVE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundColor(R0llingTheme.statusLive)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(R0llingTheme.statusLive.opacity(0.15))
        .clipShape(Capsule())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

/// Υπερυψωμένη μπάρα άμεσης αποκοπής (Floating Clip Bar)
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
                    Text(String(format: "Buffer: %.1fs", bufferDuration))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(R0llingTheme.textPrimary)
                }
                Text("Προηγούμενα δευτερόλεπτα στη μνήμη")
                    .font(.system(size: 11))
                    .foregroundColor(R0llingTheme.textSecondary)
            }

            Spacer()

            Button(action: {
                R0llingTheme.triggerSuccessHaptic()
                onClipTapped()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "scissors")
                        .font(.system(size: 15, weight: .bold))
                    Text("CLIP THIS")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(R0llingTheme.accentPurple)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: R0llingTheme.accentGlow, radius: 8, x: 0, y: 4)
            }
            .disabled(!isStreaming || bufferDuration < 0.5)
        }
        .padding(14)
        .background(R0llingTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

/// Μικρό chip ετικέτας (Tag)
public struct TagChip: View {
    public let text: String

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(R0llingTheme.accentLavender)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(R0llingTheme.accentLavender.opacity(0.12))
            .clipShape(Capsule())
    }
}
