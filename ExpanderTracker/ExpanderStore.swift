import Foundation
import Combine

final class ExpanderStore: ObservableObject {
    @Published private(set) var data = AppData()

    private let storageKey: String

    init(storageKey: String = "expander-tracker-native-v1") {
        self.storageKey = storageKey
        load()
    }

    var settings: Settings { data.settings }
    var stretchingLogs: [StretchingSessionLog] { data.stretchingLogs }
    var forwardLogs: [ForwardTurnLog] { data.forwardLogs }

    func updateSettings(_ transform: (inout Settings) -> Void) {
        transform(&data.settings)
        data.settings = data.settings.normalized
        save()
    }

    func logStretchingSession(label: StretchSessionLabel, turns: Int, timerMinutes: Int, startedAt: Date, completedAt: Date) {
        let settings = data.settings.normalized
        let startIndex = settings.currentBoltIndex
        let temporaryIndex = BoltMath.calculateStretchForwardTarget(
            startIndex: startIndex,
            stretchTurnCount: turns,
            totalPositions: settings.boltPositionCount
        )
        let returnIndex = BoltMath.calculateStretchReturnTarget(
            forwardTargetIndex: temporaryIndex,
            stretchTurnCount: turns,
            totalPositions: settings.boltPositionCount
        )
        let log = StretchingSessionLog(
            date: ProtocolLogic.dateKey(startedAt),
            startedAt: startedAt,
            completedAt: completedAt,
            sessionLabel: label,
            stretchTurnCount: turns,
            timerDurationMinutes: timerMinutes,
            status: .completed,
            startPositionIndex: startIndex,
            startPositionLabel: BoltMath.getDisplayLabel(index: startIndex, labels: settings.boltLabels),
            temporaryTargetIndex: temporaryIndex,
            temporaryTargetLabel: BoltMath.getDisplayLabel(index: temporaryIndex, labels: settings.boltLabels),
            returnTargetIndex: returnIndex,
            returnTargetLabel: BoltMath.getDisplayLabel(index: returnIndex, labels: settings.boltLabels)
        )
        data.stretchingLogs.insert(log, at: 0)
        save()
    }

    func logIncompleteStretchingSession(label: StretchSessionLabel, turns: Int, timerMinutes: Int, startedAt: Date) {
        let settings = data.settings.normalized
        let startIndex = settings.currentBoltIndex
        let temporaryIndex = BoltMath.calculateStretchForwardTarget(
            startIndex: startIndex,
            stretchTurnCount: turns,
            totalPositions: settings.boltPositionCount
        )
        let returnIndex = BoltMath.calculateStretchReturnTarget(
            forwardTargetIndex: temporaryIndex,
            stretchTurnCount: turns,
            totalPositions: settings.boltPositionCount
        )
        let log = StretchingSessionLog(
            date: ProtocolLogic.dateKey(startedAt),
            startedAt: startedAt,
            completedAt: nil,
            sessionLabel: label,
            stretchTurnCount: turns,
            timerDurationMinutes: timerMinutes,
            status: .incomplete,
            startPositionIndex: startIndex,
            startPositionLabel: BoltMath.getDisplayLabel(index: startIndex, labels: settings.boltLabels),
            temporaryTargetIndex: temporaryIndex,
            temporaryTargetLabel: BoltMath.getDisplayLabel(index: temporaryIndex, labels: settings.boltLabels),
            returnTargetIndex: returnIndex,
            returnTargetLabel: BoltMath.getDisplayLabel(index: returnIndex, labels: settings.boltLabels)
        )
        data.stretchingLogs.insert(log, at: 0)
        save()
    }

    func logForwardTurn(turns: Int? = nil, wasScheduled: Bool = true, overrideReason: String = "") {
        let settings = data.settings.normalized
        let numberOfTurns = max(1, turns ?? settings.forwardTurnsPerSession)
        let beforeIndex = settings.currentBoltIndex
        let afterIndex = BoltMath.getPositionAfterTurns(
            startIndex: beforeIndex,
            turnCount: numberOfTurns,
            totalPositions: settings.boltPositionCount
        )
        let now = Date()
        let log = ForwardTurnLog(
            date: ProtocolLogic.dateKey(now),
            completedAt: now,
            startPositionIndex: beforeIndex,
            startPositionLabel: BoltMath.getDisplayLabel(index: beforeIndex, labels: settings.boltLabels),
            endPositionIndex: afterIndex,
            endPositionLabel: BoltMath.getDisplayLabel(index: afterIndex, labels: settings.boltLabels),
            numberOfTurns: numberOfTurns,
            wasScheduled: wasScheduled,
            overrideReason: overrideReason
        )
        data.forwardLogs.insert(log, at: 0)
        data.settings.currentBoltIndex = afterIndex
        save()
    }

    func deleteStretchingLog(_ log: StretchingSessionLog) {
        data.stretchingLogs.removeAll { $0.id == log.id }
        save()
    }

    func deleteForwardLog(_ log: ForwardTurnLog) {
        data.forwardLogs.removeAll { $0.id == log.id }
        save()
    }

    func markStretchingIncomplete(_ log: StretchingSessionLog) {
        guard let index = data.stretchingLogs.firstIndex(where: { $0.id == log.id }) else { return }
        data.stretchingLogs[index].status = .incomplete
        data.stretchingLogs[index].completedAt = nil
        save()
    }

    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return "{}" }
        return String(data: encoded, encoding: .utf8) ?? "{}"
    }

    func exportCSV() -> String {
        var rows = [["type", "date", "time", "label", "turns", "timerMinutes", "status", "startIndex", "startLabel", "endIndex", "endLabel", "notes"]]

        rows += data.stretchingLogs.map { log in
            [
                "stretching",
                log.date,
                log.startedAt.ISO8601Format(),
                log.sessionLabel.rawValue,
                String(log.stretchTurnCount),
                String(log.timerDurationMinutes),
                log.status.rawValue,
                String(log.startPositionIndex + 1),
                log.startPositionLabel,
                String(log.returnTargetIndex + 1),
                log.returnTargetLabel,
                log.notes
            ]
        }

        rows += data.forwardLogs.map { log in
            [
                "forward",
                log.date,
                log.completedAt.ISO8601Format(),
                "",
                String(log.numberOfTurns),
                "",
                "completed",
                String(log.startPositionIndex + 1),
                log.startPositionLabel,
                String(log.endPositionIndex + 1),
                log.endPositionLabel,
                log.notes
            ]
        }

        return rows.map { row in
            row.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
        }.joined(separator: "\n")
    }

    private func load() {
        guard let stored = UserDefaults.standard.data(forKey: storageKey) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(AppData.self, from: stored) {
            data = decoded
            data.settings = data.settings.normalized
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}
