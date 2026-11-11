import SwiftUI
import UIKit

// MARK: - Model

@MainActor
final class TimerModel: ObservableObject {
    enum RunState { case idle, running, paused, done }

    private static let storeKey = Settings.storeKey

    @Published var settings: Settings {
        didSet {
            normalise()
            save()
        }
    }
    @Published private(set) var state: RunState = .idle {
        didSet { UIApplication.shared.isIdleTimerDisabled = (state == .running) }
    }
    @Published private(set) var phases: [Phase] = []
    @Published private(set) var index = 0
    @Published private(set) var elapsed: TimeInterval = 0     // seconds into the current phase

    private var phaseStart = Date()
    private var pausedAt = Date()
    private var lastBeepSecond: Int?
    private var timer: Timer?
    private let audio = AudioCue()
    private let live = LiveActivityController()
    private let alerts = AlertScheduler()

    init() {
        var s = Settings()
        if let data = UserDefaults.standard.data(forKey: Self.storeKey),
           let saved = try? JSONDecoder().decode(Settings.self, from: data) {
            s = saved
        }
        settings = s
        normalise()   // didSet is not called from init, so clamp and pad explicitly
        SyncBridge.shared.activate()
        SyncBridge.shared.push(settings)
    }

    // MARK: Settings helpers

    /// Keeps every value in range and makes sure there is one SetTimes per round.
    private func normalise() {
        let s = settings.normalised()
        // Only write back if something changed. The assignment re-enters didSet once, finds nothing
        // to change, and stops.
        if s != settings { settings = s }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
        SyncBridge.shared.push(settings)
    }

    func setCustom(_ on: Bool) {
        var s = settings
        // First time on (or nothing customised yet): seed every set from the current Exercise/Rest values.
        if on, let first = s.sets.first, s.sets.allSatisfy({ $0 == first }) {
            let seed = SetTimes(work: s.work, rest: s.rest)
            s.sets = s.sets.map { _ in seed }
        }
        s.custom = on
        settings = s
    }

    func copyFirstSetToAll() {
        var s = settings
        guard let first = s.sets.first else { return }
        s.sets = s.sets.map { _ in first }
        settings = s
    }

    func apply(_ p: Preset) {
        var s = settings
        s.work = p.work; s.rest = p.rest; s.rounds = p.rounds; s.prep = p.prep
        s.custom = false
        settings = s
    }

    private func workOf(_ i: Int) -> Int { settings.work(at: i) }
    private func restOf(_ i: Int) -> Int { settings.rest(at: i) }

    private func buildPhases() -> [Phase] { settings.buildPhases() }

    // MARK: Derived display values

    var isActive: Bool { state == .running || state == .paused }
    var planTotalSeconds: Int {
        let total: Double = buildPhases().reduce(0.0) { $0 + $1.duration }
        return Int(total.rounded())
    }

    private var current: Phase? { isActive && index < phases.count ? phases[index] : nil }

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

    /// Whole seconds shown on the big readout (rounded up, like the web version).
    var displaySeconds: Int {
        switch state {
        case .idle: return workOf(0)
        case .done: return 0
        default:
            guard let c = current else { return 0 }
            return Int(ceil(max(0, c.duration - elapsed)))
        }
    }

    /// 0 at the start of an interval, 1 at the end. Drives the ring.
    var fraction: Double {
        switch state {
        case .idle: return 0
        case .done: return 1
        default:
            guard let c = current, c.duration > 0 else { return 0 }
            return min(1, max(0, elapsed / c.duration))
        }
    }

    var kind: PhaseType? {
        switch state {
        case .idle, .done: return nil
        default: return current?.type
        }
    }

    var subtitle: String {
        switch state {
        case .done: return "Workout complete"
        case .paused: return "Paused"
        case .running: return nextText
        case .idle: return " "
        }
    }

    private var nextText: String {
        guard index + 1 < phases.count else { return "Last interval" }
        let n = phases[index + 1]
        let name = n.type == .work ? "Work" : (n.type == .rest ? "Rest" : "Get ready")
        return "Next: \(name) \(formatTime(Int(n.duration)))"
    }

    // MARK: Lock screen / Dynamic Island

    private func makeLiveState(finished: Bool = false) -> IntervalActivityAttributes.ContentState? {
        if finished {
            let now = Date()
            return IntervalActivityAttributes.ContentState(
                kind: "done", label: "DONE", phaseStart: now, phaseEnd: now.addingTimeInterval(1),
                isPaused: true, pausedSeconds: 0,
                roundText: "\(settings.rounds) / \(settings.rounds)", nextText: "Workout complete")
        }
        guard isActive, index < phases.count else { return nil }
        let c = phases[index]
        let kind: String
        let label: String
        switch c.type {
        case .prep: kind = "prep"; label = "GET READY"
        case .work: kind = "work"; label = "WORK"
        case .rest: kind = "rest"; label = "REST"
        }
        let paused = (state == .paused)
        let heldFor = max(0, c.duration - pausedAt.timeIntervalSince(phaseStart))
        return IntervalActivityAttributes.ContentState(
            kind: kind, label: label,
            phaseStart: phaseStart, phaseEnd: phaseStart.addingTimeInterval(c.duration),
            isPaused: paused, pausedSeconds: Int(ceil(heldFor)),
            roundText: c.round == 0 ? "Get ready" : "Set \(c.round) / \(settings.rounds)",
            nextText: nextText)
    }

    private func pushLive(begin: Bool = false) {
        guard let s = makeLiveState() else { return }
        if begin { live.begin(s) } else { live.update(s) }
    }

    private func scheduleAlerts() {
        guard settings.alerts, state == .running else { return }
        alerts.schedule(phases: phases, from: index, phaseStart: phaseStart, rounds: settings.rounds)
    }

    var roundText: String {
        switch state {
        case .idle: return "1 / \(settings.rounds)"
        case .done: return "\(settings.rounds) / \(settings.rounds)"
        default:
            guard let c = current else { return "–" }
            return c.round == 0 ? "Get ready" : "\(c.round) / \(settings.rounds)"
        }
    }

    var totalRemainingText: String {
        switch state {
        case .idle: return formatTime(planTotalSeconds)
        case .done: return "0:00"
        default:
            guard let c = current else { return "0:00" }
            var rem: Double = max(0, c.duration - elapsed)
            if index + 1 < phases.count {
                for p in phases[(index + 1)...] { rem += p.duration }
            }
            return formatTime(Int(ceil(rem)))
        }
    }

    var startButtonTitle: String {
        switch state {
        case .idle: return "Start"
        case .running: return "Pause"
        case .paused: return "Resume"
        case .done: return "Again"
        }
    }

    // MARK: Controls

    func toggle() {
        state == .running ? pause() : start()
    }

    func start() {
        switch state {
        case .running:
            return
        case .paused:
            phaseStart = phaseStart.addingTimeInterval(Date().timeIntervalSince(pausedAt))
            state = .running
            audio.start()
            pushLive()
            scheduleAlerts()
        case .idle, .done:
            phases = buildPhases()
            index = 0
            elapsed = 0
            lastBeepSecond = nil
            phaseStart = Date()
            state = .running
            audio.start()
            cue(for: phases[0].type)
            pushLive(begin: true)
            if settings.alerts { alerts.requestPermission() }
            scheduleAlerts()
        }
        startTimer()
    }

    func pause() {
        guard state == .running else { return }
        pausedAt = Date()
        state = .paused
        stopTimer()
        audio.stop()
        pushLive()
        alerts.cancelAll()
    }

    func reset() {
        stopTimer()
        audio.stop()
        live.end()
        alerts.cancelAll()
        phases = []
        index = 0
        elapsed = 0
        state = .idle
    }

    func skip(_ direction: Int) {
        guard isActive else { return }
        let ref = state == .paused ? pausedAt : Date()
        var target = index + direction
        if direction < 0 && ref.timeIntervalSince(phaseStart) > 2 { target = index }   // first press restarts this interval
        target = max(0, target)
        if target >= phases.count { finish(); return }
        index = target
        phaseStart = ref
        elapsed = 0
        lastBeepSecond = nil
        if state == .running { cue(for: phases[index].type) }
        pushLive()
        scheduleAlerts()
    }

    // MARK: Engine

    private func startTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { self.tick() }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard state == .running else { return }
        let now = Date()

        // Carry overshoot into following phases so rounds never drift, and so a long
        // suspension (e.g. the app was frozen) lands in the right place.
        let startIndex = index
        while index < phases.count && now.timeIntervalSince(phaseStart) >= phases[index].duration {
            phaseStart = phaseStart.addingTimeInterval(phases[index].duration)
            index += 1
        }
        if index >= phases.count { finish(); return }
        if index != startIndex {
            lastBeepSecond = nil
            cue(for: phases[index].type)
            pushLive()
        }

        elapsed = now.timeIntervalSince(phaseStart)

        let remaining = Int(ceil(phases[index].duration - elapsed))
        if (1...3).contains(remaining), remaining != lastBeepSecond, phases[index].duration > 3 {
            lastBeepSecond = remaining
            if settings.sound { audio.play(.countdown) }
            if settings.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
    }

    private func finish() {
        stopTimer()
        state = .done
        index = max(0, phases.count - 1)
        elapsed = 0
        live.end(final: makeLiveState(finished: true), lingerSeconds: 8)
        alerts.cancelAll()
        if settings.sound { audio.play(.done) }
        if settings.haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        // Let the finish chime play out, then release the audio session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.state != .running else { return }
            self.audio.stop()
        }
    }

    private func cue(for type: PhaseType) {
        if settings.sound {
            switch type {
            case .work: audio.play(.work)
            case .rest: audio.play(.rest)
            case .prep: break
            }
        }
        if settings.haptics {
            UIImpactFeedbackGenerator(style: type == .work ? .heavy : .medium).impactOccurred()
        }
    }
}
