import XCTest
import IOKit.ps
@testable import BatteryWarn

final class BatteryMonitorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var source: BatteryReading?
    private var monitor: BatteryMonitor!
    private var changes: [WarningLevel] = []

    override func setUp() {
        super.setUp()
        let suite = "BatteryMonitorTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }

        source = reading(level: 80)
        changes = []
        monitor = BatteryMonitor(defaults: defaults, readPowerSource: { [unowned self] in self.source })
        monitor.threshold = 10
        monitor.onWarningChange = { [unowned self] level in self.changes.append(level) }
    }

    private func reading(level: Int, pluggedIn: Bool = false, minutes: Int? = nil) -> BatteryReading? {
        var description: [String: Any] = [
            kIOPSCurrentCapacityKey: level,
            kIOPSPowerSourceStateKey: pluggedIn ? kIOPSACPowerValue : kIOPSBatteryPowerValue
        ]
        if let minutes = minutes {
            description[kIOPSTimeToEmptyKey] = minutes
        }
        return BatteryReading(description: description)
    }

    private func battery(_ level: Int, pluggedIn: Bool = false, minutes: Int? = nil) {
        source = reading(level: level, pluggedIn: pluggedIn, minutes: minutes)
        monitor.refresh()
    }

    func testPublishesTheCurrentReading() {
        battery(9, minutes: 14)

        XCTAssertEqual(monitor.batteryLevel, 9)
        XCTAssertFalse(monitor.isPluggedIn)
        XCTAssertEqual(monitor.minutesRemaining, 14)
    }

    func testStaysQuietAboveThreshold() {
        battery(11)

        XCTAssertEqual(changes, [])
    }

    func testWarnsOnceWhileLevelStaysLow() {
        battery(10)
        battery(10)

        XCTAssertEqual(changes, [.warning])
    }

    func testOpenWarningEscalatesToCritical() {
        battery(8)
        battery(5)

        XCTAssertEqual(changes, [.warning, .critical])
    }

    func testDismissingClearsWarningUntilNextDrop() {
        battery(8)

        monitor.dismissOverlay()
        battery(8)
        battery(7)

        XCTAssertEqual(changes, [.warning, .none, .warning])
    }

    func testConnectingPowerClearsWarning() {
        battery(8)
        battery(8, pluggedIn: true)

        XCTAssertEqual(changes, [.warning, .none])
    }

    func testRaisingThresholdAboveLevelWarnsImmediately() {
        battery(50)

        monitor.threshold = 60

        XCTAssertEqual(changes, [.warning])
    }

    func testLoweringThresholdBelowLevelClearsWarning() {
        battery(9)

        monitor.threshold = 5

        XCTAssertEqual(changes, [.warning, .none])
    }

    func testThresholdSurvivesRelaunch() {
        monitor.threshold = 35

        let relaunched = BatteryMonitor(defaults: defaults, readPowerSource: { nil })

        XCTAssertEqual(relaunched.threshold, 35)
    }

    func testKeepsLastReadingWhenPowerSourceIsUnavailable() {
        battery(42)

        source = nil
        monitor.refresh()

        XCTAssertEqual(monitor.batteryLevel, 42)
    }
}
