import SwiftUI

struct RootView: View {
    @Environment(ProStore.self) private var pro
    @State private var store = TimerStore()
    @State private var presets = PresetStore()
    @State private var showPaywall = false
    @State private var showCustom = false

    var body: some View {
        VStack(spacing: 0) {
            header
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if store.timers.isEmpty {
                    emptyState
                } else {
                    burnerGrid(now: context.date)
                }
            }
            .frame(maxHeight: .infinity)
            presetBar
        }
        .background(Theme.cream.ignoresSafeArea())
        .tint(Theme.ink)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        #if DEBUG
        // -paywall: 直接弹解锁页，供 ASC 内购审核截图用
        .onAppear { if CommandLine.arguments.contains("-paywall") { showPaywall = true } }
        #endif
        .sheet(isPresented: $showCustom) {
            CustomTimerSheet(canSave: pro.isPro) { emoji, label, seconds, save in
                if save { presets.add(emoji: emoji, label: label, seconds: seconds) }
                start(label: label, emoji: emoji, seconds: seconds)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("SIMMER")
                .font(Theme.font(20, weight: .bold))
                .kerning(4)
            Spacer()
            if !pro.isPro {
                Button("PRO") { showPaywall = true }
                    .font(Theme.font(13, weight: .bold))
                    .foregroundStyle(Theme.flame)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🍳").font(.system(size: 56))
            Text("Nothing on the stove")
                .font(Theme.font(17, weight: .semibold))
            Text("Tap a preset below to start a timer.\nIt lives on your Lock Screen and\nin the Dynamic Island.")
                .font(Theme.font(13))
                .foregroundStyle(Theme.faded)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.ink)
    }

    private func burnerGrid(now: Date) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(store.timers) { timer in
                    BurnerView(timer: timer, now: now)
                        .onTapGesture {
                            if timer.isDone(at: now) {
                                store.dismiss(timer.id)
                            } else {
                                store.togglePause(timer.id)
                            }
                        }
                        .contextMenu {
                            Button("Restart") { store.restart(timer.id) }
                            Button("+1 minute") { store.addMinute(timer.id) }
                            Button("Cancel", role: .destructive) { store.dismiss(timer.id) }
                        }
                }
            }
            .padding(24)
        }
    }

    private var presetBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    showCustom = true
                } label: {
                    Label("Custom", systemImage: "plus")
                        .font(Theme.font(13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().stroke(Theme.ink.opacity(0.3)))
                }
                ForEach(presets.saved) { preset in
                    Button {
                        start(label: preset.label, emoji: preset.emoji, seconds: preset.seconds)
                    } label: {
                        Text("\(preset.emoji) \(preset.label) · \(timerText(preset.seconds))")
                            .font(Theme.font(13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.flame.opacity(0.15)))
                    }
                    .contextMenu {
                        Button("Remove Preset", role: .destructive) { presets.remove(preset.id) }
                    }
                }
                ForEach(Preset.builtins) { preset in
                    Button {
                        start(label: preset.label, emoji: preset.emoji, seconds: preset.seconds)
                    } label: {
                        Text("\(preset.emoji) \(preset.label) · \(timerText(preset.seconds))")
                            .font(Theme.font(13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.ink.opacity(0.06)))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .foregroundStyle(Theme.ink)
    }

    private func start(label: String, emoji: String, seconds: TimeInterval) {
        // Free tier: one timer at a time. Pro unlocks the full stovetop.
        guard pro.isPro || store.timers.isEmpty else {
            showPaywall = true
            return
        }
        store.start(label: label, emoji: emoji, duration: seconds)
    }
}

/// A timer drawn as a stove burner: progress ring, food emoji, countdown.
struct BurnerView: View {
    let timer: KitchenTimer
    let now: Date

    var body: some View {
        let done = timer.isDone(at: now)
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.ink.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: timer.progress(at: now))
                    .stroke(done ? Theme.flame : Theme.ink,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(timer.emoji).font(.system(size: 36))
                    if done {
                        Text("DONE")
                            .font(Theme.font(15, weight: .bold))
                            .foregroundStyle(Theme.flame)
                        Text("OVER +\(timerText(timer.overdue(at: now)))")
                            .font(Theme.font(9, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.faded)
                    } else {
                        Text(timerText(timer.remaining(at: now)))
                            .font(Theme.font(17, weight: .bold).monospacedDigit())
                        if !timer.isRunning {
                            Text("PAUSED")
                                .font(Theme.font(9, weight: .semibold))
                                .foregroundStyle(Theme.faded)
                        }
                    }
                }
            }
            .frame(width: 130, height: 130)
            Text(timer.label.uppercased())
                .font(Theme.font(11, weight: .semibold))
                .kerning(1)
                .foregroundStyle(Theme.faded)
                .lineLimit(1)
        }
        .foregroundStyle(Theme.ink)
        .padding(.vertical, 8)
    }
}

struct CustomTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""
    @State private var emoji = "🍲"
    @State private var saveAsPreset = false
    let canSave: Bool  // Pro: keep this timer in the preset bar
    let onStart: (String, String, TimeInterval, Bool) -> Void

    private let emojis = ["🍲", "🍳", "🥚", "🍝", "🍚", "🥩", "🍞", "🍵", "🧁", "🥦", "🍕", "🦐"]

    var body: some View {
        VStack(spacing: 20) {
            Text("CUSTOM TIMER")
                .font(Theme.font(16, weight: .bold))
                .kerning(3)
                .padding(.top, 24)

            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<181, id: \.self) { Text("\($0) min") }
                }
                .pickerStyle(.wheel)
                Picker("Seconds", selection: $seconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text("\($0) sec") }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 130)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                ForEach(emojis, id: \.self) { candidate in
                    Button {
                        emoji = candidate
                    } label: {
                        Text(candidate)
                            .font(.system(size: 26))
                            .padding(6)
                            .background(
                                Circle().fill(candidate == emoji ? Theme.flame.opacity(0.3) : .clear))
                    }
                }
            }

            TextField("Label (optional)", text: $label)
                .textFieldStyle(.roundedBorder)

            if canSave {
                Toggle(isOn: $saveAsPreset) {
                    Text("SAVE AS PRESET")
                        .font(Theme.font(12, weight: .semibold))
                        .kerning(1)
                }
                .tint(Theme.flame)
            }

            Button {
                let total = TimeInterval(minutes * 60 + seconds)
                guard total > 0 else { return }
                onStart(emoji, label.isEmpty ? "Timer" : label, total, canSave && saveAsPreset)
                dismiss()
            } label: {
                Text("START")
                    .font(Theme.font(15, weight: .bold))
                    .foregroundStyle(Theme.cream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.ink))
            }
            Spacer()
        }
        .padding(24)
        .foregroundStyle(Theme.ink)
        .background(Theme.cream)
        .presentationDetents([.medium, .large])
    }
}
