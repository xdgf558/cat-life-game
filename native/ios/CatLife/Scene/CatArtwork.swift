import Foundation
import CatGameCore

enum CatArtwork {
    static func asset(_ baseName: String, appearance: CatAppearance) -> String {
        switch appearance {
        case .orange: return baseName
        case .cow: return baseName.replacingOccurrences(of: "cat-", with: "cat-cow-")
        }
    }
}
