import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var title: String { switch self { case .system: return "تلقائي"; case .dark: return "داكن"; case .light: return "فاتح" } }
    var scheme: ColorScheme? { switch self { case .system: return nil; case .dark: return .dark; case .light: return .light } }
}

enum T4Style {
    static let corner: CGFloat = 22
    static let spacing: CGFloat = 16
}
