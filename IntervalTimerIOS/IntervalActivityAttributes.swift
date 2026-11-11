import ActivityKit
import Foundation

// This file must be a member of BOTH the app target and the widget extension target.

struct IntervalActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var kind: String          // "prep" | "work" | "rest" | "done"
        var label: String         // "WORK", "REST", ...
        var phaseStart: Date
        var phaseEnd: Date
        var isPaused: Bool
        var pausedSeconds: Int    // shown instead of the live countdown while paused
        var roundText: String     // "3 / 8"
        var nextText: String      // "Next: Rest 0:20"
    }

    var name: String
}

func clockString(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return "\(s / 60):" + (s % 60 < 10 ? "0" : "") + "\(s % 60)"
}
