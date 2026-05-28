import Foundation

enum NutPosition: String, CaseIterable, Codable, Identifiable {
    case threeA = "3a"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case unknown = "Unknown"

    var id: String { rawValue }

    func next(turns: Int = 1) -> NutPosition {
        let all = Self.allCases
        guard let start = all.firstIndex(of: self) else { return self }
        let index = (start + max(0, turns)) % all.count
        return all[index]
    }
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
    case customDates
    case off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekdays: return "Specific weekdays"
        case .customDates: return "Custom dates"
        case .off: return "Off / manual only"
        }
    }
}

struct ForwardTurnSchedule: Codable, Equatable {
    var mode: ForwardScheduleMode = .daily
    var weekdays: Set<Int> = Set(1...7)
    var customDates: Set<String> = []
}

struct ReminderSettings: Codable, Equatable {
    var morningStretching = ""
    var eveningStretching = ""
    var forwardTurn = ""
}

struct Settings: Codable, Equatable {
    var currentNutPosition: NutPosition = .threeA
    var forwardTurnSchedule = ForwardTurnSchedule()
    var stretchingSessionsPerDay = 2
    var allowedStretchTurnCounts = [3, 4, 5]
    var defaultStretchingTurns = 3
    var defaultTimerDurationMinutes = 15
    var reminders = ReminderSettings()
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
    var notes: String = ""
}

struct ForwardTurnLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: String
    var completedAt: Date
    var beforePosition: NutPosition
    var afterPosition: NutPosition
    var numberOfTurns = 1
    var overrideReason: String = ""
    var notes: String = ""
}

struct AppData: Codable, Equatable {
    var settings = Settings()
    var stretchingLogs: [StretchingSessionLog] = []
    var forwardLogs: [ForwardTurnLog] = []
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

    static func isForwardTurnDue(settings: Settings, date: Date = Date()) -> Bool {
        let schedule = settings.forwardTurnSchedule
        switch schedule.mode {
        case .daily:
            return true
        case .weekdays:
            let weekday = calendar.component(.weekday, from: date)
            return schedule.weekdays.contains(weekday)
        case .customDates:
            return schedule.customDates.contains(dateKey(date))
        case .off:
            return false
        }
    }

    static func forwardTurnLogged(on date: Date = Date(), in logs: [ForwardTurnLog]) -> Bool {
        let key = dateKey(date)
        return logs.contains { $0.date == key }
    }

    static func forwardStatus(settings: Settings, logs: [ForwardTurnLog], date: Date = Date()) -> String {
        if forwardTurnLogged(on: date, in: logs) { return "Completed" }
        return isForwardTurnDue(settings: settings, date: date) ? "Due" : "Not scheduled"
    }

    static func stretchingStatus(_ label: StretchSessionLabel, logs: [StretchingSessionLog], date: Date = Date()) -> String {
        let key = dateKey(date)
        let latest = logs
            .filter { $0.date == key && $0.sessionLabel == label }
            .sorted { $0.startedAt > $1.startedAt }
            .first

        guard let latest else { return "Not started" }
        return latest.status == .completed ? "Completed" : "In progress"
    }

    static func completedStretchCount(logs: [StretchingSessionLog], date: Date = Date()) -> Int {
        let key = dateKey(date)
        return logs.filter { $0.date == key && $0.status == .completed }.count
    }
}
