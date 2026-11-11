# Interval Timer – iPhone app (SwiftUI, iOS 17+)

Native port of `interval-timer.html`: exercise / rest / rounds / get-ready, optional per-set
exercise and rest times, presets, ring countdown, beeps, haptics, screen kept awake, beeps that
keep working with the screen locked, a lock-screen / Dynamic Island countdown (Live Activity),
and silent backup alerts that tap your Apple Watch.

## Files

**App target (`IntervalTimer`)**
- `IntervalTimerApp.swift` – entry point
- `ContentView.swift` – all the UI
- `TimerModel.swift` – settings, phase sequencing, timing engine
- `AudioCue.swift` – generated beeps + background-audio keep-alive
- `AlertScheduler.swift` – silent backup notifications at each interval change
- `LiveActivityController.swift` – starts/updates/ends the Live Activity
- `IntervalActivityAttributes.swift` – **shared: add to BOTH targets**

**Widget extension target (`IntervalWidget`)** – in the `Widget/` folder
- `IntervalWidgetBundle.swift`
- `IntervalLiveActivity.swift`
- plus `IntervalActivityAttributes.swift` from above

## Set up in Xcode

### 1. The app
1. **File ▸ New ▸ Project ▸ iOS ▸ App.** Product Name `IntervalTimer`, Interface **SwiftUI**,
   Language **Swift**, Storage **None**, untick Tests. Pick your Team and a bundle ID
   (e.g. `com.amduck.intervaltimer`).
2. Delete the template's `ContentView.swift` and `IntervalTimerApp.swift` (Move to Trash).
   Drag in the seven app-target `.swift` files listed above (tick **Copy items if needed**,
   target `IntervalTimer`).
3. Target ▸ **General** ▸ Minimum Deployments **iOS 17.0**.
4. **Signing & Capabilities ▸ + Capability ▸ Background Modes** ▸ tick
   **Audio, AirPlay, and Picture in Picture**. *Without this the beeps stop when the screen locks.*
5. Target ▸ **Info** tab ▸ add a row **Supports Live Activities** (`NSSupportsLiveActivities`) = **YES**.

### 2. The Live Activity widget
1. **File ▸ New ▸ Target ▸ Widget Extension.** Name `IntervalWidget`. **Tick "Include Live Activity"**,
   untick "Include Configuration App Intent" and "Include Control". Finish, and **Activate** the scheme if asked.
2. Xcode generates a few template files in the `IntervalWidget` folder. **Delete all of them** (Move to Trash).
3. Drag in `Widget/IntervalWidgetBundle.swift` and `Widget/IntervalLiveActivity.swift`, with target
   membership **IntervalWidget** only.
4. Select `IntervalActivityAttributes.swift` ▸ File inspector (right panel) ▸ **Target Membership** ▸
   tick **both** `IntervalTimer` and `IntervalWidget`.
5. Set the widget target's Minimum Deployment to iOS 17.0 as well.

### 3. Run
Plug in your iPhone (Developer Mode on), choose the **IntervalTimer** scheme and your phone, press **Run**.
Allow notifications when prompted on the first workout.

## If the build complains
- *"Main actor-isolated … cannot satisfy nonisolated requirement"* (Xcode 26 defaults): in Build Settings
  for each target set **Default Actor Isolation** to **nonisolated**, or just paste me the errors.

## How it behaves
- While a workout runs the app holds an active audio session (mixes with music/podcasts) and a silent
  loop, which is what lets iOS keep the timer alive when the screen locks. Pause/finish releases it.
- The Live Activity countdown is drawn by the system, so it ticks smoothly without the app updating
  every second. It shows the phase, set number and what's next, and freezes while paused.
- Lock-screen alerts are silent banners scheduled for every interval change (toggle in settings).
  They light the lock screen and mirror to an Apple Watch as a haptic tap. They are hidden while the app
  is open, and the app's own beeps carry the sound.
- Haptics inside the app only fire while the screen is on – iOS doesn't allow them in the background.
