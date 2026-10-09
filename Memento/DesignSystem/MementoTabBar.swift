import SwiftUI

/// Five-slot bar from the prototype: four tabs and a centre terracotta "+" that opens the Write sheet.
struct MementoTabBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            tab(.journal, "Journal", "book.closed")
            tab(.discover, "Discover", "circle.circle")
            Button { app.sheet = .write } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color.mOnTer)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.mTer))
                    .shadow(color: Color(red: 120 / 255, green: 60 / 255, blue: 30 / 255).opacity(0.6), radius: 7, y: 6)
            }
            .buttonStyle(.plain)
            .frame(width: 64)
            .padding(.top, -4)
            .accessibilityLabel("Write")
            .accessibilityIdentifier("tab.write")
            tab(.notebooks, "Notebooks", "books.vertical")
            tab(.you, "You", "person")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle().fill(.bar).overlay(Color.mBg.opacity(0.7))
                .overlay(alignment: .top) { Rectangle().fill(Color.mLine).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tab(_ value: AppTab, _ title: String, _ symbol: String) -> some View {
        let on = app.tab == value
        return Button { app.select(value) } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 19, weight: .regular)).frame(height: 22)
                Text(title).font(.ui(10.5, relativeTo: .caption2, weight: .medium))
            }
            .foregroundStyle(on ? Color.mTer : Color.mMut)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(String(describing: value))")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
