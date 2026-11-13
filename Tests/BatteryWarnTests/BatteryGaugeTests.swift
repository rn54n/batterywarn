import XCTest
@testable import BatteryWarn

final class BatteryGaugeTests: XCTestCase {
    func testDragPositionMapsToPercentOfTheBar() {
        XCTAssertEqual(BatteryGaugeView.threshold(atX: 105, innerWidth: 500), 21)
    }

    func testDragPositionRoundsToTheNearestPercent() {
        XCTAssertEqual(BatteryGaugeView.threshold(atX: 107, innerWidth: 500), 21)
        XCTAssertEqual(BatteryGaugeView.threshold(atX: 108, innerWidth: 500), 22)
    }

    func testDraggingPastTheLeftEndStopsAtTheLowestThreshold() {
        XCTAssertEqual(BatteryGaugeView.threshold(atX: -40, innerWidth: 500), 5)
    }

    func testDraggingPastTheRightEndStopsAtTheHighestThreshold() {
        XCTAssertEqual(BatteryGaugeView.threshold(atX: 900, innerWidth: 500), 99)
    }
}
