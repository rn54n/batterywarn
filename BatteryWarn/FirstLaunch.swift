import Foundation

/// A menu bar app opens no window when it starts, so the very first start shows Settings
enum FirstLaunch {
    static let defaultsKey = "hasLaunchedBefore"

    /// True exactly once
    static func consume(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: defaultsKey) else { return false }

        defaults.set(true, forKey: defaultsKey)
        return true
    }
}
