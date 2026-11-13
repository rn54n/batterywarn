import XCTest
@testable import BatteryWarn

final class BatteryFormatTests: XCTestCase {
    func testTimeRemainingInMinutes() {
        XCTAssertEqual(BatteryFormat.timeRemaining(minutes: 12), "About 12 min left")
    }

    func testTimeRemainingInHoursAndMinutes() {
        XCTAssertEqual(BatteryFormat.timeRemaining(minutes: 75), "About 1 h 15 min left")
    }

    func testTimeRemainingOnTheFullHour() {
        XCTAssertEqual(BatteryFormat.timeRemaining(minutes: 120), "About 2 h left")
    }

    func testNoTimeRemainingWhenUnknown() {
        XCTAssertNil(BatteryFormat.timeRemaining(minutes: nil))
    }

    func testDurationInMinutes() {
        XCTAssertEqual(BatteryFormat.duration(minutes: 45), "45 min")
    }

    func testDurationInHoursAndMinutes() {
        XCTAssertEqual(BatteryFormat.duration(minutes: 192), "3 h 12 min")
    }

    func testDurationOnTheFullHour() {
        XCTAssertEqual(BatteryFormat.duration(minutes: 60), "1 h")
    }

    func testPowerDetailOnBatteryWithEstimate() {
        XCTAssertEqual(
            BatteryFormat.powerDetail(isPluggedIn: false, isCharging: false, minutesRemaining: 315),
            "About 5 h 15 min left"
        )
    }

    func testPowerDetailPrefersChargingOverPluggedIn() {
        XCTAssertEqual(
            BatteryFormat.powerDetail(isPluggedIn: true, isCharging: true, minutesRemaining: nil),
            "Charging"
        )
    }

    func testMenuStatusOnBatteryWithEstimate() {
        XCTAssertEqual(
            BatteryFormat.menuStatus(level: 82, isPluggedIn: false, isCharging: false, minutesRemaining: 192),
            "Battery 82% · About 3 h 12 min left"
        )
    }

    func testMenuStatusOnBatteryWithoutEstimate() {
        XCTAssertEqual(
            BatteryFormat.menuStatus(level: 82, isPluggedIn: false, isCharging: false, minutesRemaining: nil),
            "Battery 82% · On battery"
        )
    }

    func testMenuStatusWhileCharging() {
        XCTAssertEqual(
            BatteryFormat.menuStatus(level: 40, isPluggedIn: true, isCharging: true, minutesRemaining: nil),
            "Battery 40% · Charging"
        )
    }

    func testMenuStatusPluggedInButNotCharging() {
        XCTAssertEqual(
            BatteryFormat.menuStatus(level: 100, isPluggedIn: true, isCharging: false, minutesRemaining: nil),
            "Battery 100% · Plugged in"
        )
    }
}
