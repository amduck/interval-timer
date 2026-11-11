import ActivityKit
import Foundation

/// Starts, updates and ends the lock-screen / Dynamic Island countdown.
/// The countdown itself is drawn by the system from `phaseStart...phaseEnd`, so it keeps
/// ticking without the app having to push an update every second.
@MainActor
final class LiveActivityController {
    typealias State = IntervalActivityAttributes.ContentState

    private var activity: Activity<IntervalActivityAttributes>?

    init() {
        // Clear anything left over from a previous launch (e.g. the app was force-quit mid-workout).
        Task {
            for stale in Activity<IntervalActivityAttributes>.activities {
                await stale.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    func begin(_ state: State) {
        end()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity<IntervalActivityAttributes>.request(
                attributes: IntervalActivityAttributes(name: "Interval Timer"),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("LiveActivity: could not start – \(error)")
        }
    }

    func update(_ state: State) {
        guard let current = activity else { return }
        Task { await current.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Ends the activity. With a final state it lingers on screen for `lingerSeconds`.
    func end(final state: State? = nil, lingerSeconds: TimeInterval = 0) {
        guard let current = activity else { return }
        activity = nil
        Task {
            if let state, lingerSeconds > 0 {
                await current.end(ActivityContent(state: state, staleDate: nil),
                                  dismissalPolicy: .after(Date().addingTimeInterval(lingerSeconds)))
            } else {
                await current.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
