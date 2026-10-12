import SwiftUI

@main
struct SuiviClientApp: App {
    @State private var store = DataStore()
    @State private var agenda = AppointmentStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(agenda)
        }
    }
}
