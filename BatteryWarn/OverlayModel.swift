import Foundation
import Combine

/// State shared by the overlay windows on all screens
class OverlayModel: ObservableObject {
    @Published var batteryLevel: Int
    @Published var isCritical: Bool
    @Published var minutesRemaining: Int?
    @Published private(set) var escHoldProgress: Double = 0
    @Published private(set) var isHoldingEsc = false

    let threshold: Int
    let allowsDismiss: Bool
    let isTest: Bool
    var onDismiss: (() -> Void)?

    static let escHoldDuration: TimeInterval = 3.0

    init(
        batteryLevel: Int,
        isCritical: Bool,
        minutesRemaining: Int? = nil,
        threshold: Int,
        allowsDismiss: Bool = true,
        isTest: Bool = false
    ) {
        self.batteryLevel = batteryLevel
        self.isCritical = isCritical
        self.minutesRemaining = minutesRemaining
        self.threshold = threshold
        self.allowsDismiss = allowsDismiss
        self.isTest = isTest
    }

    func escPressed() {
        // Dismissing can be turned off in Settings; a preview always closes
        guard allowsDismiss || isTest else { return }

        // For non-critical, instant dismiss
        if !isCritical {
            onDismiss?()
            return
        }

        // For critical, require 3 second hold
        isHoldingEsc = true
        escHoldProgress = 0
    }

    func escReleased() {
        isHoldingEsc = false
        escHoldProgress = 0
    }

    /// Call this on a timer while the overlay is on screen
    func advanceHold(by seconds: TimeInterval) {
        guard isHoldingEsc else { return }

        escHoldProgress = min(1, escHoldProgress + seconds / Self.escHoldDuration)

        if escHoldProgress >= 1 {
            isHoldingEsc = false
            onDismiss?()
        }
    }
}
