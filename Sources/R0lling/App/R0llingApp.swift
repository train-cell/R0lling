import SwiftUI

@main
public struct R0llingApp: App {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .task {
                    await appState.loadInitialData()
                }
        }
    }
}

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    public var body: some View {
        ZStack(alignment: .top) {
            TabView {
                TodayView()
                    .tabItem {
                        Label("Σήμερα", systemImage: "sparkles")
                    }

                CalendarView()
                    .tabItem {
                        Label("Ημερολόγιο", systemImage: "calendar")
                    }

                AssistantView()
                    .tabItem {
                        Label("Βοηθός", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Ρυθμίσεις", systemImage: "gearshape.fill")
                    }
            }
            .accentColor(R0llingTheme.accentPurple)
            .onChange(of: scenePhase) { _, newPhase in
                // A07: background / lock / foreground → honest pause/resume policy.
                Task {
                    await appState.handleScenePhaseChange(newPhase)
                }
            }

            // Global Toast Overlay
            if let toast = appState.toastMessage {
                VStack {
                    Text(toast)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(R0llingTheme.bgElevated)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(100)
                .animation(.spring(), value: appState.toastMessage)
            }
        }
    }
}
