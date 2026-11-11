import AVFoundation

/// Plays the workout beeps and keeps the app alive with the screen locked.
///
/// While a workout is running we hold an active `.playback` audio session and a looping
/// silent buffer. That is what lets iOS keep the app (and its 0.1 s timer) running in the
/// background, provided the "Audio, AirPlay, and Picture in Picture" background mode is on.
/// `.mixWithOthers` means music or podcasts keep playing underneath the beeps.
@MainActor
final class AudioCue {
    enum Cue { case countdown, work, rest, done }

    private let engine = AVAudioEngine()
    private let beepNode = AVAudioPlayerNode()
    private let keepAliveNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let silence: AVAudioPCMBuffer
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var graphBuilt = false
    private(set) var isRunning = false

    init() {
        let sampleRate = 44_100.0
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        format = fmt

        let silentFrames = AVAudioFrameCount(sampleRate)            // 1 s of silence, looped
        let quiet = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: silentFrames)!
        quiet.frameLength = silentFrames
        if let ch = quiet.floatChannelData?[0] {
            for i in 0..<Int(silentFrames) { ch[i] = 0 }
        }
        silence = quiet

        // (frequency Hz, start s, duration s)
        buffers[.countdown] = makeBuffer([(880, 0, 0.10)])
        buffers[.work]      = makeBuffer([(1046, 0, 0.16), (1318, 0.18, 0.28)])
        buffers[.rest]      = makeBuffer([(660, 0, 0.16), (523, 0.18, 0.28)])
        buffers[.done]      = makeBuffer([(523, 0, 0.22), (659, 0.16, 0.22), (784, 0.32, 0.22), (1046, 0.48, 0.40)])

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, self.isRunning,
                      let raw, AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
                self.restartEngine()
            }
        }
    }

    // MARK: - Lifecycle

    /// Call from a user action (Start / Resume).
    func start() {
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AudioCue: session error \(error)")
        }
        if !graphBuilt {
            engine.attach(beepNode)
            engine.attach(keepAliveNode)
            engine.connect(beepNode, to: engine.mainMixerNode, format: format)
            engine.connect(keepAliveNode, to: engine.mainMixerNode, format: format)
            graphBuilt = true
        }
        isRunning = true
        restartEngine()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        keepAliveNode.stop()
        beepNode.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func restartEngine() {
        do {
            if !engine.isRunning { try engine.start() }
            keepAliveNode.stop()
            keepAliveNode.scheduleBuffer(silence, at: nil, options: .loops, completionHandler: nil)
            keepAliveNode.play()
            if !beepNode.isPlaying { beepNode.play() }
        } catch {
            print("AudioCue: engine error \(error)")
        }
    }

    // MARK: - Playback

    func play(_ cue: Cue) {
        guard isRunning, let buffer = buffers[cue] else { return }
        if !engine.isRunning { restartEngine() }
        beepNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    // MARK: - Tone synthesis

    private func makeBuffer(_ notes: [(freq: Double, start: Double, dur: Double)]) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let total = (notes.map { $0.start + $0.dur }.max() ?? 0.1) + 0.02
        let frames = AVAudioFrameCount(total * rate)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buf.frameLength = frames
        guard let ch = buf.floatChannelData?[0] else { return buf }
        for i in 0..<Int(frames) { ch[i] = 0 }

        for n in notes {
            let first = Int(n.start * rate)
            let count = Int(n.dur * rate)
            for k in 0..<count where first + k < Int(frames) {
                let t = Double(k) / rate
                let attack = min(1.0, t / 0.008)                 // 8 ms fade-in, avoids a click
                let decay = pow(1.0 - Double(k) / Double(count), 2.0)
                ch[first + k] += Float(sin(2.0 * Double.pi * n.freq * t) * attack * decay * 0.55)
            }
        }
        return buf
    }
}
