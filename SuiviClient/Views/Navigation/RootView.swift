import SwiftUI

struct RootView: View {
    @Environment(DataStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [AppRoute] = []
    @State private var contactsPath: [AppRoute] = []
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
                    NavigationStack {
                        StatsView()
                    }
                case .contacts:
                    NavigationStack(path: $contactsPath) {
                        ContactsView(path: $contactsPath)
                            .navigationDestination(for: AppRoute.self) { route in
                                routeDestination(route, path: $contactsPath, store: store)
                            }
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                    }
                }
            }

            FloatingTabBar(selected: $selectedTab)
        }
    }
}

/// Écran affiché au lancement, le temps de récupérer les données depuis Google Drive.
private struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("Suivi Client")
                    .font(AppFont.playfair(34))
                    .tracking(AppTracking.screenTitle)
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
