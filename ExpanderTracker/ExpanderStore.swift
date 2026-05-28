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
        save()
    }

    func logStretchingSession(label: StretchSessionLabel, turns: Int, timerMinutes: Int, startedAt: Date, completedAt: Date) {
        let log = StretchingSessionLog(
            date: ProtocolLogic.dateKey(startedAt),
            startedAt: startedAt,
            completedAt: completedAt,
            sessionLabel: label,
            stretchTurnCount: turns,
            timerDurationMinutes: timerMinutes,
            status: .completed
        )
        data.stretchingLogs.insert(log, at: 0)
        save()
    }

    func logIncompleteStretchingSession(label: StretchSessionLabel, turns: Int, timerMinutes: Int, startedAt: Date) {
        let log = StretchingSessionLog(
            date: ProtocolLogic.dateKey(startedAt),
            startedAt: startedAt,
            completedAt: nil,
            sessionLabel: label,
            stretchTurnCount: turns,
            timerDurationMinutes: timerMinutes,
            status: .incomplete
        )
        data.stretchingLogs.insert(log, at: 0)
        save()
    }

    func logForwardTurn(overrideReason: String = "") {
        let before = data.settings.currentNutPosition
        let after = before.next()
        let now = Date()
        let log = ForwardTurnLog(
            date: ProtocolLogic.dateKey(now),
            completedAt: now,
            beforePosition: before,
            afterPosition: after,
            overrideReason: overrideReason
        )
        data.forwardLogs.insert(log, at: 0)
        data.settings.currentNutPosition = after
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
        var rows = [["type", "date", "time", "label", "turns", "timerMinutes", "status", "beforePosition", "afterPosition", "notes"]]

        rows += data.stretchingLogs.map { log in
            [
                "stretching",
                log.date,
                log.startedAt.ISO8601Format(),
                log.sessionLabel.rawValue,
                String(log.stretchTurnCount),
                String(log.timerDurationMinutes),
                log.status.rawValue,
                "",
                "",
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
                log.beforePosition.rawValue,
                log.afterPosition.rawValue,
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
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let encoded = try? encoder.encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}
