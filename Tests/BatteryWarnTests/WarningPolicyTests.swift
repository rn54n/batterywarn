import XCTest
@testable import BatteryWarn

final class WarningPolicyTests: XCTestCase {
    func testNoWarningAboveThreshold() {
        var policy = WarningPolicy(threshold: 10)

        XCTAssertEqual(policy.evaluate(batteryLevel: 11, isPluggedIn: false), .none)
    }

    func testWarningAtThreshold() {
        var policy = WarningPolicy(threshold: 10)

        XCTAssertEqual(policy.evaluate(batteryLevel: 10, isPluggedIn: false), .warning)
    }

    func testCriticalAtCriticalThreshold() {
        var policy = WarningPolicy(threshold: 10)

        XCTAssertEqual(policy.evaluate(batteryLevel: 6, isPluggedIn: false), .warning)
        XCTAssertEqual(policy.evaluate(batteryLevel: 5, isPluggedIn: false), .critical)
    }

    func testNoWarningWhilePluggedIn() {
        var policy = WarningPolicy(threshold: 10)

        XCTAssertEqual(policy.evaluate(batteryLevel: 3, isPluggedIn: true), .none)
    }

    func testDismissedWarningStaysHiddenAtSameLevel() {
        var policy = WarningPolicy(threshold: 10)

        policy.dismiss(at: 8)

        XCTAssertEqual(policy.evaluate(batteryLevel: 8, isPluggedIn: false), .none)
    }

    func testDismissedWarningStaysHiddenWhenLevelJittersUp() {
        var policy = WarningPolicy(threshold: 10)

        policy.dismiss(at: 8)

        XCTAssertEqual(policy.evaluate(batteryLevel: 9, isPluggedIn: false), .none)
    }

    func testDismissedWarningReturnsAfterFurtherDrop() {
        var policy = WarningPolicy(threshold: 10)

        policy.dismiss(at: 8)

        XCTAssertEqual(policy.evaluate(batteryLevel: 7, isPluggedIn: false), .warning)
    }

    func testDismissedWarningComesBackAsCritical() {
        var policy = WarningPolicy(threshold: 10)

        policy.dismiss(at: 6)

        XCTAssertEqual(policy.evaluate(batteryLevel: 5, isPluggedIn: false), .critical)
    }

    func testConnectingPowerForgetsTheDismissal() {
        var policy = WarningPolicy(threshold: 10)
        policy.dismiss(at: 8)

        _ = policy.evaluate(batteryLevel: 8, isPluggedIn: true)

        XCTAssertEqual(policy.evaluate(batteryLevel: 8, isPluggedIn: false), .warning)
    }

    func testLoweringThresholdBelowLevelClearsWarning() {
        var policy = WarningPolicy(threshold: 20)
        XCTAssertEqual(policy.evaluate(batteryLevel: 15, isPluggedIn: false), .warning)

        policy.threshold = 10

        XCTAssertEqual(policy.evaluate(batteryLevel: 15, isPluggedIn: false), .none)
    }
}
