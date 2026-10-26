import Foundation
import SwiftUI
#if canImport(MWDATCore)
import MWDATCore
import OSLog

private enum MetaDATApplicationLifecycle {
    private static let logger = Logger(subsystem: "com.personal.r0lling", category: "MetaDAT")
    private static let appLinkScheme = "com.personal.r0lling"

    // A host `App` may construct `R0llingApp` more than once; a second `Wearables.configure()`
    // only throws `.alreadyConfigured`, so run the SDK setup exactly once per process.
    private static let configuration: Void = {
        do {
            try Wearables.configure()
        } catch {
            // Keep the app usable in its explicitly labeled simulation mode if SDK setup fails.
            MetaDATApplicationLifecycle.logger.error("DAT SDK configuration failed: \(String(describing: error), privacy: .private)")
        }
    }()

    static func configure() {
        _ = configuration
    }

    static func handleURL(_ url: URL) {
        guard url.scheme?.caseInsensitiveCompare(appLinkScheme) == .orderedSame,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true else {
            return
        }

        Task {
            do {
                _ = try await Wearables.shared.handleUrl(url)
            } catch {
                logger.error("DAT callback handling failed: \(String(describing: error), privacy: .private)")
            }
        }
    }
}
#endif

#if !SWIFT_PACKAGE
@main
#endif
public struct R0llingApp: App {
    public init() {
        #if canImport(MWDATCore)
        MetaDATApplicationLifecycle.configure()
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            R0llingRootView()
        }
    }
}

/// Owns `AppState` inside an installed view. The iOS host returns `R0llingApp().body`, so
/// SwiftUI never installs `R0llingApp`'s own properties; a `@StateObject` there would create
/// a new `AppState` on each access and hand the UI and the initial load different instances.
struct R0llingRootView: View {
    @StateObject private var appState = AppState()
    @AppStorage("exeiOkloklirotheiOnboarding") private var exeiOkloklirotheiOnboarding: Bool = false
    @State private var emfanisiOnboarding: Bool = false

    var body: some View {
        MainTabView()
            .environmentObject(appState)
            .preferredColorScheme(.dark)
            .sheet(isPresented: $emfanisiOnboarding) {
                OnboardingWelcomeView(einaiAnoikto: $emfanisiOnboarding)
            }
            .task {
                if !exeiOkloklirotheiOnboarding {
                    emfanisiOnboarding = true
                    exeiOkloklirotheiOnboarding = true
                }
                await appState.loadInitialData()
            }
            #if canImport(MWDATCore)
            .onOpenURL { url in
                MetaDATApplicationLifecycle.handleURL(url)
            }
            #endif
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
            .r0llingBevelCapsule(fillColor: R0llingTheme.bgSurface.opacity(0.82))

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
                    .r0llingBevelSurface(cornerRadius: 29)
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
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(R0llingTheme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background {
                if isSelected {
                    Capsule().fill(Color.white.opacity(0.12))
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
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(R0llingTheme.bgPrimary.opacity(0.88))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(R0llingTheme.borderSubtle.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.26), radius: 10, x: 0, y: 5)
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
                    .r0llingBevelInsetSurface(cornerRadius: 28)
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
