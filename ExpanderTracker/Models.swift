import Foundation

enum LegacyNutPosition: String, CaseIterable, Codable {
    case threeA = "3a"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case unknown = "Unknown"
}

enum StretchSessionLabel: String, CaseIterable, Codable, Identifiable {
    case morning
    case evening
    case custom

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum StretchStatus: String, Codable {
    case completed
    case incomplete
}

enum ForwardScheduleMode: String, CaseIterable, Codable, Identifiable {
    case daily
    case weekdays
    case customWeekly
    case manualOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Specific weekdays"
        case .customWeekly: return "Times per week"
        case .manualOnly: return "Manual only"
        }
    }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "daily":
            self = .daily
        case "weekdays":
            self = .weekdays
        case "customWeekly", "customDates":
            self = .customWeekly
        case "manualOnly", "off":
            self = .manualOnly
        default:
            self = .manualOnly
        }
    }
}

struct ForwardTurnSchedule: Codable, Equatable {
    var mode: ForwardScheduleMode = .daily
    var weekdays: Set<Int> = Set(1...7)
    var weeklyTargetCount = 3
}

struct ReminderSettings: Codable, Equatable {
    var morningStretching = ""
    var eveningStretching = ""
    var forwardTurn = ""
}

struct Settings: Codable, Equatable {
    var boltPositionCount = 6
    var boltLabels = ["3a", "2", "3", "4", "5", "Unknown"]
    var currentBoltIndex = 0
    var forwardTurnsPerSession = 1
    var forwardTurnSchedule = ForwardTurnSchedule()
    var stretchingSessionsPerDay = 2
    var allowedStretchTurnCounts = [3, 4, 5]
    var defaultStretchingTurns = 3
    var defaultTimerDurationMinutes = 15
    var reminders = ReminderSettings()

    var normalized: Settings {
        var copy = self
        copy.boltPositionCount = max(2, copy.boltPositionCount)
        if copy.boltLabels.count < copy.boltPositionCount {
            let start = copy.boltLabels.count + 1
            copy.boltLabels += (start...copy.boltPositionCount).map { "Position \($0)" }
        } else if copy.boltLabels.count > copy.boltPositionCount {
            copy.boltLabels = Array(copy.boltLabels.prefix(copy.boltPositionCount))
        }
        copy.currentBoltIndex = BoltMath.normalizedIndex(copy.currentBoltIndex, totalPositions: copy.boltPositionCount)
        copy.forwardTurnsPerSession = max(1, copy.forwardTurnsPerSession)
        copy.forwardTurnSchedule.weeklyTargetCount = max(1, copy.forwardTurnSchedule.weeklyTargetCount)
        return copy
    }

    enum CodingKeys: String, CodingKey {
        case boltPositionCount
        case boltLabels
        case currentBoltIndex
        case currentNutPosition
        case forwardTurnsPerSession
        case forwardTurnSchedule
        case stretchingSessionsPerDay
        case allowedStretchTurnCounts
        case defaultStretchingTurns
        case defaultTimerDurationMinutes
        case reminders
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boltPositionCount = try container.decodeIfPresent(Int.self, forKey: .boltPositionCount) ?? 6
        boltLabels = try container.decodeIfPresent([String].self, forKey: .boltLabels) ?? ["3a", "2", "3", "4", "5", "Unknown"]
        currentBoltIndex = try container.decodeIfPresent(Int.self, forKey: .currentBoltIndex) ?? 0

        if let legacyPosition = try container.decodeIfPresent(LegacyNutPosition.self, forKey: .currentNutPosition),
           let legacyIndex = boltLabels.firstIndex(of: legacyPosition.rawValue) {
            currentBoltIndex = legacyIndex
        }

        forwardTurnsPerSession = try container.decodeIfPresent(Int.self, forKey: .forwardTurnsPerSession) ?? 1
        forwardTurnSchedule = try container.decodeIfPresent(ForwardTurnSchedule.self, forKey: .forwardTurnSchedule) ?? ForwardTurnSchedule()
        stretchingSessionsPerDay = try container.decodeIfPresent(Int.self, forKey: .stretchingSessionsPerDay) ?? 2
        allowedStretchTurnCounts = try container.decodeIfPresent([Int].self, forKey: .allowedStretchTurnCounts) ?? [3, 4, 5]
        defaultStretchingTurns = try container.decodeIfPresent(Int.self, forKey: .defaultStretchingTurns) ?? 3
        defaultTimerDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultTimerDurationMinutes) ?? 15
        reminders = try container.decodeIfPresent(ReminderSettings.self, forKey: .reminders) ?? ReminderSettings()
        self = normalized
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let settings = normalized
        try container.encode(settings.boltPositionCount, forKey: .boltPositionCount)
        try container.encode(settings.boltLabels, forKey: .boltLabels)
        try container.encode(settings.currentBoltIndex, forKey: .currentBoltIndex)
        try container.encode(settings.forwardTurnsPerSession, forKey: .forwardTurnsPerSession)
        try container.encode(settings.forwardTurnSchedule, forKey: .forwardTurnSchedule)
        try container.encode(settings.stretchingSessionsPerDay, forKey: .stretchingSessionsPerDay)
        try container.encode(settings.allowedStretchTurnCounts, forKey: .allowedStretchTurnCounts)
        try container.encode(settings.defaultStretchingTurns, forKey: .defaultStretchingTurns)
        try container.encode(settings.defaultTimerDurationMinutes, forKey: .defaultTimerDurationMinutes)
        try container.encode(settings.reminders, forKey: .reminders)
    }
}

struct StretchingSessionLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: String
    var startedAt: Date
    var completedAt: Date?
    var sessionLabel: StretchSessionLabel
    var stretchTurnCount: Int
    var timerDurationMinutes: Int
    var status: StretchStatus
    var startPositionIndex: Int
    var startPositionLabel: String
    var temporaryTargetIndex: Int
    var temporaryTargetLabel: String
    var returnTargetIndex: Int
    var returnTargetLabel: String
    var notes: String = ""

    init(
        id: UUID = UUID(),
        date: String,
        startedAt: Date,
        completedAt: Date?,
        sessionLabel: StretchSessionLabel,
        stretchTurnCount: Int,
        timerDurationMinutes: Int,
        status: StretchStatus,
        startPositionIndex: Int,
        startPositionLabel: String,
        temporaryTargetIndex: Int,
        temporaryTargetLabel: String,
        returnTargetIndex: Int,
        returnTargetLabel: String,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.sessionLabel = sessionLabel
        self.stretchTurnCount = stretchTurnCount
        self.timerDurationMinutes = timerDurationMinutes
        self.status = status
        self.startPositionIndex = startPositionIndex
        self.startPositionLabel = startPositionLabel
        self.temporaryTargetIndex = temporaryTargetIndex
        self.temporaryTargetLabel = temporaryTargetLabel
        self.returnTargetIndex = returnTargetIndex
        self.returnTargetLabel = returnTargetLabel
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case startedAt
        case completedAt
        case sessionLabel
        case stretchTurnCount
        case timerDurationMinutes
        case status
        case startPositionIndex
        case startPositionLabel
        case temporaryTargetIndex
        case temporaryTargetLabel
        case returnTargetIndex
        case returnTargetLabel
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(String.self, forKey: .date)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        sessionLabel = try container.decode(StretchSessionLabel.self, forKey: .sessionLabel)
        stretchTurnCount = try container.decode(Int.self, forKey: .stretchTurnCount)
        timerDurationMinutes = try container.decode(Int.self, forKey: .timerDurationMinutes)
        status = try container.decode(StretchStatus.self, forKey: .status)
        startPositionIndex = try container.decodeIfPresent(Int.self, forKey: .startPositionIndex) ?? 0
        startPositionLabel = try container.decodeIfPresent(String.self, forKey: .startPositionLabel) ?? ""
        temporaryTargetIndex = try container.decodeIfPresent(Int.self, forKey: .temporaryTargetIndex) ?? 0
        temporaryTargetLabel = try container.decodeIfPresent(String.self, forKey: .temporaryTargetLabel) ?? ""
        returnTargetIndex = try container.decodeIfPresent(Int.self, forKey: .returnTargetIndex) ?? 0
        returnTargetLabel = try container.decodeIfPresent(String.self, forKey: .returnTargetLabel) ?? startPositionLabel
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct ForwardTurnLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: String
    var completedAt: Date
    var startPositionIndex: Int
    var startPositionLabel: String
    var endPositionIndex: Int
    var endPositionLabel: String
    var numberOfTurns = 1
    var wasScheduled = true
    var overrideReason: String = ""
    var notes: String = ""

    init(
        id: UUID = UUID(),
        date: String,
        completedAt: Date,
        startPositionIndex: Int,
        startPositionLabel: String,
        endPositionIndex: Int,
        endPositionLabel: String,
        numberOfTurns: Int = 1,
        wasScheduled: Bool = true,
        overrideReason: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.completedAt = completedAt
        self.startPositionIndex = startPositionIndex
        self.startPositionLabel = startPositionLabel
        self.endPositionIndex = endPositionIndex
        self.endPositionLabel = endPositionLabel
        self.numberOfTurns = numberOfTurns
        self.wasScheduled = wasScheduled
        self.overrideReason = overrideReason
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case completedAt
        case beforePosition
        case afterPosition
        case startPositionIndex
        case startPositionLabel
        case endPositionIndex
        case endPositionLabel
        case numberOfTurns
        case wasScheduled
        case overrideReason
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(String.self, forKey: .date)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        numberOfTurns = try container.decodeIfPresent(Int.self, forKey: .numberOfTurns) ?? 1
        wasScheduled = try container.decodeIfPresent(Bool.self, forKey: .wasScheduled) ?? true
        overrideReason = try container.decodeIfPresent(String.self, forKey: .overrideReason) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""

        if let startIndex = try container.decodeIfPresent(Int.self, forKey: .startPositionIndex),
           let endIndex = try container.decodeIfPresent(Int.self, forKey: .endPositionIndex) {
            startPositionIndex = startIndex
            endPositionIndex = endIndex
            startPositionLabel = try container.decodeIfPresent(String.self, forKey: .startPositionLabel) ?? ""
            endPositionLabel = try container.decodeIfPresent(String.self, forKey: .endPositionLabel) ?? ""
        } else {
            let before = try container.decodeIfPresent(LegacyNutPosition.self, forKey: .beforePosition)
            let after = try container.decodeIfPresent(LegacyNutPosition.self, forKey: .afterPosition)
            let labels = Settings().boltLabels
            startPositionLabel = before?.rawValue ?? ""
            endPositionLabel = after?.rawValue ?? ""
            startPositionIndex = labels.firstIndex(of: startPositionLabel) ?? 0
            endPositionIndex = labels.firstIndex(of: endPositionLabel) ?? 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(startPositionIndex, forKey: .startPositionIndex)
        try container.encode(startPositionLabel, forKey: .startPositionLabel)
        try container.encode(endPositionIndex, forKey: .endPositionIndex)
        try container.encode(endPositionLabel, forKey: .endPositionLabel)
        try container.encode(numberOfTurns, forKey: .numberOfTurns)
        try container.encode(wasScheduled, forKey: .wasScheduled)
        try container.encode(overrideReason, forKey: .overrideReason)
        try container.encode(notes, forKey: .notes)
    }
}

struct AppData: Codable, Equatable {
    var settings = Settings()
    var stretchingLogs: [StretchingSessionLog] = []
    var forwardLogs: [ForwardTurnLog] = []
}

enum BoltMath {
    static func normalizedIndex(_ index: Int, totalPositions: Int) -> Int {
        guard totalPositions > 0 else { return 0 }
        let remainder = index % totalPositions
        return remainder >= 0 ? remainder : remainder + totalPositions
    }

    static func getPositionAfterTurns(startIndex: Int, turnCount: Int, totalPositions: Int) -> Int {
        normalizedIndex(startIndex + turnCount, totalPositions: max(2, totalPositions))
    }

    static func getPositionBeforeTurns(startIndex: Int, turnCount: Int, totalPositions: Int) -> Int {
        normalizedIndex(startIndex - turnCount, totalPositions: max(2, totalPositions))
    }

    static func getDisplayLabel(index: Int, labels: [String]) -> String {
        guard !labels.isEmpty else { return "Position \(index + 1)" }
        let safeIndex = normalizedIndex(index, totalPositions: labels.count)
        let label = labels[safeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? "Position \(safeIndex + 1)" : label
    }

    static func calculateStretchForwardTarget(startIndex: Int, stretchTurnCount: Int, totalPositions: Int) -> Int {
        getPositionAfterTurns(startIndex: startIndex, turnCount: stretchTurnCount, totalPositions: totalPositions)
    }

    static func calculateStretchReturnTarget(forwardTargetIndex: Int, stretchTurnCount: Int, totalPositions: Int) -> Int {
        getPositionBeforeTurns(startIndex: forwardTargetIndex, turnCount: stretchTurnCount, totalPositions: totalPositions)
    }

    static func forwardPath(startIndex: Int, turnCount: Int, labels: [String]) -> [BoltPositionSnapshot] {
        let total = max(2, labels.count)
        return (0...max(0, turnCount)).map { offset in
            let index = getPositionAfterTurns(startIndex: startIndex, turnCount: offset, totalPositions: total)
            return BoltPositionSnapshot(index: index, label: getDisplayLabel(index: index, labels: labels))
        }
    }
}

struct BoltPositionSnapshot: Codable, Equatable, Identifiable {
    var index: Int
    var label: String
    var id: Int { index }

    var displayText: String {
        "Position \(index + 1): \(label)"
    }
}

enum ProtocolLogic {
    static let calendar = Calendar.current

    static func dateKey(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func isForwardTurnDue(settings: Settings, forwardLogs: [ForwardTurnLog] = [], date: Date = Date()) -> Bool {
        let settings = settings.normalized
        let schedule = settings.forwardTurnSchedule
        switch schedule.mode {
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return schedule.weekdays.contains(weekday)
        case .customWeekly:
            return completedForwardSessionsThisWeek(logs: forwardLogs, date: date) < schedule.weeklyTargetCount
        case .manualOnly:
            return false
        }
    }

    static func forwardTurnLogged(on date: Date = Date(), in logs: [ForwardTurnLog]) -> Bool {
        let key = dateKey(date)
        return logs.contains { $0.date == key }
    }

    static func completedForwardSessionsThisWeek(logs: [ForwardTurnLog], date: Date = Date()) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return logs.filter { interval.contains($0.completedAt) && $0.wasScheduled }.count
    }

    static func remainingForwardSessionsThisWeek(settings: Settings, logs: [ForwardTurnLog], date: Date = Date()) -> Int {
        guard settings.forwardTurnSchedule.mode == .customWeekly else { return 0 }
        return max(0, settings.forwardTurnSchedule.weeklyTargetCount - completedForwardSessionsThisWeek(logs: logs, date: date))
    }

    static func forwardStatus(settings: Settings, logs: [ForwardTurnLog], date: Date = Date()) -> String {
        if forwardTurnLogged(on: date, in: logs) { return "Completed" }
        if settings.forwardTurnSchedule.mode == .customWeekly {
            let remaining = remainingForwardSessionsThisWeek(settings: settings, logs: logs, date: date)
            return remaining > 0 ? "Due, \(remaining) left this week" : "Not due"
        }
        return isForwardTurnDue(settings: settings, forwardLogs: logs, date: date) ? "Due" : "Not due"
    }

    static func stretchingStatus(_ label: StretchSessionLabel, logs: [StretchingSessionLog], date: Date = Date()) -> String {
        let key = dateKey(date)
        let latest = logs
            .filter { $0.date == key && $0.sessionLabel == label }
            .sorted { $0.startedAt > $1.startedAt }
            .first

        guard let latest else { return "Not completed" }
        return latest.status == .completed ? "Completed" : "In progress"
    }

    static func completedStretchCount(logs: [StretchingSessionLog], date: Date = Date()) -> Int {
        let key = dateKey(date)
        return logs.filter { $0.date == key && $0.status == .completed }.count
    }
}
