import SwiftUI

enum IMDTheme {
    static let names = ["Celestial Glass", "Celestial +", "Celestial Retro", "Liquid Glass", "Xcube 360", "Gamestation"]
    static func palette(named name: String) -> ThemePalette {
        switch name {
        case "Celestial +": .init(background: [.init(red: 0.03, green: 0.01, blue: 0.12), .black], accent: .purple, secondary: .cyan, card: .purple.opacity(0.16), radius: 30)
        case "Celestial Retro": .init(background: [.init(red: 0.08, green: 0.035, blue: 0.01), .black], accent: .orange, secondary: .yellow, card: .orange.opacity(0.14), radius: 10)
        case "Liquid Glass": .init(background: [.init(red: 0.0, green: 0.16, blue: 0.20), .init(red: 0.02, green: 0.03, blue: 0.10)], accent: .mint, secondary: .blue, card: .white.opacity(0.13), radius: 34)
        case "Xcube 360": .init(background: [.init(red: 0.02, green: 0.16, blue: 0.025), .black], accent: .green, secondary: .white, card: .green.opacity(0.13), radius: 8)
        case "Gamestation": .init(background: [.init(red: 0.05, green: 0.06, blue: 0.09), .black], accent: .blue, secondary: .white, card: .blue.opacity(0.13), radius: 4)
        default: .init(background: [.init(red: 0.015, green: 0.035, blue: 0.10), .black], accent: .init(red: 0.12, green: 0.82, blue: 1), secondary: .init(red: 0.48, green: 0.31, blue: 1), card: .white.opacity(0.08), radius: 24)
        }
    }
}

struct ThemePalette {
    let background: [Color]
    let accent: Color
    let secondary: Color
    let card: Color
    let radius: CGFloat
    var gradient: LinearGradient { LinearGradient(colors: background, startPoint: .topLeading, endPoint: .bottomTrailing) }
}

private struct ThemePaletteKey: EnvironmentKey { static let defaultValue = IMDTheme.palette(named: "Celestial Glass") }
extension EnvironmentValues { var imdPalette: ThemePalette { get { self[ThemePaletteKey.self] } set { self[ThemePaletteKey.self] = newValue } } }

struct GlassPanel: ViewModifier {
    @Environment(\.imdPalette) private var palette
    func body(content: Content) -> some View {
        content
            .background(palette.card, in: RoundedRectangle(cornerRadius: palette.radius, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: palette.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: palette.radius).stroke(palette.accent.opacity(0.3), lineWidth: 1))
    }
}

extension View { func glassPanel() -> some View { modifier(GlassPanel()) } }

