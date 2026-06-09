import SwiftUI

@main
struct FreeTimeApp: App {
    @StateObject private var store = FreeTimeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(.blue)
        }
    }
}
