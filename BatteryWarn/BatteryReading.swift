import Foundation
import IOKit.ps

/// One snapshot of the power source, parsed from its IOKit description
struct BatteryReading: Equatable {
    var level: Int
    var isPluggedIn: Bool
    var isCharging: Bool
    var minutesRemaining: Int? // nil while plugged in or while macOS is still estimating

    init?(description: [String: Any]) {
        guard let currentCapacity = description[kIOPSCurrentCapacityKey] as? Int else {
            return nil
        }

        level = currentCapacity
        isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        isCharging = description[kIOPSIsChargingKey] as? Bool ?? false

        // macOS reports -1 until it has an estimate
        if !isPluggedIn, let minutes = description[kIOPSTimeToEmptyKey] as? Int, minutes > 0 {
            minutesRemaining = minutes
        } else {
            minutesRemaining = nil
        }
    }
}
