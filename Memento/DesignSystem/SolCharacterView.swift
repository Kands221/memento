import SwiftUI
import UIKit
import MementoCore

/// Sol the tortoise, alive: breathing, waving, leaning in, nodding, pondering and napping.
/// Motion is procedural on the paper-cut poses; Reduce Motion (and UI tests) get still poses.
struct SolCharacterView: View {
    let mood: SolMood
    var size: CGFloat
    /// Bump to make Sol nod (e.g. on each streamed chunk or each word typed).
    var nudge: Int = 0
    /// Floating thought dots and z's around the character.
    var showsEffects = true
    /// Tapping makes him duck into his shell and peek back out.
    var reactsToTap = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moodStart = Date()
    @State private var nodStart = Date.distantPast
    @State private var tucked = false

    private var still: Bool { reduceMotion || (LaunchOptions.current.uiTesting && !LaunchOptions.current.demoRecording) }
    private var pose: SolMood { tucked ? .resting : mood }

    var body: some View {
        Group {
            if still {
                figure(at: .now)
            } else {
                TimelineView(.animation) { context in figure(at: context.date) }
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { if reactsToTap { duck() } }
        .onChange(of: mood) { _, _ in moodStart = .now }
        .onChange(of: nudge) { _, _ in nodStart = .now }
        .animation(.spring(response: 0.42, dampingFraction: 0.62), value: pose)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(reactsToTap ? .isButton : [])
    }

    private func figure(at date: Date) -> some View {
        let m = still ? Motion.rest : Motion.at(date.timeIntervalSinceReferenceDate,
                                                 sinceMood: date.timeIntervalSince(moodStart),
                                                 sinceNod: date.timeIntervalSince(nodStart), mood: pose)
        return ZStack {
            SolArt(name: pose.asset, size: size)
                .id(pose)
                .transition(.asymmetric(insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
                                        removal: .opacity))
                .scaleEffect(x: 1 / m.breath, y: m.breath, anchor: .bottom)
                .rotationEffect(.degrees(m.tilt), anchor: .bottom)
                .offset(x: m.sway, y: m.bob)
            if showsEffects && !still {
                effects(at: date.timeIntervalSinceReferenceDate)
            }
        }
    }

    @ViewBuilder
    private func effects(at t: TimeInterval) -> some View {
        switch pose {
        case .thinking:
            // Three small paper dots drifting up and fading, staggered.
            ForEach(0..<3, id: \.self) { i in
                let p = (t / 1.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Circle().fill(Color.mTer.opacity(0.75 * (1 - p)))
                    .frame(width: size * (0.035 + 0.02 * p), height: size * (0.035 + 0.02 * p))
                    .offset(x: size * (0.18 + 0.05 * sin(p * .pi * 2 + Double(i))), y: -size * (0.12 + 0.32 * p))
            }
        case .resting:
            ForEach(0..<3, id: \.self) { i in
                let p = (t / 2.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.serif(size * (0.08 + 0.07 * p), italic: true))
                    .foregroundStyle(Color.mMut.opacity(0.8 * (1 - p)))
                    .offset(x: size * (0.12 + 0.14 * p), y: -size * (0.05 + 0.3 * p))
            }
        default:
            EmptyView()
        }
    }

    private func duck() {
        guard !tucked else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        tucked = true
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            tucked = false
            nodStart = .now
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var accessibilityText: String {
        switch pose {
        case .hello: "Sol the tortoise, waving hello"
        case .listening: "Sol, listening"
        case .thinking: "Sol, thinking"
        case .speaking: "Sol"
        case .reflect: "Sol, reading your reflection"
        case .resting: "Sol, resting in his shell"
        }
    }
}

/// Per-frame transform for Sol's body. Pure, so the motion stays easy to reason about.
private struct Motion {
    var breath: CGFloat = 1   // vertical squash/stretch, anchored at the feet
    var tilt: Double = 0      // degrees, anchored at the feet
    var bob: CGFloat = 0      // points
    var sway: CGFloat = 0     // points

    static let rest = Motion()

    static func at(_ t: TimeInterval, sinceMood: TimeInterval, sinceNod: TimeInterval, mood: SolMood) -> Motion {
        var m = Motion()
        let wave = { (period: Double) in sin(t * 2 * .pi / period) }
        switch mood {
        case .hello:
            m.breath = 1 + 0.012 * wave(3.0)
            // A friendly wave for the first ~2.5 s after he says hello, then settle.
            let decay = max(0, 1 - sinceMood / 2.5)
            m.tilt = 4.5 * sin(sinceMood * 2 * .pi / 0.75) * decay
            m.bob = -2 * abs(sin(sinceMood * 2 * .pi / 1.5)) * decay
        case .listening:
            m.breath = 1 + 0.01 * wave(2.6)
            m.tilt = 3 + 0.8 * wave(2.4)          // leaning in
            m.sway = 1.5
        case .thinking:
            m.breath = 1 + 0.008 * wave(2.2)
            m.bob = -2.2 * CGFloat((wave(1.8) + 1) / 2)
            m.tilt = -1.2 * wave(3.6)
        case .speaking:
            m.breath = 1 + 0.012 * wave(2.8)
        case .reflect:
            m.breath = 1 + 0.01 * wave(3.2)
            m.sway = 1.2 * CGFloat(wave(5))
        case .resting:
            m.breath = 1 + 0.02 * wave(4.2)       // slow, deep sleeping breaths
        }
        // A nod: a quick dip forward that eases out over ~0.6 s.
        if sinceNod < 0.6 {
            let p = sinceNod / 0.6
            m.tilt += 5 * sin(p * .pi) * (1 - p)
            m.bob += CGFloat(1.5 * sin(p * .pi))
        }
        return m
    }
}
