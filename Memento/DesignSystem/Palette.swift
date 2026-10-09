import SwiftUI
import MementoCore

extension Color {
    static let mPage = Color("page"), mBg = Color("bg"), mCard = Color("card"), mSheet = Color("sheet")
    static let mInk = Color("ink"), mMut = Color("mut"), mLine = Color("line")
    static let mTer = Color("ter"), mOnTer = Color("onTer"), mTerT = Color("terT")
    static let mSage = Color("sage"), mSageT = Color("sageT"), mUmb = Color("umb"), mUmbT = Color("umbT")
    static let mSlate = Color("slate"), mSlateT = Color("slateT"), mDanger = Color("danger")

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension TagKind {
    /// Text and dashed-border colour.
    var color: Color {
        switch self {
        case .feeling: .mTer
        case .situation: .mUmb
        case .helped: .mSage
        case .topic: .mSlate
        }
    }

    /// Fill for kept chips and highlighter marks.
    var tint: Color {
        switch self {
        case .feeling: .mTerT
        case .situation: .mUmbT
        case .helped: .mSageT
        case .topic: .mSlateT
        }
    }

    /// Generated emblem asset name.
    var emblem: String { "kind-\(rawValue)" }
}
