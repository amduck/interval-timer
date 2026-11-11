import SwiftUI

@main
struct IntervalWatchApp: App {
    @StateObject private var model = WatchTimerModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(model)
        }
    }
}
