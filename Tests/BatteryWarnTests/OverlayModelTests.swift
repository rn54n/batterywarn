import XCTest
@testable import BatteryWarn

final class OverlayModelTests: XCTestCase {
    private var dismissCount = 0

    private func makeModel(isCritical: Bool, allowsDismiss: Bool = true, isTest: Bool = false) -> OverlayModel {
        let model = OverlayModel(
            batteryLevel: isCritical ? 4 : 9,
            isCritical: isCritical,
            threshold: 10,
            allowsDismiss: allowsDismiss,
            isTest: isTest
        )
        model.onDismiss = { [unowned self] in self.dismissCount += 1 }
        return model
    }

    func testEscDismissesWarningImmediately() {
        let model = makeModel(isCritical: false)

        model.escPressed()

        XCTAssertEqual(dismissCount, 1)
    }

    func testEscAloneDoesNotDismissCritical() {
        let model = makeModel(isCritical: true)

        model.escPressed()

        XCTAssertEqual(dismissCount, 0)
        XCTAssertTrue(model.isHoldingEsc)
    }

    func testHoldingEscForThreeSecondsDismissesCritical() {
        let model = makeModel(isCritical: true)

        model.escPressed()
        model.advanceHold(by: 1.5)
        XCTAssertEqual(dismissCount, 0)
        XCTAssertEqual(model.escHoldProgress, 0.5, accuracy: 0.001)

        model.advanceHold(by: 1.5)
        XCTAssertEqual(dismissCount, 1)
    }

    func testReleasingEscStartsTheHoldOver() {
        let model = makeModel(isCritical: true)

        model.escPressed()
        model.advanceHold(by: 2)
        model.escReleased()
        XCTAssertFalse(model.isHoldingEsc)
        XCTAssertEqual(model.escHoldProgress, 0)

        model.escPressed()
        model.advanceHold(by: 2)
        XCTAssertEqual(dismissCount, 0)
    }

    func testEscIsIgnoredWhenDismissingIsOff() {
        let model = makeModel(isCritical: false, allowsDismiss: false)

        model.escPressed()

        XCTAssertEqual(dismissCount, 0)
    }

    func testHoldingEscIsIgnoredWhenDismissingIsOff() {
        let model = makeModel(isCritical: true, allowsDismiss: false)

        model.escPressed()
        model.advanceHold(by: 3)

        XCTAssertEqual(dismissCount, 0)
        XCTAssertFalse(model.isHoldingEsc)
    }

    func testPreviewStillClosesWithEscWhenDismissingIsOff() {
        let model = makeModel(isCritical: false, allowsDismiss: false, isTest: true)

        model.escPressed()

        XCTAssertEqual(dismissCount, 1)
    }

    func testTimePassingWithoutEscDoesNotDismiss() {
        let model = makeModel(isCritical: true)

        model.advanceHold(by: 10)

        XCTAssertEqual(dismissCount, 0)
    }

    func testCompletedHoldDismissesOnlyOnce() {
        let model = makeModel(isCritical: true)

        model.escPressed()
        model.advanceHold(by: 3)
        model.advanceHold(by: 1)

        XCTAssertEqual(dismissCount, 1)
    }
}
