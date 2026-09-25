import SwiftUI

@main
struct CraftyNativeApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .tint(Color(red: 0.25, green: 0.68, blue: 0.49))
        }
    }
}
