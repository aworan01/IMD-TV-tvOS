import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var theme = UserDefaults.standard.string(forKey: "theme") ?? "Celestial Glass" {
        didSet { UserDefaults.standard.set(theme, forKey: "theme") }
    }
    @Published var playerMode = UserDefaults.standard.string(forKey: "playerMode") ?? "Automatic" {
        didSet { UserDefaults.standard.set(playerMode, forKey: "playerMode") }
    }
    @Published var showClock = UserDefaults.standard.object(forKey: "showClock") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showClock, forKey: "showClock") }
    }
}

