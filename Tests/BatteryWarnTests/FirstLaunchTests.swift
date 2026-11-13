import XCTest
@testable import BatteryWarn

final class FirstLaunchTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        let suite = "FirstLaunchTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
    }

    func testTheVeryFirstLaunchIsReported() {
        XCTAssertTrue(FirstLaunch.consume(defaults: defaults))
    }

    func testLaterLaunchesAreNotReported() {
        _ = FirstLaunch.consume(defaults: defaults)

        XCTAssertFalse(FirstLaunch.consume(defaults: defaults))
    }
}
