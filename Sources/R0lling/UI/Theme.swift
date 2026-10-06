import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Χρωματικά tokens και στυλ Strava × Bevel × Discord
public struct R0llingTheme {
    // Athletic Dark Palette (Bevel Charcoal & Midnight Navy)
    public static let bgPrimary = Color(hex: 0x0B0F17)
    public static let bgSurface = Color(hex: 0x141A24)
    public static let bgElevated = Color(hex: 0x1C2433)
    public static let borderSubtle = Color(white: 1.0, opacity: 0.08)
    public static let borderFocus = Color(hex: 0xFC5200).opacity(0.4)

    // Typography Colors
    public static let textPrimary = Color(hex: 0xF8FAFC)
    public static let textSecondary = Color(hex: 0x94A3B8)
    public static let textMuted = Color(hex: 0x64748B)

    // Strava & Bevel Brand Accents
    public static let stravaOrange = Color(hex: 0xFC5200)
    public static let stravaFlame = Color(hex: 0xFF7322)
    public static let bevelCyan = Color(hex: 0x00E5FF)
    public static let bevelEmerald = Color(hex: 0x10B981)
    public static let bevelAmber = Color(hex: 0xF59E0B)

    // Secondary Lavender Accents
    public static let accentPurple = Color(hex: 0x7742DC)
    public static let accentLavender = Color(hex: 0xA78BFA)
    public static let accentGlow = Color(hex: 0xFC5200).opacity(0.35)

    // Status Badges
    public static let statusLive = Color(hex: 0xFC5200) // Strava Active Pulse
    public static let statusSuccess = Color(hex: 0x10B981) // Bevel High Recovery
    public static let statusWarning = Color(hex: 0xF59E0B) // Amber Strain Target
    public static let statusError = Color(hex: 0xEF4444)

    // Gradients
    public static let stravaButtonGradient = LinearGradient(
        colors: [Color(hex: 0xFC5200), Color(hex: 0xFF6519)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let bevelRingGradient = AngularGradient(
        gradient: Gradient(colors: [Color(hex: 0x00E5FF), Color(hex: 0x10B981), Color(hex: 0xFC5200), Color(hex: 0x00E5FF)]),
        center: .center
    )

    public static let heroCardGradient = LinearGradient(
        colors: [Color(hex: 0x172030), Color(hex: 0x111622)],
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
