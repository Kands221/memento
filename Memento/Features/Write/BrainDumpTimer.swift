import SwiftUI

/// Three-minute brain-dump timer (prototype L231–237, L881–883).
struct BrainDumpTimer: View {
    static let duration = 180
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var left = Self.duration
    @State private var running = false
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: "%d:%02d", left / 60, left % 60))
                    .font(.mono(34, relativeTo: .largeTitle)).monospacedDigit().tracking(-0.6).foregroundStyle(Color.mInk)
                Spacer()
                Button(buttonTitle, action: toggle)
                    .buttonStyle(PillButtonStyle(fill: .mTerT, foreground: .mTer, border: nil, height: 40, horizontalPadding: 18))
            }
            GeometryReader { geo in
                Capsule().fill(Color.mLine)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.mTer)
                            .frame(width: geo.size.width * CGFloat(Self.duration - left) / CGFloat(Self.duration))
                            .animation(reduceMotion ? nil : .linear(duration: 1), value: left)
                    }
            }
            .frame(height: 4)
            Text(note).font(.ui(14)).foregroundStyle(Color.mMut)
        }
        .onDisappear { ticker?.cancel() }
    }

    private var buttonTitle: String {
        if running { return "Pause" }
        if left == 0 { return "Again" }
        return left < Self.duration ? "Resume" : "Start"
    }

    private var note: String {
        if left == 0 { return "Time’s up. Keep going if you like — nothing stops you." }
        return running ? "Keep moving. Don’t fix anything." : "Three minutes. Write whatever arrives."
    }

    private func toggle() {
        if running {
            running = false
            ticker?.cancel()
            return
        }
        if left <= 0 { left = Self.duration }
        running = true
        ticker = Task {
            while running, left > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                left -= 1
            }
            running = false
        }
    }
}
