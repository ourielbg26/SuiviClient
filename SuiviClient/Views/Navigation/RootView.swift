import SwiftUI

struct RootView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [AppRoute] = []
    @State private var statsPath: [AppRoute] = []

    /// La liste des transactions (ouverte depuis l'Accueil) et le détail de l'encaissé
    /// (depuis les Stats) sont des écrans à part entière : pas de barre d'onglets, ni
    /// sur ce qu'on ouvre depuis eux.
    private var hidesTabBar: Bool {
        homePath.contains(.transactionsList) || !statsPath.isEmpty
    }
    /// Passe à true au bout de quelques secondes : si des données sont déjà en cache sur
    /// le téléphone, on les montre sans attendre la fin de la synchro Drive (qui peut
    /// prendre plus d'une minute) — elle continue en arrière-plan et met l'écran à jour.
    @State private var splashWaitElapsed = false

    private var showsSplash: Bool {
        guard !store.hasFinishedLaunchSync else { return false }
        return store.clients.isEmpty || !splashWaitElapsed
    }

    var body: some View {
        ZStack {
            if showsSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.35), value: showsSplash)
        .task {
            try? await Task.sleep(for: .seconds(3))
            splashWaitElapsed = true
        }
        // Retour dans l'app (après WhatsApp, l'appareil photo…) : on récupère ce que
        // l'autre iPhone a pu enregistrer entre-temps. La synchro du lancement s'en charge
        // déjà au démarrage.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.hasFinishedLaunchSync else { return }
            Task { await store.sync() }
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            Theme.Colors.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home:
                    NavigationStack(path: $homePath) {
                        HomeView(path: $homePath)
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(route, path: $homePath, store: store)
                            }
                    }
                case .stats:
                    NavigationStack(path: $statsPath) {
                        StatsView()
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(route, path: $statsPath, store: store)
                            }
                    }
                case .calendar:
                    NavigationStack {
                        CalendarView()
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                    }
                }
            }

            if !hidesTabBar {
                FloatingTabBar(selected: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: hidesTabBar)
        .environment(\.goHome, GoHomeAction {
            homePath = []
            statsPath = []
            selectedTab = .home
        })
    }
}

/// Écran affiché au lancement, le temps de récupérer les données depuis Google Drive.
private struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Suivi Client")
                    .font(AppFont.display(30, weight: .regular))
                    .tracking(AppTracking.screenTitle * 1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
                ProgressView()
                    .tint(Theme.Colors.primaryButton)
                Text("Chargement des données…")
                    .font(AppFont.montserrat(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
    }
}
