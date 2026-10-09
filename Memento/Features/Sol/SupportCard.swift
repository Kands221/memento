import SwiftUI

/// Static, offline safety net shown instead of a model reply (spec D17).
struct SupportCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message).font(.serif(17, relativeTo: .body)).foregroundStyle(Color.mInk).fixedSize(horizontal: false, vertical: true)
            if Locale.current.region == .unitedStates, let tel = URL(string: "tel:988") {
                Link("Call or text 988", destination: tel)
                    .buttonStyle(InkButtonStyle(height: 44))
            }
            if let url = URL(string: "https://findahelpline.com") {
                Link("Find a helpline near you", destination: url)
                    .font(.ui(15, weight: .semibold)).foregroundStyle(Color.mTer)
            }
            Text("Talking to someone you trust can help too.").font(.ui(13)).foregroundStyle(Color.mMut)
        }
        .paperCard(radius: 18, padding: 16)
        .accessibilityElement(children: .contain)
    }
}
