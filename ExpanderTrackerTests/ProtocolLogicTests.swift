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

    func testActiveTimerPersistsAfterNavigatingAway() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        let startedAt = Date(timeIntervalSince1970: 1_000)

        store.startActiveStretchingSession(label: .morning, turns: 3, timerMinutes: 15, startedAt: startedAt)

        XCTAssertNotNil(store.activeStretchingSession)
        XCTAssertEqual(store.activeStretchingSession?.startedAt, startedAt)
        XCTAssertEqual(store.activeStretchingSession?.stretchTurnCount, 3)
    }

    func testActiveTimerSurvivesStoreReload() {
        let storageKey = UUID().uuidString
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let firstStore = ExpanderStore(storageKey: storageKey)

        firstStore.startActiveStretchingSession(label: .evening, turns: 4, timerMinutes: 15, startedAt: startedAt)
        let reloadedStore = ExpanderStore(storageKey: storageKey)

        XCTAssertEqual(reloadedStore.activeStretchingSession?.startedAt, startedAt)
        XCTAssertEqual(reloadedStore.activeStretchingSession?.stretchTurnCount, 4)
    }

    func testRemainingTimeIsCalculatedFromTimestamps() {
        let session = ActiveStretchingSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            durationSeconds: 900,
            sessionLabel: .morning,
            stretchTurnCount: 3,
            startPositionIndex: 0,
            startPositionLabel: "3a",
            temporaryForwardTargetIndex: 3,
            temporaryForwardTargetLabel: "4",
            expectedReturnPositionIndex: 0,
            expectedReturnPositionLabel: "3a",
            status: .active
        )

        XCTAssertEqual(ProtocolLogic.remainingSeconds(for: session, now: Date(timeIntervalSince1970: 1_300)), 600)
    }

    func testTimerReachesReadyToReturnAfterElapsedDuration() {
        let session = ActiveStretchingSession(
            startedAt: Date(timeIntervalSince1970: 1_000),
            durationSeconds: 900,
            sessionLabel: .morning,
            stretchTurnCount: 3,
            startPositionIndex: 0,
            startPositionLabel: "3a",
            temporaryForwardTargetIndex: 3,
            temporaryForwardTargetLabel: "4",
            expectedReturnPositionIndex: 0,
            expectedReturnPositionLabel: "3a",
            status: .active
        )

        XCTAssertEqual(ProtocolLogic.activeStretchingStatus(for: session, now: Date(timeIntervalSince1970: 2_000)), .readyToReturn)
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
        XCTAssertEqual(store.netForwardTurns, 1)
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
        XCTAssertEqual(store.netForwardTurns, 3)
    }

    func testStretchingDoesNotAffectNetTurns() {
        let store = ExpanderStore(storageKey: UUID().uuidString)

        store.logStretchingSession(label: .morning, turns: 5, timerMinutes: 30, startedAt: Date(), completedAt: Date())

        XCTAssertEqual(store.netForwardTurns, 0)
    }

    func testManualNetTurnsAdjustmentUpdatesDisplayedValueWithoutDeletingLogs() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.logForwardTurn(turns: 2)

        store.setDisplayedNetForwardTurns(5)

        XCTAssertEqual(store.forwardLogs.count, 1)
        XCTAssertEqual(store.netForwardTurns, 5)
        XCTAssertEqual(store.settings.netForwardTurnsOffset, 3)
    }

    func testDeletingForwardLogRecalculatesNetTurnsFromLogsAndOffset() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.logForwardTurn(turns: 3)
        guard let log = store.forwardLogs.first else {
            XCTFail("Expected forward log")
            return
        }

        store.deleteForwardLog(log)

        XCTAssertEqual(store.netForwardTurns, 0)
    }

    func testAlignerChangeDateUsesConfiguredTwoWeekDuration() {
        var settings = Settings()
        settings.aligner.wearStartedAt = Date(timeIntervalSince1970: 1_000)
        settings.aligner.wearDurationWeeks = 2

        let expected = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date(timeIntervalSince1970: 1_000))

        XCTAssertEqual(settings.aligner.normalized.nextChangeDate, expected)
        XCTAssertEqual(ProtocolLogic.alignerStatus(settings: settings, now: Date(timeIntervalSince1970: 1_000)), "14 days remaining")
    }

    func testStartingNextAlignerPreservesPreviousAlignerHistory() {
        let store = ExpanderStore(storageKey: UUID().uuidString)
        store.updateSettings { settings in
            settings.aligner.currentAlignerNumber = 4
            settings.aligner.wearStartedAt = Date(timeIntervalSince1970: 1_000)
            settings.aligner.wearDurationWeeks = 3
            settings.aligner.notes = "Lower tray"
        }

        store.startNextAligner()

        XCTAssertEqual(store.alignerSettings.currentAlignerNumber, 5)
        XCTAssertNotNil(store.alignerSettings.wearStartedAt)
        XCTAssertEqual(store.data.alignerChangeLogs.first?.alignerNumber, 4)
        XCTAssertEqual(store.data.alignerChangeLogs.first?.durationWeeks, 3)
    }

    func testOlderSavedDataWithoutNewAlignerFieldsStillDecodes() throws {
        let oldData = Data(#"{
            "settings": {
                "forwardTurnSchedule": { "mode": "daily", "weekdays": [1, 2, 3, 4, 5, 6, 7] }
            },
            "stretchingLogs": [],
            "forwardLogs": []
        }"#.utf8)

        let decoded = try JSONDecoder().decode(AppData.self, from: oldData)

        XCTAssertEqual(decoded.settings.forwardTurnSchedule.weeklyTargetCount, 3)
        XCTAssertEqual(decoded.settings.aligner.currentAlignerNumber, 1)
        XCTAssertTrue(decoded.alignerChangeLogs.isEmpty)
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
