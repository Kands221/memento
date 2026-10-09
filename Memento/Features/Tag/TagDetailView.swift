import SwiftUI
import SwiftData
import MementoCore

/// Every moment a kept tag appears, across notebooks (prototype L316–346).
struct TagDetailView: View {
    let label: String
    @Environment(AppModel.self) private var app
    @Query(sort: \Entry.createdAt, order: .reverse) private var all: [Entry]

    var body: some View {
        let key = label.lowercased()
        let entries = all.filter { entry in entry.keptTags.contains { $0.label.lowercased() == key } }
        if let summary = TagIndex(entries: all).summary(for: label), !entries.isEmpty {
            content(summary, entries: entries)
        } else {
            Text("No entries have this tag right now.").font(.ui(16)).foregroundStyle(Color.mMut)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.mBg)
        }
    }

    private func content(_ tag: TagSummary, entries: [Entry]) -> some View {
        let labels = DateLabels()
        let dates = entries.map(\.createdAt).sorted()
        let notebooks = Set(entries.map(\.notebookID)).count
        let range = labels.short(dates[0]) + (dates.count > 1 ? " – " + labels.short(dates[dates.count - 1]) : "")
        let cooccurring = coOccurring(in: entries, excluding: tag.key)
        return Screen(spacing: 0, horizontalPadding: 22) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    PaperIcon(name: tag.kind.emblem, size: 28)
                    Eyebrow(tag.kind.plural, color: tag.kind.color)
                }
                Text(tag.label).font(.serif(40, relativeTo: .largeTitle)).tracking(-0.8).foregroundStyle(Color.mInk)
                    .accessibilityIdentifier("tag.title")
                Text("Mentioned in \(entries.count) \(entries.count == 1 ? "entry" : "entries") · \(notebooks) \(notebooks == 1 ? "notebook" : "notebooks") · \(range)")
                    .font(.ui(15)).foregroundStyle(Color.mMut)
            }
            TagTimeline(dates: dates, kind: tag.kind).padding(.top, 22)
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    let mark = entry.keptTags.first { $0.label.lowercased() == tag.key }
                    Button { app.openEntry(entry.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(labels.relativeDay(entry.createdAt))
                                Spacer()
                                Text(entry.notebook.name)
                            }
                            .font(.ui(12.5, relativeTo: .caption1)).foregroundStyle(Color.mMut)
                            if let quote = mark?.quote {
                                AnnotatedText(segments: [TextSegment(text: quote, mark: QuoteMark(id: mark!.id, kind: tag.kind, status: .kept, quote: quote))],
                                              font: .serif(19, relativeTo: .body), lineSpacing: 5)
                            } else {
                                Text(Excerpt.make(entry.text)).font(.serif(19, relativeTo: .body)).foregroundStyle(Color.mInk)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .paperCard(radius: 18, padding: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 22)
            .padding(.horizontal, -6)
            if !cooccurring.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Also kept in these entries").font(.serif(20, relativeTo: .title3)).foregroundStyle(Color.mInk)
                    FlowLayout(spacing: 8) {
                        ForEach(cooccurring, id: \.label) { item in
                            Button { app.openTag(item.label) } label: {
                                TagChip(label: item.label, kind: item.kind, count: "in \(item.count)")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.top, 24)
            }
            Text("This shows what appears together in what you’ve written, not what causes what. Entries without this tag may still be about it.")
                .font(.ui(13)).foregroundStyle(Color.mMut).padding(.top, 18).fixedSize(horizontal: false, vertical: true)
            Button("Summarize these \(entries.count) \(entries.count == 1 ? "entry" : "entries")") {
                app.push(.summary(SummarySeed(ids: entries.map(\.id))))
            }
            .buttonStyle(OutlineButtonStyle())
            .padding(.top, 20)
        }
    }

    private func coOccurring(in entries: [Entry], excluding key: String) -> [(label: String, kind: TagKind, count: Int)] {
        var counts: [(label: String, kind: TagKind, count: Int)] = []
        for entry in entries {
            for tag in entry.keptTags where tag.label.lowercased() != key {
                if let i = counts.firstIndex(where: { $0.label.lowercased() == tag.label.lowercased() }) {
                    counts[i].count += 1
                } else {
                    counts.append((tag.label, tag.kind, 1))
                }
            }
        }
        return Array(counts.enumerated()
            .filter { $0.element.count >= 2 }
            .sorted { $0.element.count != $1.element.count ? $0.element.count > $1.element.count : $0.offset < $1.offset }
            .prefix(5)
            .map(\.element))
    }
}

/// Dots on a month axis, one per entry (prototype TG.marks).
struct TagTimeline: View {
    let dates: [Date]
    let kind: TagKind

    var body: some View {
        let calendar = Calendar.current
        let firstMonth = calendar.dateInterval(of: .month, for: dates.first ?? .now)!.start
        let lastMonth = calendar.dateInterval(of: .month, for: dates.last ?? .now)!.start
        let start = firstMonth == lastMonth ? calendar.date(byAdding: .month, value: -1, to: firstMonth)! : firstMonth
        let end = calendar.date(byAdding: .month, value: 1, to: lastMonth)!
        let months = Array(sequence(first: start) { calendar.date(byAdding: .month, value: 1, to: $0)! }.prefix { $0 < end })
        let span = end.timeIntervalSince(start)
        VStack(spacing: 6) {
            GeometryReader { geo in
                let x = { (date: Date) in geo.size.width * date.timeIntervalSince(start) / span }
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Color.mLine).frame(height: 1).offset(y: 8)
                    ForEach(months.dropFirst(), id: \.self) { month in
                        Rectangle().fill(Color.mLine).frame(width: 1, height: 10).offset(x: x(month), y: 3)
                    }
                    ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                        Circle().fill(kind.color).frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.mBg, lineWidth: 2))
                            .offset(x: x(date) - 6, y: 2)
                    }
                }
            }
            .frame(height: 16)
            HStack(spacing: 0) {
                ForEach(months, id: \.self) { month in
                    Text(DateLabels().month(month)).font(.ui(12, relativeTo: .caption1)).foregroundStyle(Color.mMut)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dates.count) entries between \(DateLabels().short(dates.first ?? .now)) and \(DateLabels().short(dates.last ?? .now))")
    }
}
