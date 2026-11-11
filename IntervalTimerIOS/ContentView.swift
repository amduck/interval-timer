import SwiftUI

// MARK: - Theme

enum Theme {
    static let work = Color(red: 0.91, green: 0.27, blue: 0.17)
    static let rest = Color(red: 0.09, green: 0.63, blue: 0.54)
    static let prep = Color(red: 0.85, green: 0.60, blue: 0.08)
    static let done = Color(red: 0.36, green: 0.42, blue: 1.00)
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var model = TimerModel()

    private var accent: Color {
        switch model.state {
        case .idle: return Color(.systemGray)
        case .done: return Theme.done
        default:
            switch model.kind {
            case .work: return Theme.work
            case .rest: return Theme.rest
            case .prep: return Theme.prep
            case nil:   return Color(.systemGray)
            }
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    Text("INTERVAL TIMER")
                        .font(.footnote.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    ring
                    meta
                    controls
                    settingsPanel
                    presets
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 520)
            }
        }
    }

    // MARK: Ring + readout

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(1 - model.fraction))
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: model.fraction)
            VStack(spacing: 2) {
                Text(model.phaseLabel)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(accent)
                Text(formatTime(model.displaySeconds))
                    .font(.system(size: 78, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(model.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(34)
        }
        .frame(maxWidth: 340)
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 12)
    }

    private var meta: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Round")
                Text(model.roundText).fontWeight(.semibold).foregroundStyle(.primary)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("Total remaining")
                Text(model.totalRemainingText).fontWeight(.semibold).foregroundStyle(.primary)
            }
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 10) {
            Button { model.skip(-1) } label: {
                Image(systemName: "backward.end.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!model.isActive)
            .accessibilityLabel("Previous interval")

            Button { model.toggle() } label: {
                Text(model.startButtonTitle)
            }
            .buttonStyle(MainButtonStyle(color: model.state == .idle ? Theme.work : accent))
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            Button { model.skip(1) } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(!model.isActive)
            .accessibilityLabel("Skip interval")

            Button { model.reset() } label: {
                Text("Reset")
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(model.state == .idle)
        }
    }

    // MARK: Settings

    private func setBinding(_ i: Int, _ keyPath: WritableKeyPath<SetTimes, Int>) -> Binding<Int> {
        Binding(
            get: { i < model.settings.sets.count ? model.settings.sets[i][keyPath: keyPath] : 0 },
            set: { newValue in
                guard i < model.settings.sets.count else { return }
                model.settings.sets[i][keyPath: keyPath] = newValue
            }
        )
    }

    private func settingRow<Control: View>(_ title: String, _ subtitle: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            control()
        }
        .padding(.vertical, 10)
    }

    private var settingsPanel: some View {
        let s = model.settings
        return VStack(spacing: 0) {
            if !s.custom {
                settingRow("Exercise", "work period") {
                    TimeStepper(title: "Exercise", value: $model.settings.work, range: 1...3600)
                }
                Divider()
                settingRow("Rest", "between rounds") {
                    TimeStepper(title: "Rest", value: $model.settings.rest, range: 0...3600)
                }
                Divider()
            }
            settingRow("Rounds", "exercise periods") {
                TimeStepper(title: "Rounds", value: $model.settings.rounds, range: 1...99, step: 1, isTime: false)
            }
            Divider()
            settingRow("Get ready", "countdown before start") {
                TimeStepper(title: "Get ready", value: $model.settings.prep, range: 0...600)
            }
            Divider()

            Toggle("Customise each set", isOn: Binding(
                get: { model.settings.custom },
                set: { model.setCustom($0) }
            ))
            .padding(.vertical, 10)

            if s.custom { setList }

            Divider()
            Toggle("Beeps", isOn: $model.settings.sound).padding(.vertical, 10)
            Divider()
            Toggle("Haptics", isOn: $model.settings.haptics).padding(.vertical, 10)
            Divider()
            Toggle(isOn: $model.settings.alerts) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Lock-screen alerts")
                    Text("Silent banner at each change; taps your Apple Watch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
            Divider()
            HStack {
                Text("Total workout").foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(model.planTotalSeconds)).fontWeight(.semibold).monospacedDigit()
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .disabled(model.isActive)
        .opacity(model.isActive ? 0.45 : 1)
    }

    private var setList: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Spacer().frame(width: 46)
                Text("Exercise").frame(maxWidth: .infinity)
                Text("Rest after").frame(maxWidth: .infinity)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(0..<model.settings.rounds, id: \.self) { i in
                let isLast = i == model.settings.rounds - 1
                HStack(spacing: 8) {
                    Text("Set \(i + 1)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)
                    TimeStepper(title: "Set \(i + 1) exercise", value: setBinding(i, \.work), range: 1...3600, compact: true)
                        .frame(maxWidth: .infinity)
                    TimeStepper(title: "Set \(i + 1) rest", value: setBinding(i, \.rest), range: 0...3600, compact: true, disabled: isLast)
                        .frame(maxWidth: .infinity)
                }
            }

            Button("Copy set 1 to all sets") { model.copyFirstSetToAll() }
                .font(.footnote)
                .buttonStyle(.bordered)
                .padding(.top, 6)
        }
        .padding(.bottom, 10)
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Presets.all) { p in
                    Button(p.name) { model.apply(p) }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                }
            }
            .padding(.horizontal, 2)
        }
        .disabled(model.isActive)
        .opacity(model.isActive ? 0.45 : 1)
    }
}

// MARK: - Components

/// − value + control. Tapping the value opens a minutes/seconds wheel for time fields.
struct TimeStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 5
    var isTime: Bool = true
    var compact: Bool = false
    var disabled: Bool = false

    @State private var editing = false

    private func stepped(_ direction: Int) -> Int {
        var v = value + direction * step
        // Snap to the grid so 43 -> 45 (up) or 40 (down), not 48.
        if step > 1 && value % step != 0 {
            v = direction > 0 ? ((value / step) + 1) * step : (value / step) * step
        }
        return min(range.upperBound, max(range.lowerBound, v))
    }

    var body: some View {
        HStack(spacing: compact ? 2 : 6) {
            Button { value = stepped(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(StepButtonStyle(compact: compact))
                .accessibilityLabel("Decrease \(title)")

            Button {
                if isTime { editing = true }
            } label: {
                Text(disabled ? "–" : (isTime ? formatTime(value) : "\(value)"))
                    .font(.system(size: compact ? 16 : 19, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(width: compact ? 50 : 66)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(isTime ? formatTime(value) : "\(value)")")

            Button { value = stepped(1) } label: { Image(systemName: "plus") }
                .buttonStyle(StepButtonStyle(compact: compact))
                .accessibilityLabel("Increase \(title)")
        }
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
        .sheet(isPresented: $editing) {
            TimePickerSheet(title: title, value: value, range: range) { value = $0 }
        }
    }
}

struct TimePickerSheet: View {
    let title: String
    let range: ClosedRange<Int>
    let onDone: (Int) -> Void

    @State private var minutes: Int
    @State private var seconds: Int
    @Environment(\.dismiss) private var dismiss

    init(title: String, value: Int, range: ClosedRange<Int>, onDone: @escaping (Int) -> Void) {
        self.title = title
        self.range = range
        self.onDone = onDone
        _minutes = State(initialValue: value / 60)
        _seconds = State(initialValue: value % 60)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0...60, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Seconds", selection: $seconds) {
                    ForEach(0..<60, id: \.self) { Text("\($0) sec").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let total = minutes * 60 + seconds
                        onDone(min(range.upperBound, max(range.lowerBound, total)))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}

struct StepButtonStyle: ButtonStyle {
    var compact: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 14 : 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: compact ? 30 : 38, height: compact ? 34 : 38)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(minWidth: 48, minHeight: 52)
            .padding(.horizontal, 6)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.4)
    }
}

struct MainButtonStyle: ButtonStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

#Preview {
    ContentView()
}
