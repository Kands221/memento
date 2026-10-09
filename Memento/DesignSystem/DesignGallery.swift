#if DEBUG
import SwiftUI
import MementoCore

/// Visual check of every design-system component (launch with -designGallery).
struct DesignGallery: View {
    @State private var on = true
    @State private var seg = 0

    var body: some View {
        Screen {
            PageTitle("Design system")
            Eyebrow("Chips")
            ForEach(TagKind.allCases, id: \.self) { kind in
                FlowLayout {
                    TagChip(label: kind.singular, kind: kind, status: .suggested)
                    TagChip(label: kind.singular, kind: kind, status: .kept, count: "3")
                    TagChip(label: "Small", kind: kind, status: .kept, size: .small)
                }
            }
            HStack { FilterChip(label: "All", isOn: true) {}; FilterChip(label: "Walking helped") {} }
            SegmentedPill(options: [(0, "Free"), (1, "Brain dump"), (2, "Guided"), (3, "Photo")], selection: $seg)
            Toggle("Suggest tags after saving", isOn: $on).toggleStyle(SageToggleStyle()).font(.ui(17))
            Button("See how it works") {}.buttonStyle(PrimaryButtonStyle())
            Button("Find the details") {}.buttonStyle(OutlineButtonStyle(color: .mTer, height: 50))
            HStack { Button("Write freely") {}.buttonStyle(PillButtonStyle(fill: .mTer, foreground: .mOnTer, border: nil)); Button("Guided") {}.buttonStyle(PillButtonStyle(fill: .clear)) }
            Text("Tonight").font(.serif(24, italic: true))
            Text("A journal that helps you notice.").font(.serif(40, relativeTo: .largeTitle))
            Text("3:00").font(.mono(34))
            ToastView(toast: Toast(text: "Removed “Restless”", undo: {}))
            PaperArt(name: "onb-hero", height: 220)
            HStack { PaperIcon(name: "sol-mark"); PaperIcon(name: "mode-free"); NotebookCover(notebook: .daily).frame(width: 120) }
            AnnotatedPreview()
        }
    }
}

private struct AnnotatedPreview: View {
    var body: some View {
        Text("AnnotatedText arrives in Task 13").font(.ui(13)).foregroundStyle(Color.mMut)
    }
}
#endif
