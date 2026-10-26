import SwiftUI

/// Katastasi kai Periexomeno tou Vimatos Onboarding.
public struct OnboardingVimaInfo: Identifiable {
    public let id: Int
    public let titlos: String
    public let perigrafi: String
    public let eikonidio: String
    public let xrwmaAccent: Color

    public init(id: Int, titlos: String, perigrafi: String, eikonidio: String, xrwmaAccent: Color) {
        self.id = id
        self.titlos = titlos
        self.perigrafi = perigrafi
        self.eikonidio = eikonidio
        self.xrwmaAccent = xrwmaAccent
    }
}

/// Dedicated First-Launch Onboarding Wizard gia to R0lling.
/// Ylopoiei aystira:
/// - Bevel Dark Design Tokens (R0llingTheme)
/// - WCAG AAA 44pt Touch Targets
/// - Local-First & Zero-Trust Epilogi (Privacy Invariants)
public struct OnboardingWelcomeView: View {
    @Binding public var einaiAnoikto: Bool
    @State private var epilegmenoVima: Int = 0

    private let vimata: [OnboardingVimaInfo] = [
        OnboardingVimaInfo(
            id: 0,
            titlos: "Τοπικό & Προσωπικό Ημερολόγιο",
            perigrafi: "Όλες οι καταχωρήσεις και τα πολυμέσα αποθηκεύονται τοπικά στη συσκευή σας με AES κρυπτογράφηση. Μηδενικό cloud lock-in και πλήρης ιδιωτικότητα.",
            eikonidio: "lock.shield.fill",
            xrwmaAccent: R0llingTheme.accentPurple
        ),
        OnboardingVimaInfo(
            id: 1,
            titlos: "Σύνδεση με Obsidian Vault",
            perigrafi: "Συγχρονίστε αυτόματα τις καθημερινές σας σημειώσεις με το Obsidian vault σας μέσω ασφαλούς sandbox descriptor-relative εξαγωγής.",
            eikonidio: "folder.badge.gearshape",
            xrwmaAccent: R0llingTheme.accentAmber
        ),
        OnboardingVimaInfo(
            id: 2,
            titlos: "Meta Ray-Ban Gen 2 Glasses",
            perigrafi: "Καταγράψτε στιγμές και ηχητικές εντολές απευθείας από τα έξυπνα γυαλιά σας με αυστηρή fail-closed προστασία παρασκηνίου.",
            eikonidio: "eyeglasses",
            xrwmaAccent: R0llingTheme.accentLime
        )
    ]

    public init(einaiAnoikto: Binding<Bool>) {
        self._einaiAnoikto = einaiAnoikto
    }

    public var body: some View {
        ZStack {
            R0llingTheme.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: {
                        einaiAnoikto = false
                    }) {
                        Text("Παράλειψη")
                            .font(.subheadline)
                            .foregroundColor(R0llingTheme.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 8) {
                    Text("R0lling")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(R0llingTheme.textPrimary)

                    Text("Local-First AI Companion & Life Logger")
                        .font(.footnote)
                        .foregroundColor(R0llingTheme.textMuted)
                }

                TabView(selection: $epilegmenoVima) {
                    ForEach(vimata) { vima in
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(vima.xrwmaAccent.opacity(0.15))
                                    .frame(width: 96, height: 96)

                                Image(systemName: vima.eikonidio)
                                    .font(.system(size: 42, weight: .semibold))
                                    .foregroundColor(vima.xrwmaAccent)
                            }
                            .padding(.top, 16)

                            Text(vima.titlos)
                                .font(.title3.bold())
                                .foregroundColor(R0llingTheme.textPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)

                            Text(vima.perigrafi)
                                .font(.body)
                                .foregroundColor(R0llingTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 24)

                            Spacer()
                        }
                        .tag(vima.id)
                    }
                }
                #if canImport(UIKit)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                #endif
                .frame(maxHeight: 340)

                Spacer()

                VStack(spacing: 12) {
                    if epilegmenoVima < vimata.count - 1 {
                        Button(action: {
                            withAnimation {
                                epilegmenoVima += 1
                            }
                        }) {
                            Text("Επόμενο")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(R0llingTheme.primaryButtonGradient)
                                .cornerRadius(12)
                        }
                        .frame(minHeight: 44)
                    } else {
                        Button(action: {
                            einaiAnoikto = false
                        }) {
                            Text("Έναρξη R0lling")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(R0llingTheme.primaryButtonGradient)
                                .cornerRadius(12)
                        }
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}
