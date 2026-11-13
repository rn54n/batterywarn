import XCTest
import IOKit.ps
@testable import BatteryWarn

final class BatteryReadingTests: XCTestCase {
    func testReadsLevelOnBatteryPower() throws {
        let reading = try XCTUnwrap(BatteryReading(description: [
            kIOPSCurrentCapacityKey: 42,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSIsChargingKey: false
        ]))

        XCTAssertEqual(reading.level, 42)
        XCTAssertFalse(reading.isPluggedIn)
        XCTAssertFalse(reading.isCharging)
    }

    func testReadsChargingOnACPower() throws {
        let reading = try XCTUnwrap(BatteryReading(description: [
            kIOPSCurrentCapacityKey: 80,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSIsChargingKey: true
        ]))

        XCTAssertTrue(reading.isPluggedIn)
        XCTAssertTrue(reading.isCharging)
    }

    func testReadsTimeToEmptyOnBatteryPower() throws {
        let reading = try XCTUnwrap(BatteryReading(description: [
            kIOPSCurrentCapacityKey: 9,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: 17
        ]))

        XCTAssertEqual(reading.minutesRemaining, 17)
    }

    func testTimeRemainingIsUnknownWhileSystemIsStillEstimating() throws {
        let reading = try XCTUnwrap(BatteryReading(description: [
            kIOPSCurrentCapacityKey: 9,
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue,
            kIOPSTimeToEmptyKey: -1
        ]))

        XCTAssertNil(reading.minutesRemaining)
    }

    func testTimeRemainingIsUnknownWhilePluggedIn() throws {
        let reading = try XCTUnwrap(BatteryReading(description: [
            kIOPSCurrentCapacityKey: 9,
            kIOPSPowerSourceStateKey: kIOPSACPowerValue,
            kIOPSTimeToEmptyKey: 17
        ]))

        XCTAssertNil(reading.minutesRemaining)
    }

    func testNoReadingWithoutCapacity() {
        XCTAssertNil(BatteryReading(description: [
            kIOPSPowerSourceStateKey: kIOPSBatteryPowerValue
        ]))
    }
}
