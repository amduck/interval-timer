import SwiftUI
import WatchKit

/// Runs the workout on the watch. Settings come from the iPhone app (cached for offline use).
@MainActor
final class WatchTimerModel: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    enum RunState { case idle, running, paused, done }

    @Published private(set) var settings: Settings
    @Published private(set) var hasSynced: Bool
    @Published private(set) var state: RunState = .idle
    @Published private(set) var phases: [Phase] = []
    @Published private(set) var index = 0
    @Published private(set) var elapsed: TimeInterval = 0

    private var phaseStart = Date()
    private var pausedAt = Date()
    private var lastBeepSecond: Int?
    private var timer: Timer?
    private var session: WKExtendedRuntimeSession?

    override init() {
        var s = Settings()
        var synced = false
        if let data = UserDefaults.standard.data(forKey: Settings.storeKey),
           let saved = try? JSONDecoder().decode(Settings.self, from: data) {
            s = saved
            synced = true
        }
        settings = s.normalised()
        hasSynced = synced
        super.init()
        SyncBridge.shared.onReceive = { [weak self] new in
            MainActor.assumeIsolated { self?.received(new) }
        }
        SyncBridge.shared.activate()
    }

    /// New settings from the phone. Never changes a workout that is already under way.
    private func received(_ new: Settings) {
        let n = new.normalised()
        if let data = try? JSONEncoder().encode(n) {
            UserDefaults.standard.set(data, forKey: Settings.storeKey)
        }
        hasSynced = true
        if state == .idle || state == .done { settings = n; if state == .done { reset() } }
        else { pendingSettings = n }
    }
    private var pendingSettings: Settings?

    // MARK: Derived values

    var isActive: Bool { state == .running || state == .paused }
    private var current: Phase? { isActive && index < phases.count ? phases[index] : nil }

    var planTotalSeconds: Int {
        Int(settings.buildPhases().reduce(0.0) { $0 + $1.duration }.rounded())
    }

    var summary: String {
        settings.custom
            ? "\(settings.rounds) sets · custom"
            : "\(settings.rounds) × \(settings.work)s / \(settings.rest)s"
    }

    var kind: PhaseType? { current?.type }

    var phaseLabel: String {
        switch state {
        case .idle: return "READY"
        case .done: return "DONE"
        default:
            switch current?.type {
            case .prep: return "GET READY"
            case .work: return "WORK"
            case .rest: return "REST"
            case nil:   return "READY"
            }
        }
    }

    var displaySeconds: Int {
        switch state {
        case .idle: return settings.work(at: 0)
        case .done: return 0
        default:
            guard let c = current else { return 0 }
            return Int(ceil(max(0, c.duration - elapsed)))
        }
    }

    var fraction: Double {
        switch state {
        case .idle: return 0
        case .done: return 1
        default:
            guard let c = current, c.duration > 0 else { return 0 }
            return min(1, max(0, elapsed / c.duration))
        }
    }

    var roundText: String {
        switch state {
        case .idle: return "1 / \(settings.rounds)"
        case .done: return "\(settings.rounds) / \(settings.rounds)"
        default:
            guard let c = current else { return "–" }
            return c.round == 0 ? "Get ready" : "Set \(c.round) / \(settings.rounds)"
        }
    }

    // MARK: Controls

    func toggle() { state == .running ? pause() : start() }

    func start() {
        switch state {
        case .running: return
        case .paused:
            phaseStart = phaseStart.addingTimeInterval(Date().timeIntervalSince(pausedAt))
            state = .running
            beginSession()
        case .idle, .done:
            if let p = pendingSettings { settings = p; pendingSettings = nil }
            phases = settings.buildPhases()
            index = 0
            elapsed = 0
            lastBeepSecond = nil
            phaseStart = Date()
            state = .running
            beginSession()
            cue(for: phases[0].type)
        }
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        pausedAt = Date()
        state = .paused
        stopTimer()
        endSession()
    }

    func reset() {
        stopTimer()
        endSession()
        if let p = pendingSettings { settings = p; pendingSettings = nil }
        phases = []
        index = 0
        elapsed = 0
        state = .idle
    }

    func skip(_ direction: Int) {
        guard isActive else { return }
        let ref = state == .paused ? pausedAt : Date()
        var target = index + direction
        if direction < 0 && ref.timeIntervalSince(phaseStart) > 2 { target = index }
        target = max(0, target)
        if target >= phases.count { finish(); return }
        index = target
        phaseStart = ref
        elapsed = 0
        lastBeepSecond = nil
        if state == .running { cue(for: phases[index].type) }
    }

    // MARK: Engine

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func tick() {
        guard state == .running else { return }
        let now = Date()
        let startIndex = index
        while index < phases.count && now.timeIntervalSince(phaseStart) >= phases[index].duration {
            phaseStart = phaseStart.addingTimeInterval(phases[index].duration)
            index += 1
        }
        if index >= phases.count { finish(); return }
        if index != startIndex {
            lastBeepSecond = nil
            cue(for: phases[index].type)
        }
        elapsed = now.timeIntervalSince(phaseStart)

        let remaining = Int(ceil(phases[index].duration - elapsed))
        if (1...3).contains(remaining), remaining != lastBeepSecond, phases[index].duration > 3 {
            lastBeepSecond = remaining
            if settings.haptics { WKInterfaceDevice.current().play(.click) }
        }
    }

    private func finish() {
        stopTimer()
        state = .done
        index = max(0, phases.count - 1)
        elapsed = 0
        if settings.haptics { WKInterfaceDevice.current().play(.success) }
        // Give the success haptic a moment before the background session is released.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.state != .running else { return }
            self.endSession()
        }
    }

    private func cue(for type: PhaseType) {
        guard settings.haptics else { return }
        switch type {
        case .work: WKInterfaceDevice.current().play(.start)
        case .rest: WKInterfaceDevice.current().play(.stop)
        case .prep: WKInterfaceDevice.current().play(.click)
        }
    }

    // MARK: Extended runtime session (keeps the timer and haptics going with the wrist down)

    private func beginSession() {
        if let s = session, s.state == .running || s.state == .scheduled { return }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        session = s
    }

    private func endSession() {
        if let s = session, s.state == .running || s.state == .scheduled { s.invalidate() }
        session = nil
    }

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // 1-hour cap for this session type; warn the wearer with a haptic.
        WKInterfaceDevice.current().play(.notification)
    }

    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                            didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                            error: Error?) {}
}
