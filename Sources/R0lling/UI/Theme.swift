import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Χρωματικά tokens και στυλ Discord × Twitch
public struct R0llingTheme {
    public static let bgPrimary = Color(hex: 0x16161D)
    public static let bgSurface = Color(hex: 0x22232D)
    public static let bgElevated = Color(hex: 0x2C2D39)
    public static let borderSubtle = Color(hex: 0x373948)

    public static let textPrimary = Color(hex: 0xF4F4F8)
    public static let textSecondary = Color(hex: 0xB4B5C5)
    public static let textMuted = Color(hex: 0x7E8096)

    public static let accentPurple = Color(hex: 0x7742DC)
    public static let accentLavender = Color(hex: 0xA78BFA)
    public static let accentGlow = Color(hex: 0x7742DC).opacity(0.35)

    public static let statusLive = Color(hex: 0xFF4F64)
    public static let statusSuccess = Color(hex: 0x55D6A4)
    public static let statusWarning = Color(hex: 0xFFB347)
    public static let statusError = Color(hex: 0xFF6B7A)

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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(R0llingTheme.borderSubtle, lineWidth: 1)
            )
    }
}

extension View {
    public func r0llingCard() -> some View {
        self.modifier(R0llingCardModifier())
    }
}
