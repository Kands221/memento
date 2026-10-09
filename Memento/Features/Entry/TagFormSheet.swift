import SwiftUI
import MementoCore

struct TagFormSheet: View {
    let entryID: UUID
    let tagID: UUID?
    var body: some View { Text("TagFormSheet").frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.mBg) }
}
