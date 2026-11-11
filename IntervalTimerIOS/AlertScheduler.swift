import UserNotifications

/// Backup alerts for when the app can't make noise itself (audio session lost, app suspended).
/// While a workout runs we schedule one silent banner per interval change. On a locked iPhone a
/// banner lights the screen, and it is mirrored to an Apple Watch as a haptic tap. The app's own
/// beeps carry the sound, so these are deliberately silent. They're hidden while the app is open.
@MainActor
final class AlertScheduler: NSObject, UNUserNotificationCenterDelegate {

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Replaces any pending alerts with one per upcoming interval boundary.
    func schedule(phases: [Phase], from index: Int, phaseStart: Date, rounds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var boundary = phaseStart
        var scheduled = 0
        for i in index..<phases.count {
            boundary = boundary.addingTimeInterval(phases[i].duration)
            let wait = boundary.timeIntervalSinceNow
            guard wait > 1 else { continue }
            guard scheduled < 60 else { break }          // iOS keeps at most 64 pending requests

            let content = UNMutableNotificationContent()
            if i + 1 < phases.count {
                let next = phases[i + 1]
                switch next.type {
                case .work:
                    content.title = "Work"
                    content.body = "Set \(next.round) of \(rounds) · \(clock(next.duration))"
                case .rest:
                    content.title = "Rest"
                    content.body = "After set \(next.round) of \(rounds) · \(clock(next.duration))"
                case .prep:
                    content.title = "Get ready"
                    content.body = clock(next.duration)
                }
            } else {
                content.title = "Workout complete"
                content.body = "Nice work."
            }
            content.sound = nil

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
            center.add(UNNotificationRequest(identifier: "interval-\(i)", content: content, trigger: trigger))
            scheduled += 1
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        formatTime(Int(seconds))
    }

    // Don't show banners while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }
}
