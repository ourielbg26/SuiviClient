import SwiftUI

@main
struct SuiviClientApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
