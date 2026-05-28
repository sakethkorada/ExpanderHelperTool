import XCTest
@testable import ExpanderTracker

final class ProtocolLogicTests: XCTestCase {
    func testNutPositionCircularSequence() {
        XCTAssertEqual(NutPosition.threeA.next(), .two)
        XCTAssertEqual(NutPosition.two.next(), .three)
        XCTAssertEqual(NutPosition.three.next(), .four)
        XCTAssertEqual(NutPosition.four.next(), .five)
        XCTAssertEqual(NutPosition.five.next(), .unknown)
        XCTAssertEqual(NutPosition.unknown.next(), .threeA)
        XCTAssertEqual(NutPosition.five.next(turns: 3), .two)
    }

    func testForwardTurnUpdatesCurrentPosition() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.updateSettings { $0.currentNutPosition = .three }

        store.logForwardTurn()

        XCTAssertEqual(store.forwardLogs.first?.beforePosition, .three)
        XCTAssertEqual(store.forwardLogs.first?.afterPosition, .four)
        XCTAssertEqual(store.settings.currentNutPosition, .four)
    }

    func testStretchingSessionDoesNotUpdateCurrentPosition() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.updateSettings { $0.currentNutPosition = .unknown }

        store.logStretchingSession(label: .morning, turns: 5, timerMinutes: 30, startedAt: Date(), completedAt: Date())

        XCTAssertEqual(store.stretchingLogs.first?.stretchTurnCount, 5)
        XCTAssertEqual(store.settings.currentNutPosition, .unknown)
    }

    func testDoubleForwardTurnWarningLogic() {
        let now = Date()
        let log = ForwardTurnLog(
            date: ProtocolLogic.dateKey(now),
            completedAt: now,
            beforePosition: .threeA,
            afterPosition: .two
        )

        XCTAssertTrue(ProtocolLogic.forwardTurnLogged(on: now, in: [log]))
    }

    func testScheduleLogicForDueDays() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let monday = formatter.date(from: "2026-06-01 08:00:00")!
        let tuesday = formatter.date(from: "2026-06-02 08:00:00")!

        var daily = Settings()
        daily.forwardTurnSchedule.mode = .daily
        XCTAssertTrue(ProtocolLogic.isForwardTurnDue(settings: daily, date: monday))

        var weekdays = Settings()
        weekdays.forwardTurnSchedule.mode = .weekdays
        weekdays.forwardTurnSchedule.weekdays = [2]
        XCTAssertTrue(ProtocolLogic.isForwardTurnDue(settings: weekdays, date: monday))
        XCTAssertFalse(ProtocolLogic.isForwardTurnDue(settings: weekdays, date: tuesday))

        var custom = Settings()
        custom.forwardTurnSchedule.mode = .customDates
        custom.forwardTurnSchedule.customDates = ["2026-06-02"]
        XCTAssertTrue(ProtocolLogic.isForwardTurnDue(settings: custom, date: tuesday))

        var off = Settings()
        off.forwardTurnSchedule.mode = .off
        XCTAssertFalse(ProtocolLogic.isForwardTurnDue(settings: off, date: monday))
    }
}
