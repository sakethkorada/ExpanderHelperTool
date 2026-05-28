import XCTest
@testable import ExpanderTracker

final class ProtocolLogicTests: XCTestCase {
    func testCircularForwardMovementWithConfigurablePositions() {
        XCTAssertEqual(BoltMath.getPositionAfterTurns(startIndex: 0, turnCount: 1, totalPositions: 6), 1)
        XCTAssertEqual(BoltMath.getPositionAfterTurns(startIndex: 5, turnCount: 1, totalPositions: 6), 0)
        XCTAssertEqual(BoltMath.getPositionAfterTurns(startIndex: 3, turnCount: 4, totalPositions: 5), 2)
    }

    func testCircularBackwardMovementWithConfigurablePositions() {
        XCTAssertEqual(BoltMath.getPositionBeforeTurns(startIndex: 0, turnCount: 1, totalPositions: 6), 5)
        XCTAssertEqual(BoltMath.getPositionBeforeTurns(startIndex: 2, turnCount: 4, totalPositions: 6), 4)
        XCTAssertEqual(BoltMath.getPositionBeforeTurns(startIndex: 1, turnCount: 8, totalPositions: 5), 3)
    }

    func testStretchingForwardTargetCalculation() {
        let target = BoltMath.calculateStretchForwardTarget(startIndex: 1, stretchTurnCount: 4, totalPositions: 6)
        XCTAssertEqual(target, 5)
    }

    func testStretchingReturnTargetCalculation() {
        let returnTarget = BoltMath.calculateStretchReturnTarget(forwardTargetIndex: 5, stretchTurnCount: 4, totalPositions: 6)
        XCTAssertEqual(returnTarget, 1)
    }

    func testStretchingSessionDoesNotUpdatePermanentCurrentPosition() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.updateSettings { settings in
            settings.currentBoltIndex = 5
        }

        store.logStretchingSession(label: .morning, turns: 5, timerMinutes: 30, startedAt: Date(), completedAt: Date())

        XCTAssertEqual(store.stretchingLogs.first?.stretchTurnCount, 5)
        XCTAssertEqual(store.settings.currentBoltIndex, 5)
    }

    func testForwardTurnsUpdatePermanentCurrentPosition() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.updateSettings { settings in
            settings.currentBoltIndex = 2
            settings.forwardTurnsPerSession = 1
        }

        store.logForwardTurn()

        XCTAssertEqual(store.forwardLogs.first?.startPositionIndex, 2)
        XCTAssertEqual(store.forwardLogs.first?.endPositionIndex, 3)
        XCTAssertEqual(store.settings.currentBoltIndex, 3)
    }

    func testMultipleForwardTurnsInOneScheduledSession() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.updateSettings { settings in
            settings.currentBoltIndex = 1
            settings.forwardTurnsPerSession = 3
        }

        store.logForwardTurn()

        XCTAssertEqual(store.forwardLogs.first?.numberOfTurns, 3)
        XCTAssertEqual(store.forwardLogs.first?.startPositionLabel, "2")
        XCTAssertEqual(store.forwardLogs.first?.endPositionLabel, "5")
        XCTAssertEqual(store.settings.currentBoltIndex, 4)
    }

    func testDoubleForwardTurnWarningLogic() {
        let now = Date()
        let log = ForwardTurnLog(
            date: ProtocolLogic.dateKey(now),
            completedAt: now,
            startPositionIndex: 0,
            startPositionLabel: "3a",
            endPositionIndex: 1,
            endPositionLabel: "2"
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

        var weekly = Settings()
        weekly.forwardTurnSchedule.mode = .customWeekly
        weekly.forwardTurnSchedule.weeklyTargetCount = 2
        XCTAssertTrue(ProtocolLogic.isForwardTurnDue(settings: weekly, forwardLogs: [], date: monday))

        var manual = Settings()
        manual.forwardTurnSchedule.mode = .manualOnly
        XCTAssertFalse(ProtocolLogic.isForwardTurnDue(settings: manual, date: monday))
    }
}
