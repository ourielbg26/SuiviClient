import SwiftUI

struct RootView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [AppRoute] = []
    @State private var contactsPath: [AppRoute] = []

    var body: some View {
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
