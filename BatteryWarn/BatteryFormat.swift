import Foundation

enum BatteryFormat {
    static func duration(minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60

        if hours == 0 {
            return "\(rest) min"
        } else if rest == 0 {
            return "\(hours) h"
        } else {
            return "\(hours) h \(rest) min"
        }
    }

    static func timeRemaining(minutes: Int?) -> String? {
        guard let minutes = minutes else { return nil }

        return "About \(duration(minutes: minutes)) left"
    }

    /// What the battery is doing right now, in a few words
    static func powerDetail(isPluggedIn: Bool, isCharging: Bool, minutesRemaining: Int?) -> String {
        if isCharging {
            return "Charging"
        } else if isPluggedIn {
            return "Plugged in"
        } else {
            return timeRemaining(minutes: minutesRemaining) ?? "On battery"
        }
    }

    /// One-line summary for the menu bar menu
    static func menuStatus(level: Int, isPluggedIn: Bool, isCharging: Bool, minutesRemaining: Int?) -> String {
        let detail = powerDetail(isPluggedIn: isPluggedIn, isCharging: isCharging, minutesRemaining: minutesRemaining)

        return "Battery \(level)% · \(detail)"
    }
}
