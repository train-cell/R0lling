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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDestination: MainDestination = .today
    @State private var isQuickActionsPresented = false
    @State private var pendingTodayQuickAction: TodayQuickAction?
    @AccessibilityFocusState private var quickActionAccessibilityFocus: QuickActionAccessibilityFocus?

    private let primaryDestinations: [MainDestination] = [.today, .journal, .fitness, .wellness]

    public var body: some View {
        ZStack(alignment: .bottom) {
            destinationView
            quickActionsOverlay
        }
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
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isQuickActionsPresented)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: appState.toastMessage)
        .onChange(of: isQuickActionsPresented) { _, isPresented in
            Task { @MainActor in
                await Task.yield()
                quickActionAccessibilityFocus = isPresented ? .action(QuickAction.allCases[0]) : .launcher
            }
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selectedDestination {
        case .today:
            TodayView(
                quickAction: $pendingTodayQuickAction,
                onOpenSettings: { selectedDestination = .settings },
                onOpenHealth: { selectedDestination = .wellness }
            )
        case .journal:
            CalendarView()
        case .fitness:
            FitnessView(onOpenQuickActions: openQuickActions)
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
                if isQuickActionsPresented {
                    closeQuickActions()
                } else {
                    openQuickActions()
                }
            } label: {
                Image(systemName: isQuickActionsPresented ? "xmark" : "plus")
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
            .accessibilityLabel(isQuickActionsPresented ? "Κλείσιμο γρήγορων ενεργειών" : "Περισσότερες λειτουργίες")
            .accessibilityHint(isQuickActionsPresented ? "Κλείνει το μενού ενεργειών." : "Ανοίγει το μενού ενεργειών.")
            .accessibilityAddTraits(isQuickActionsPresented ? .isSelected : [])
            .accessibilityFocused($quickActionAccessibilityFocus, equals: .launcher)
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

    @ViewBuilder
    private var quickActionsOverlay: some View {
        if isQuickActionsPresented {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeQuickActions)
                    .accessibilityLabel("Κλείσιμο γρήγορων ενεργειών")
                    .accessibilityAddTraits(.isButton)
                    .transition(.opacity)

                GeometryReader { geometry in
                    quickActionsPanel
                        .frame(maxWidth: min(520, max(0, geometry.size.width - 24)))
                        .frame(maxHeight: min(520, max(1, geometry.size.height - 16)))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .zIndex(1)
            .transition(.opacity)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func destinationButton(_ destination: MainDestination) -> some View {
        let isSelected = selectedDestination == destination
        return Button {
            selectedDestination = destination
            if isQuickActionsPresented { closeQuickActions() }
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

    private var quickActionsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Γρήγορες ενέργειες")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(R0llingTheme.textPrimary)
                Spacer()
                Button(action: closeQuickActions) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(R0llingTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Κλείσιμο γρήγορων ενεργειών")
                .keyboardShortcut(.cancelAction)
                .accessibilityFocused($quickActionAccessibilityFocus, equals: .close)
            }

            ScrollView {
                LazyVGrid(columns: quickActionGridColumns, spacing: 12) {
                    ForEach(QuickAction.allCases, id: \.self) { action in
                        quickActionButton(action)
                    }
                }
            }
        }
        .padding(20)
        .r0llingBevelSurface(cornerRadius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Γρήγορες ενέργειες")
    }

    private var quickActionGridColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private func quickActionButton(_ action: QuickAction) -> some View {
        Button {
            openQuickAction(action)
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
        .accessibilityFocused($quickActionAccessibilityFocus, equals: .action(action))
    }

    private func closeQuickActions() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isQuickActionsPresented = false
        }
    }

    private func openQuickActions() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isQuickActionsPresented = true
        }
    }

    private func openQuickAction(_ action: QuickAction) {
        closeQuickActions()
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

private enum QuickAction: CaseIterable, Hashable {
    case newNote
    case importFile
    case assistant
    case studio
    case vault
    case settings

    var title: String {
        switch self {
        case .newNote: "Νέα σημείωση"
        case .importFile: "Εισαγωγή αρχείου"
        case .assistant: "Βοηθός"
        case .studio: "Studio"
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
        case .vault: "lock.shield.fill"
        case .settings: "gearshape.fill"
        }
    }
}

private enum QuickActionAccessibilityFocus: Hashable {
    case launcher
    case close
    case action(QuickAction)
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
