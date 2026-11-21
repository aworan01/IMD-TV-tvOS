import SwiftUI

enum IMDTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.015, green: 0.035, blue: 0.10), .black],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cyan = Color(red: 0.12, green: 0.82, blue: 1)
    static let violet = Color(red: 0.48, green: 0.31, blue: 1)
}

struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.13), lineWidth: 1))
    }
}

extension View { func glassPanel() -> some View { modifier(GlassPanel()) } }

