import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Bevel-inspired dark wellness palette for R0lling surfaces and telemetry.
public struct R0llingTheme {
    // Bevel references use a charcoal canvas with flat, readable slate surfaces.
    public static let bgPrimary = Color(hex: 0x1F2023)
    public static let bgSurface = Color(hex: 0x2E3037)
    public static let bgElevated = Color(hex: 0x34363D)
    public static let bgInset = Color(hex: 0x25262D)
    public static let bgSelectedControl = Color(hex: 0x6C6E7A)
    public static let bgUnselectedControl = Color(hex: 0x36383F)
    public static let sharePreviewCheckerboardBase = Color(hex: 0x6A6A6A)
    public static let sharePreviewCheckerboardHighlight = Color(hex: 0x717171)
    public static let borderSubtle = Color(hex: 0x464850)
    public static let borderFocus = Color(hex: 0x8B89F5).opacity(0.7)

    // The Bevel sleep-detail screens use a deeper blue surface family.
    public static let sleepCanvas = Color(hex: 0x1A1D2C)
    public static let sleepSurface = Color(hex: 0x232942)
    public static let sleepInset = Color(hex: 0x1A1D2C)
    public static let sleepMetricSurface = Color(hex: 0x1D2331)
    public static let sleepTimeBadgeSurface = Color(hex: 0x343A55)
    public static let sleepBorder = Color(hex: 0x343A55)
    public static let sleepAccent = Color(hex: 0x8796FF)
    public static let sleepVitalTrace = Color(hex: 0xAA84F6)
    public static let sleepAwake = Color(hex: 0xF2AB7E)
    public static let sleepREM = Color(hex: 0xA3B7F9)
    public static let sleepCore = Color(hex: 0x6686F3)
    public static let sleepDeep = Color(hex: 0x5E66C1)
    public static let sleepHeartRate = Color(hex: 0xE76DA1)
    public static let sleepHRV = Color(hex: 0x66A4A5)
    public static let sleepHRVMuted = Color(hex: 0x425C65)
    public static let sleepRespiratory = Color(hex: 0x806FC0)
    public static let sleepRespiratoryMuted = Color(hex: 0x473E6D)
    public static let sleepOxygen = Color(hex: 0x3691B6)
    public static let sleepOxygenMuted = Color(hex: 0x234B69)

    // Fitness calendar fills visually matched to the supplied Bevel activity screen.
    public static let fitnessSingleActivity = Color(hex: 0xAFDC6C)
    public static let fitnessMultipleActivities = Color(hex: 0x4CA8C1)
    public static let fitnessNoActivity = Color(hex: 0x58595F)
    public static let fitnessSelectedDayAccent = Color(hex: 0x699AF8)
    public static let fitnessTrendStart = Color(hex: 0xF3B379)
    public static let fitnessTrendEnd = Color(hex: 0xEE859B)

    public static func fitnessTrendColor(at progress: Double) -> Color {
        let fraction = min(max(progress, 0), 1)
        return Color(
            red: (243.0 + (238.0 - 243.0) * fraction) / 255.0,
            green: (179.0 + (133.0 - 179.0) * fraction) / 255.0,
            blue: (121.0 + (155.0 - 121.0) * fraction) / 255.0
        )
    }

    // Today metric ring accents visually matched to the warm, lime, and periwinkle arcs in IMG_0478.
    public static let todayCognitiveLoadRingStart = Color(hex: 0xF5BF5E)
    public static let todayCognitiveLoadRingEnd = Color(hex: 0xFBE396)
    public static let todayFocusRingStart = Color(hex: 0x91CF38)
    public static let todayFocusRingEnd = Color(hex: 0xEDF267)
    public static let todayReadinessRingStart = Color(hex: 0x6253DE)
    public static let todayReadinessRingEnd = Color(hex: 0xAACBFF)
    public static let healthMonitorGaugeGreen = Color(hex: 0x6DAD83)
    public static let healthMonitorGaugeBlue = Color(hex: 0x699AF8)
    public static let healthMonitorGaugeTrack = Color(hex: 0x292A30)
    public static let healthMonitorTileSurface = Color(hex: 0x33353C)

    // Typography Colors
    public static let textPrimary = Color(hex: 0xF5F5F7)
    public static let textSecondary = Color(hex: 0xA9ABB3)
    public static let textMuted = Color(hex: 0x8A8C96)

    // Indigo/periwinkle identity with Bevel-style metric colors.
    public static let accentPurple = Color(hex: 0x7068E8)
    public static let accentTwitch = Color(hex: 0x8178EE)
    public static let accentLavender = Color(hex: 0xA3A0F5)
    public static let accentCyan = Color(hex: 0x79AFFF)
    public static let accentLime = Color(hex: 0xAFD66C)
    public static let accentAmber = Color(hex: 0xF1BD6E)
    public static let accentGlow = Color(hex: 0x8B89F5).opacity(0.16)

    // Compatibility aliases used by older feature surfaces.
    public static let stravaOrange = Color(hex: 0xF08B68)
    public static let stravaFlame = Color(hex: 0xF28B82)
    public static let bevelCyan = accentCyan
    public static let bevelEmerald = Color(hex: 0x7AC290)
    public static let bevelAmber = accentAmber

    // Status Badges
    public static let statusLive = accentCyan
    public static let statusSuccess = Color(hex: 0x7AC290)
    public static let statusWarning = accentAmber
    public static let statusError = Color(hex: 0xF17B82)

    // Gradients
    public static let primaryButtonGradient = LinearGradient(
        colors: [Color(hex: 0x5E5CC8), Color(hex: 0x7775D9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let stravaButtonGradient = primaryButtonGradient

    public static let twitchRingGradient = AngularGradient(
        gradient: Gradient(colors: [bevelCyan, accentPurple, bevelEmerald, accentAmber, bevelCyan]),
        center: .center
    )
    public static let bevelRingGradient = twitchRingGradient

    public static let heroCardFill = bgSurface
    /// Compatibility token for existing callers; new surfaces use the flat `heroCardFill`.
    public static let heroCardGradient = LinearGradient(
        colors: [bgSurface, bgSurface],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static func triggerHapticFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    public static func triggerSuccessHaptic() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}

public struct R0llingCardModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(14)
            .r0llingBevelSurface(cornerRadius: 20)
    }
}

public struct R0llingBevelSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let fillColor: Color

    public init(cornerRadius: CGFloat = 20, fillColor: Color = R0llingTheme.bgSurface) {
        self.cornerRadius = cornerRadius
        self.fillColor = fillColor
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(fillColor))
            .clipShape(shape)
            .overlay {
                shape.stroke(R0llingTheme.borderSubtle.opacity(0.72), lineWidth: 0.9)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
    }
}

public struct R0llingBevelInsetSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(R0llingTheme.bgInset))
            .clipShape(shape)
            .overlay {
                shape.stroke(R0llingTheme.borderSubtle.opacity(0.42), lineWidth: 0.9)
            }
    }
}

/// Quiet outlined circular control used for contextual toolbar actions.
public struct R0llingToolbarCircleModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        let shape = Circle()
        content
            .background(shape.fill(R0llingTheme.bgInset))
            .clipShape(shape)
            .overlay {
                shape.stroke(R0llingTheme.borderSubtle.opacity(0.8), lineWidth: 0.9)
            }
    }
}

public struct R0llingBevelCapsuleModifier: ViewModifier {
    private let fillColor: Color

    public init(fillColor: Color = R0llingTheme.heroCardFill) {
        self.fillColor = fillColor
    }

    public func body(content: Content) -> some View {
        let shape = Capsule()
        content
            .background(shape.fill(fillColor))
            .clipShape(shape)
            .overlay {
                shape.stroke(R0llingTheme.borderSubtle.opacity(0.74), lineWidth: 0.9)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

public struct R0llingSleepSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 20) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(R0llingTheme.sleepSurface))
            .clipShape(shape)
            .overlay {
                shape.stroke(R0llingTheme.sleepBorder.opacity(0.8), lineWidth: 0.9)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
    }
}

public struct R0llingSleepInsetSurfaceModifier: ViewModifier {
    public let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(R0llingTheme.sleepInset))
            .clipShape(shape)
            .overlay {
                shape.stroke(R0llingTheme.sleepBorder.opacity(0.72), lineWidth: 0.9)
            }
    }
}

public struct R0llingFormSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(R0llingTheme.bgPrimary)
            .tint(R0llingTheme.accentLavender)
            .foregroundStyle(R0llingTheme.textPrimary)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(R0llingTheme.heroCardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(R0llingTheme.borderSubtle.opacity(0.72), lineWidth: 0.9)
                    }
                    .padding(.vertical, 3)
            )
            .listRowSeparator(.hidden)
    }
}

@MainActor
extension View {
    public func r0llingCard() -> some View {
        self.modifier(R0llingCardModifier())
    }

    public func r0llingBevelSurface(
        cornerRadius: CGFloat = 20,
        fillColor: Color = R0llingTheme.bgSurface
    ) -> some View {
        self.modifier(R0llingBevelSurfaceModifier(cornerRadius: cornerRadius, fillColor: fillColor))
    }

    public func r0llingBevelInsetSurface(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(R0llingBevelInsetSurfaceModifier(cornerRadius: cornerRadius))
    }

    public func r0llingToolbarCircle() -> some View {
        self.modifier(R0llingToolbarCircleModifier())
    }

    public func r0llingBevelCapsule(fillColor: Color = R0llingTheme.heroCardFill) -> some View {
        self.modifier(R0llingBevelCapsuleModifier(fillColor: fillColor))
    }

    public func r0llingSleepSurface(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(R0llingSleepSurfaceModifier(cornerRadius: cornerRadius))
    }

    public func r0llingSleepInsetSurface(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(R0llingSleepInsetSurfaceModifier(cornerRadius: cornerRadius))
    }

    public func r0llingFormSurface() -> some View {
        self.modifier(R0llingFormSurfaceModifier())
    }
}
