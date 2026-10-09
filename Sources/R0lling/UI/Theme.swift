import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Bevel-inspired dark wellness palette for R0lling surfaces and telemetry.
public struct R0llingTheme {
    // Charcoal canvas, soft slate cards, and quiet outlines.
    public static let bgPrimary = Color(hex: 0x17181C)
    public static let bgSurface = Color(hex: 0x2A2B32)
    public static let bgElevated = Color(hex: 0x343640)
    public static let borderSubtle = Color(hex: 0x41434D)
    public static let borderFocus = Color(hex: 0x8B89F5).opacity(0.7)

    // Typography Colors
    public static let textPrimary = Color(hex: 0xF5F5F7)
    public static let textSecondary = Color(hex: 0xB9BAC4)
    public static let textMuted = Color(hex: 0xA6A8B7)

    // Indigo/periwinkle identity with Bevel-style metric colors.
    public static let accentPurple = Color(hex: 0x7068E8)
    public static let accentTwitch = Color(hex: 0x8178EE)
    public static let accentLavender = Color(hex: 0xA3A0F5)
    public static let accentCyan = Color(hex: 0x79AFFF)
    public static let accentLime = Color(hex: 0xB8E34A)
    public static let accentAmber = Color(hex: 0xF3BD55)
    public static let accentGlow = Color(hex: 0x8B89F5).opacity(0.2)

    // Compatibility aliases used by older feature surfaces.
    public static let stravaOrange = Color(hex: 0xF08B68)
    public static let stravaFlame = Color(hex: 0xF28B82)
    public static let bevelCyan = Color(hex: 0x78B9E8)
    public static let bevelEmerald = Color(hex: 0x62C99A)
    public static let bevelAmber = accentAmber

    // Status Badges
    public static let statusLive = Color(hex: 0x79AFFF)
    public static let statusSuccess = Color(hex: 0x62C99A)
    public static let statusWarning = Color(hex: 0xF3BD55)
    public static let statusError = Color(hex: 0xF17B82)

    // Gradients
    public static let primaryButtonGradient = LinearGradient(
        colors: [Color(hex: 0x625FE0), Color(hex: 0x8B89F5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let stravaButtonGradient = primaryButtonGradient

    public static let twitchRingGradient = AngularGradient(
        gradient: Gradient(colors: [bevelCyan, accentPurple, bevelEmerald, accentAmber, bevelCyan]),
        center: .center
    )
    public static let bevelRingGradient = twitchRingGradient

    public static let heroCardGradient = LinearGradient(
        colors: [Color(hex: 0x32343D), Color(hex: 0x25262D)],
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

    public init(cornerRadius: CGFloat = 20) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(R0llingTheme.heroCardGradient))
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.075),
                            R0llingTheme.borderSubtle.opacity(0.62),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
            }
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
            .shadow(color: Color.white.opacity(0.025), radius: 1, x: 0, y: -1)
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
            .background(shape.fill(Color.black.opacity(0.18)))
            .clipShape(shape)
            .overlay {
                shape.stroke(Color.black.opacity(0.34), lineWidth: 1)
            }
            .overlay {
                shape.inset(by: 1).stroke(Color.white.opacity(0.045), lineWidth: 0.75)
            }
    }
}

public struct R0llingBevelCapsuleModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        let shape = Capsule()
        content
            .background(shape.fill(R0llingTheme.heroCardGradient))
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            R0llingTheme.borderSubtle.opacity(0.65),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
            }
            .shadow(color: Color.black.opacity(0.24), radius: 6, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.03), radius: 1, x: 0, y: -1)
    }
}

public struct R0llingFormSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(R0llingTheme.bgPrimary)
            .tint(R0llingTheme.accentCyan)
            .foregroundStyle(R0llingTheme.textPrimary)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(R0llingTheme.heroCardGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.075),
                                        R0llingTheme.borderSubtle.opacity(0.65),
                                        Color.black.opacity(0.22)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    }
                    .padding(.vertical, 3)
            )
            .listRowSeparator(.hidden)
    }
}

extension View {
    public func r0llingCard() -> some View {
        self.modifier(R0llingCardModifier())
    }

    public func r0llingBevelSurface(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(R0llingBevelSurfaceModifier(cornerRadius: cornerRadius))
    }

    public func r0llingBevelInsetSurface(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(R0llingBevelInsetSurfaceModifier(cornerRadius: cornerRadius))
    }

    public func r0llingBevelCapsule() -> some View {
        self.modifier(R0llingBevelCapsuleModifier())
    }

    public func r0llingFormSurface() -> some View {
        self.modifier(R0llingFormSurfaceModifier())
    }
}
