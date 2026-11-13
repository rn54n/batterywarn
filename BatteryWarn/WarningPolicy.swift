import Foundation

enum WarningLevel: Equatable {
    case none
    case warning
    case critical
}

/// Decides which warning belongs on screen for a given battery state
struct WarningPolicy {
    var threshold: Int
    var criticalThreshold: Int = 5 // At or below this = critical

    // Track dismissed level to re-show at next drop
    private var dismissedAtLevel: Int? = nil

    init(threshold: Int) {
        self.threshold = threshold
    }

    mutating func evaluate(batteryLevel: Int, isPluggedIn: Bool) -> WarningLevel {
        // Reset dismissal when plugged in
        if isPluggedIn {
            dismissedAtLevel = nil
            return .none
        }

        guard batteryLevel <= threshold else { return .none }

        // If dismissed at a level, only show again when battery drops further
        if let dismissed = dismissedAtLevel, batteryLevel >= dismissed {
            return .none
        }

        return batteryLevel <= criticalThreshold ? .critical : .warning
    }

    /// Call this when the user dismisses the overlay
    mutating func dismiss(at batteryLevel: Int) {
        dismissedAtLevel = batteryLevel
    }
}
