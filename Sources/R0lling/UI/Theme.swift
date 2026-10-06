import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Χρωματικά tokens και στυλ Discord × Twitch
public struct R0llingTheme {
    // Discord Dark Cold Palette (Dark Charcoal & Deep Slate)
    public static let bgPrimary = Color(hex: 0x16161D)
    public static let bgSurface = Color(hex: 0x22232D)
    public static let bgElevated = Color(hex: 0x2C2D39)
    public static let borderSubtle = Color(hex: 0x373948)
    public static let borderFocus = Color(hex: 0x7742DC).opacity(0.6)

    // Typography Colors
    public static let textPrimary = Color(hex: 0xF4F4F8)
    public static let textSecondary = Color(hex: 0xB4B5C5)
    public static let textMuted = Color(hex: 0x787A91)

    // Twitch & Discord Brand Accents (Strictly Cold / Purple / Cyan - Zero Orange / Red in regular states)
    public static let accentPurple = Color(hex: 0x7742DC)
    public static let accentTwitch = Color(hex: 0x9146FF)
    public static let accentLavender = Color(hex: 0xA78BFA)
    public static let accentCyan = Color(hex: 0x00E5FF)
    public static let accentGlow = Color(hex: 0x7742DC).opacity(0.35)

    // Backward compatibility aliases (re-routed to Twitch Purple / Lavender to ensure zero orange)
    public static let stravaOrange = Color(hex: 0x7742DC)
    public static let stravaFlame = Color(hex: 0xA78BFA)
    public static let bevelCyan = Color(hex: 0x00E5FF)
    public static let bevelEmerald = Color(hex: 0x55D6A4)
    public static let bevelAmber = Color(hex: 0xA78BFA)

    // Status Badges
    public static let statusLive = Color(hex: 0x7742DC) // Twitch Active Stream Pulse
    public static let statusSuccess = Color(hex: 0x55D6A4) // Verified Success
    public static let statusWarning = Color(hex: 0xA78BFA) // Attention / Notice (Cold Lavender)
    public static let statusError = Color(hex: 0xFF6B7A) // Strictly for runtime errors

    // Gradients
    public static let primaryButtonGradient = LinearGradient(
        colors: [Color(hex: 0x7742DC), Color(hex: 0x9146FF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    public static let stravaButtonGradient = primaryButtonGradient

    public static let twitchRingGradient = AngularGradient(
        gradient: Gradient(colors: [Color(hex: 0x00E5FF), Color(hex: 0x7742DC), Color(hex: 0xA78BFA), Color(hex: 0x00E5FF)]),
        center: .center
    )
    public static let bevelRingGradient = twitchRingGradient

    public static let heroCardGradient = LinearGradient(
        colors: [Color(hex: 0x22232D), Color(hex: 0x1B1B24)],
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
            .background(R0llingTheme.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

extension View {
    public func r0llingCard() -> some View {
        self.modifier(R0llingCardModifier())
    }
}
