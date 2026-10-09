import SwiftUI
import SwiftData
import MementoCore

/// Today, streak, the Tonight prompt, review queue, revisit and recent entries (prototype L175–221).
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var now = Date.now

    var body: some View {
        let labels = DateLabels(now: now)
        let index = TagIndex(entries: entries)
        let pending = JournalInsights.pending(entries)
        Screen {
            VStack(alignment: .leading, spacing: 4) {
                Text(labels.longDay(now).uppercased())
                    .font(.ui(13, relativeTo: .footnote, weight: .semibold)).tracking(0.8).foregroundStyle(Color.mMut)
                PageTitle(labels.greeting())
            }
            .padding(.top, 4)
            streakRow
            tonightCard
            if !pending.isEmpty { pendingRow(pending) }
            if let revisit = JournalInsights.revisit(index) { revisitCard(revisit) }
            if entries.isEmpty {
                emptyState
            } else {
                Eyebrow("Recent").padding(.top, 6)
                ForEach(entries) { EntryCard(entry: $0) }
            }
        }
        .onAppear { now = .now }
    }

    private var streakRow: some View {
        let streak = Streak.compute(entryDates: entries.map(\.createdAt), today: now)
        return Button { app.push(.reminders) } label: {
            ViewThatFits(in: .horizontal) {
                HStack { streakCount(streak); Spacer(minLength: 12); week(streak) }
                VStack(alignment: .leading, spacing: 12) { streakCount(streak); week(streak) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func streakCount(_ streak: StreakInfo) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(streak.count)").font(.serif(34, relativeTo: .largeTitle)).foregroundStyle(Color.mTer)
                .accessibilityIdentifier("journal.streak")
            Text(streak.unit).font(.ui(14)).foregroundStyle(Color.mMut)
        }
    }

    private func week(_ streak: StreakInfo) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(streak.week.enumerated()), id: \.offset) { _, day in
                Text(day.letter)
                    .font(.ui(12, relativeTo: .caption1, weight: .semibold))
                    .foregroundStyle(day.hasEntry ? Color.mOnTer : Color.mMut)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(day.hasEntry ? Color.mTer : .clear))
                    .overlay {
                        if day.hasEntry {
                            Circle().strokeBorder(Color.mTer, lineWidth: 1.5)
                        } else if day.isToday {
                            Circle().strokeBorder(Color.mTer, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                        } else {
                            Circle().strokeBorder(Color.mLine, lineWidth: 1.5)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var tonightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Eyebrow("Tonight")
                Spacer()
                PaperIcon(name: "tonight-ornament", size: 36)
            }
            .padding(.bottom, -14)
            Text("What took up the most room in your head today?")
                .font(.serif(24, relativeTo: .title2, italic: true))
                .foregroundStyle(Color.mInk)
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 8) {
                Button("Write freely") { app.openEditor(.free) }
                    .buttonStyle(PillButtonStyle(fill: .mTer, foreground: .mOnTer, border: nil, horizontalPadding: 15))
                    .accessibilityIdentifier("journal.writeFreely")
                Button("Brain dump · 3 min") { app.openEditor(.dump) }.buttonStyle(PillButtonStyle(fill: .clear, horizontalPadding: 13))
                Button("Guided") { app.openEditor(.guided) }.buttonStyle(PillButtonStyle(fill: .clear, horizontalPadding: 13))
            }
        }
        .paperCard(radius: 24, padding: 20)
    }

    private func pendingRow(_ pending: PendingReview) -> some View {
        Button {
            if let id = pending.firstEntryID { app.openEntry(id) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pending.label).font(.ui(15, weight: .semibold)).foregroundStyle(Color.mInk)
                    Text("Review whenever you like. They aren’t counted until kept.")
                        .font(.ui(13, relativeTo: .footnote)).foregroundStyle(Color.mMut)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.mMut)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .dashedBorder(radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func revisitCard(_ tag: TagSummary) -> some View {
        Button { app.openTag(tag.label) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Revisit", color: .mSage)
                Text("You’ve written about \(Text(tag.label.lowercased()).italic()) in \(tag.count) entries.")
                    .font(.serif(21, relativeTo: .title3))
                    .foregroundStyle(Color.mInk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("See those moments ›").font(.ui(14, weight: .semibold)).foregroundStyle(Color.mSage)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.mSageT))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaperArt(name: "empty-journal", height: 180)
            Text("Your first entry can be one sentence.").font(.serif(22, relativeTo: .title3)).foregroundStyle(Color.mInk)
            Button("Write freely") { app.openEditor(.free) }
                .buttonStyle(PillButtonStyle(fill: .mTer, foreground: .mOnTer, border: nil))
        }
        .padding(.top, 8)
    }
}
