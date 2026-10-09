import SwiftUI

#if !SWIFT_PACKAGE
@main
#endif
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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDestination: MainDestination = .today
    @State private var isQuickActionsPresented = false
    @State private var pendingQuickAction: QuickSheetAction?
    @State private var pendingTodayQuickAction: TodayQuickAction?

    private let primaryDestinations: [MainDestination] = [.today, .journal, .fitness, .wellness]

    public var body: some View {
        destinationView
            .safeAreaInset(edge: .bottom, spacing: 0) {
                floatingNavigation
            }
            .background(R0llingTheme.bgPrimary.ignoresSafeArea())
            .onChange(of: scenePhase) { _, newPhase in
                // A07: background / lock / foreground → honest pause/resume policy.
                Task {
                    await appState.handleScenePhaseChange(newPhase)
                }
            }
            .sheet(isPresented: $isQuickActionsPresented, onDismiss: applyPendingQuickAction) {
                quickActionsSheet
                    .presentationDetents(quickActionsSheetDetents)
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(R0llingTheme.bgSurface)
            }
            .overlay(alignment: .top) {
                if let toast = appState.toastMessage {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(R0llingTheme.bgElevated, in: Capsule())
                        .overlay(Capsule().stroke(R0llingTheme.borderSubtle, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appState.toastMessage)
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selectedDestination {
        case .today:
            TodayView(quickAction: $pendingTodayQuickAction)
        case .journal:
            CalendarView()
        case .fitness:
            FitnessView()
        case .wellness:
            BiohackingHubView()
        case .vault:
            StrategicVaultHubView()
        case .studio:
            CreativeStudioHubView()
        case .assistant:
            AssistantView()
        case .settings:
            SettingsView()
        }
    }

    private var floatingNavigation: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(primaryDestinations, id: \.self) { destination in
                    destinationButton(destination)
                }
            }
            .padding(4)
            .background {
                Capsule().fill(
                    LinearGradient(
                        colors: [R0llingTheme.bgElevated.opacity(0.98), R0llingTheme.bgSurface.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                Capsule().stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.09), R0llingTheme.borderSubtle.opacity(0.68), Color.black.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 4)

            Button {
                isQuickActionsPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .frame(width: 58, height: 58)
                    .background {
                        Circle().fill(
                            LinearGradient(
                                colors: [R0llingTheme.bgElevated, R0llingTheme.bgSurface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    .overlay {
                        Circle().stroke(
                            LinearGradient(
                            colors: [Color.white.opacity(0.10), R0llingTheme.borderSubtle.opacity(0.72), Color.black.opacity(0.24)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                    }
                    .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Περισσότερες λειτουργίες")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [R0llingTheme.bgPrimary.opacity(0), R0llingTheme.bgPrimary.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func destinationButton(_ destination: MainDestination) -> some View {
        let isSelected = selectedDestination == destination
        return Button {
            selectedDestination = destination
        } label: {
            VStack(spacing: 4) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(destination.title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(isSelected ? R0llingTheme.textPrimary : R0llingTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if isSelected {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.13), Color.white.opacity(0.055)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var quickActionsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Περισσότερα")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Button("Κλείσιμο", systemImage: "xmark") {
                    isQuickActionsPresented = false
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Κλείσιμο")
            }

            ScrollView {
                LazyVGrid(columns: quickActionGridColumns, spacing: 12) {
                    ForEach(QuickSheetAction.allCases, id: \.self) { action in
                        quickActionButton(action)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .r0llingBevelSurface(cornerRadius: 24)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var quickActionsSheetDetents: Set<PresentationDetent> {
        if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact {
            return [.large]
        }
        if horizontalSizeClass == .compact {
            return [.medium, .large]
        }
        return [.height(350), .large]
    }

    private var quickActionGridColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize
            ? 1
            : (horizontalSizeClass == .compact ? 2 : 3)
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private func quickActionButton(_ action: QuickSheetAction) -> some View {
        Button {
            pendingQuickAction = action
            isQuickActionsPresented = false
        } label: {
            VStack(spacing: 8) {
                Image(systemName: action.symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                    .frame(width: 56, height: 56)
                    .r0llingBevelCapsule()
                Text(action.title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(R0llingTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 104)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }

    private func applyPendingQuickAction() {
        guard let action = pendingQuickAction else { return }
        pendingQuickAction = nil
        switch action {
        case .newNote:
            selectedDestination = .today
            pendingTodayQuickAction = .newNote
        case .importFile:
            selectedDestination = .today
            pendingTodayQuickAction = .importFile
        case .assistant:
            selectedDestination = .assistant
        case .studio:
            selectedDestination = .studio
        case .journal:
            selectedDestination = .journal
        case .vault:
            selectedDestination = .vault
        case .settings:
            selectedDestination = .settings
        }
    }
}

public enum TodayQuickAction: Equatable {
    case newNote
    case importFile
}

private enum QuickSheetAction: CaseIterable, Hashable {
    case newNote
    case importFile
    case assistant
    case studio
    case journal
    case vault
    case settings

    var title: String {
        switch self {
        case .newNote: "Νέα σημείωση"
        case .importFile: "Εισαγωγή αρχείου"
        case .assistant: "Βοηθός"
        case .studio: "Studio"
        case .journal: "Ημερολόγιο"
        case .vault: "Ιδιωτικό vault"
        case .settings: "Ρυθμίσεις"
        }
    }

    var symbol: String {
        switch self {
        case .newNote: "square.and.pencil"
        case .importFile: "folder.badge.plus"
        case .assistant: "sparkles"
        case .studio: "brain.head.profile"
        case .journal: "book.closed.fill"
        case .vault: "lock.shield.fill"
        case .settings: "gearshape.fill"
        }
    }
}

private enum MainDestination: Hashable {
    case today
    case journal
    case fitness
    case wellness
    case vault
    case studio
    case assistant
    case settings

    var title: String {
        switch self {
        case .today: "Σήμερα"
        case .journal: "Ημερολόγιο"
        case .fitness: "Fitness"
        case .wellness: "Υγεία"
        case .vault: "Vault"
        case .studio: "Studio"
        case .assistant: "Βοηθός"
        case .settings: "Ρυθμίσεις"
        }
    }

    var symbol: String {
        switch self {
        case .today: "house.fill"
        case .journal: "book.closed.fill"
        case .fitness: "figure.run"
        case .wellness: "heart.text.square.fill"
        case .vault: "lock.shield.fill"
        case .studio: "brain.head.profile"
        case .assistant: "sparkles"
        case .settings: "gearshape.fill"
        }
    }
}
