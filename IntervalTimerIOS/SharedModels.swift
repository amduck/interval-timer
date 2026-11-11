import Foundation

// Shared by the iPhone app and the Apple Watch app.

enum PhaseType { case prep, work, rest }

struct Phase {
    let type: PhaseType
    let duration: TimeInterval   // seconds
    let round: Int               // 0 = get ready, otherwise 1-based set number
}

struct SetTimes: Codable, Equatable {
    var work: Int
    var rest: Int
}

struct Settings: Codable, Equatable {
    var work = 40
    var rest = 20
    var rounds = 8
    var prep = 5
    var sound = true
    var haptics = true
    var alerts = true
    var custom = false
    var sets: [SetTimes] = []

    static let storeKey = "intervalTimer.settings.v1"

    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(hi, max(lo, v)) }

    /// Every value in range, and at least one SetTimes per round.
    func normalised() -> Settings {
        var s = self
        s.work   = Self.clamp(s.work, 1, 3600)
        s.rest   = Self.clamp(s.rest, 0, 3600)
        s.rounds = Self.clamp(s.rounds, 1, 99)
        s.prep   = Self.clamp(s.prep, 0, 600)
        s.sets = s.sets.map { SetTimes(work: Self.clamp($0.work, 1, 3600), rest: Self.clamp($0.rest, 0, 3600)) }
        while s.sets.count < s.rounds {            // extras beyond `rounds` are kept on purpose
            s.sets.append(SetTimes(work: s.work, rest: s.rest))
        }
        return s
    }

    func work(at i: Int) -> Int { custom && i < sets.count ? sets[i].work : work }
    func rest(at i: Int) -> Int { custom && i < sets.count ? sets[i].rest : rest }

    func buildPhases() -> [Phase] {
        var p: [Phase] = []
        if prep > 0 { p.append(Phase(type: .prep, duration: Double(prep), round: 0)) }
        for r in 1...max(1, rounds) {
            p.append(Phase(type: .work, duration: Double(work(at: r - 1)), round: r))
            if r < rounds && rest(at: r - 1) > 0 {
                p.append(Phase(type: .rest, duration: Double(rest(at: r - 1)), round: r))
            }
        }
        return p
    }
}

struct Preset: Identifiable {
    let id = UUID()
    let name: String
    let work: Int, rest: Int, rounds: Int, prep: Int
}

enum Presets {
    static let all: [Preset] = [
        Preset(name: "Tabata 20/10 ×8", work: 20, rest: 10, rounds: 8, prep: 5),
        Preset(name: "30/30 ×10",       work: 30, rest: 30, rounds: 10, prep: 5),
        Preset(name: "40/20 ×8",        work: 40, rest: 20, rounds: 8, prep: 5),
        Preset(name: "45/15 ×6",        work: 45, rest: 15, rounds: 6, prep: 5),
        Preset(name: "60/30 ×5",        work: 60, rest: 30, rounds: 5, prep: 10),
    ]
}

func formatTime(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return "\(s / 60):" + String(format: "%02d", s % 60)
}
