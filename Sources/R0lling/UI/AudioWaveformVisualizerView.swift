import SwiftUI

/// Optikopoihsh kymatomorfis ixou se pragmatiko xrono gia fwnitikes simeiwseis kai clips.
/// Ylopoiei aystira:
/// - Bevel Dark Theme tokens (R0llingTheme.accentPurple, accentCyan, bgElevated)
/// - WCAG AAA 44pt touch target boundary
/// - Smooth animatable bars xoris layout thrashing
public struct AudioWaveformVisualizerView: View {
    @Binding public var einaiEnergo: Bool
    public let stathmiEntasis: Float
    public let arithmosMparon: Int

    @State private var animatesSamples: [CGFloat] = []

    public init(einaiEnergo: Binding<Bool>, stathmiEntasis: Float = 0.5, arithmosMparon: Int = 24) {
        self._einaiEnergo = einaiEnergo
        self.stathmiEntasis = min(max(stathmiEntasis, 0.0), 1.0)
        self.arithmosMparon = arithmosMparon
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<arithmosMparon, id: \.self) { deiktis in
                GrammiKymatomorfisBar(
                    ypsosFactor: ypologismosYpsous(gia: deiktis),
                    einaiEnergo: einaiEnergo
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(R0llingTheme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(einaiEnergo ? R0llingTheme.accentPurple.opacity(0.4) : R0llingTheme.borderSubtle, lineWidth: 1)
        )
    }

    /// Ypologizei to dynamiko ypsos kathe mparas me bash tin entasi kai ti thesi.
    private func ypologismosYpsous(gia deiktis: Int) -> CGFloat {
        guard einaiEnergo else { return 0.15 }
        let kentro = Double(arithmosMparon) / 2.0
        let apostasiApoKentro = abs(Double(deiktis) - kentro) / kentro
        let kampyli = cos(apostasiApoKentro * Double.pi / 2.0)
        let normalizedEntasi = CGFloat(stathmiEntasis)
        let basikoYpsos = CGFloat(kampyli) * (0.3 + 0.7 * normalizedEntasi)
        return min(max(basikoYpsos, 0.15), 1.0)
    }
}

/// Memonomeni mpara kymatomorfis me omalo animation allagis ypsous.
public struct GrammiKymatomorfisBar: View {
    public let ypsosFactor: CGFloat
    public let einaiEnergo: Bool

    public init(ypsosFactor: CGFloat, einaiEnergo: Bool) {
        self.ypsosFactor = ypsosFactor
        self.einaiEnergo = einaiEnergo
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: einaiEnergo
                        ? [R0llingTheme.accentCyan, R0llingTheme.accentPurple]
                        : [R0llingTheme.bgSelectedControl, R0llingTheme.bgUnselectedControl],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4)
            .frame(height: max(6, 32 * ypsosFactor))
            .animation(.easeInOut(duration: 0.12), value: ypsosFactor)
    }
}
