import SwiftUI

struct ContentView: View {
    enum Route: Hashable {
        case stretch
        case forward
        case log
        case settings
    }

    @EnvironmentObject private var store: ExpanderStore
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .stretch:
                        StretchingSessionView()
                    case .forward:
                        ForwardTurnView()
                    case .log:
                        LogView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .tint(.trackerGreen)
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: ExpanderStore
    @Binding var path: [ContentView.Route]

    private var today: Date { Date() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(ProtocolLogic.dateKey(today))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("Expander Tracker")
                    .font(.largeTitle.weight(.bold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current nut position")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(store.settings.currentNutPosition.rawValue)
                        .font(.system(size: 86, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text(nextAction)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.trackerGreen)
                }
                .panelStyle()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatusTile(title: "Forward turn", value: forwardStatus, urgent: forwardStatus == "Due")
                    StatusTile(title: "Morning", value: morningStatus, urgent: morningStatus != "Completed")
                    StatusTile(title: "Evening", value: eveningStatus, urgent: eveningStatus != "Completed")
                    StatusTile(
                        title: "Stretching done",
                        value: "\(ProtocolLogic.completedStretchCount(logs: store.stretchingLogs, date: today))/\(store.settings.stretchingSessionsPerDay)",
                        urgent: ProtocolLogic.completedStretchCount(logs: store.stretchingLogs, date: today) < store.settings.stretchingSessionsPerDay
                    )
                }

                PrimaryActionButton("Start Stretching Session") { path.append(.stretch) }
                PrimaryActionButton("Log Forward Turn") { path.append(.forward) }
                SecondaryActionButton("View Calendar / Log") { path.append(.log) }
                SecondaryActionButton("Settings") { path.append(.settings) }
            }
            .padding(20)
        }
        .background(Color.trackerBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var forwardStatus: String {
        ProtocolLogic.forwardStatus(settings: store.settings, logs: store.forwardLogs, date: today)
    }

    private var morningStatus: String {
        ProtocolLogic.stretchingStatus(.morning, logs: store.stretchingLogs, date: today)
    }

    private var eveningStatus: String {
        ProtocolLogic.stretchingStatus(.evening, logs: store.stretchingLogs, date: today)
    }

    private var nextAction: String {
        if morningStatus != "Completed" { return "Next: morning stretching" }
        if forwardStatus == "Due" { return "Next: forward turn due" }
        if eveningStatus != "Completed" { return "Next: evening stretching" }
        return "Today is complete for your configured protocol"
    }
}

struct StretchingSessionView: View {
    @EnvironmentObject private var store: ExpanderStore
    @Environment(\.dismiss) private var dismiss

    @State private var label: StretchSessionLabel = .morning
    @State private var turns = 3
    @State private var timerMinutes = 15
    @State private var startedAt: Date?
    @State private var remainingSeconds = 15 * 60
    @State private var confirmReverseTurns = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Stretching Session")
                    .font(.largeTitle.weight(.bold))

                Picker("Session", selection: $label) {
                    ForEach(StretchSessionLabel.allCases) { label in
                        Text(label.title).tag(label)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Stretching turns", selection: $turns) {
                    ForEach(store.settings.allowedStretchTurnCounts, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Timer", selection: $timerMinutes) {
                    ForEach([15, 30, 45, 60], id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 12) {
                    StepRow(number: 1, text: "Turn forward \(turns) times.")
                    StepRow(number: 2, text: "Start the timer.")
                    StepRow(number: 3, text: "Turn back \(turns) times.")
                    StepRow(number: 4, text: "Confirm and mark complete.")
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Timer")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text("Stretching does not change permanent nut position.")
                        .font(.body.weight(.semibold))
                }
                .panelStyle()

                PrimaryActionButton(startedAt == nil ? "Start Timer" : "Timer Running") {
                    startedAt = Date()
                    remainingSeconds = timerMinutes * 60
                }
                .disabled(startedAt != nil)

                PrimaryActionButton("Mark Complete") {
                    if startedAt == nil {
                        startedAt = Date()
                    }
                    confirmReverseTurns = true
                }

                SecondaryActionButton("Save Incomplete") {
                    let start = startedAt ?? Date()
                    store.logIncompleteStretchingSession(label: label, turns: turns, timerMinutes: timerMinutes, startedAt: start)
                    dismiss()
                }
            }
            .padding(20)
        }
        .background(Color.trackerBackground)
        .navigationTitle("Stretching")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            turns = store.settings.defaultStretchingTurns
            timerMinutes = store.settings.defaultTimerDurationMinutes
            remainingSeconds = timerMinutes * 60
            label = ProtocolLogic.stretchingStatus(.morning, logs: store.stretchingLogs) == "Completed" ? .evening : .morning
        }
        .onChange(of: timerMinutes) { newValue in
            if startedAt == nil {
                remainingSeconds = newValue * 60
            }
        }
        .onReceive(timer) { _ in
            guard startedAt != nil, remainingSeconds > 0 else { return }
            remainingSeconds -= 1
        }
        .confirmationDialog("Did you turn back the same number of turns?", isPresented: $confirmReverseTurns, titleVisibility: .visible) {
            Button("Yes, complete") {
                let start = startedAt ?? Date()
                store.logStretchingSession(label: label, turns: turns, timerMinutes: timerMinutes, startedAt: start, completedAt: Date())
                dismiss()
            }
            Button("No", role: .cancel) {}
        }
    }
}

struct ForwardTurnView: View {
    @EnvironmentObject private var store: ExpanderStore
    @Environment(\.dismiss) private var dismiss

    @State private var confirm = false
    @State private var overrideConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Forward Turn")
                    .font(.largeTitle.weight(.bold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Before")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(store.settings.currentNutPosition.rawValue)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                    Text("After one forward turn")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(store.settings.currentNutPosition.next().rawValue)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                }
                .panelStyle()

                WarningBox(text: warningText)

                PrimaryActionButton("Confirm One Forward Turn") {
                    if alreadyDone {
                        overrideConfirm = true
                    } else {
                        confirm = true
                    }
                }
            }
            .padding(20)
        }
        .background(Color.trackerBackground)
        .navigationTitle("Forward Turn")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Confirm one forward turn?", isPresented: $confirm, titleVisibility: .visible) {
            Button("I completed it") {
                store.logForwardTurn()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(store.settings.currentNutPosition.rawValue) to \(store.settings.currentNutPosition.next().rawValue)")
        }
        .confirmationDialog("Forward turn already logged today", isPresented: $overrideConfirm, titleVisibility: .visible) {
            Button("Override and log", role: .destructive) {
                store.logForwardTurn(overrideReason: "Manual override after same-day warning")
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A second forward turn can be logged only as a manual override.")
        }
    }

    private var alreadyDone: Bool {
        ProtocolLogic.forwardTurnLogged(in: store.forwardLogs)
    }

    private var due: Bool {
        ProtocolLogic.isForwardTurnDue(settings: store.settings)
    }

    private var warningText: String {
        if alreadyDone { return "A forward turn was already logged today. Override requires confirmation." }
        if due { return "Forward turn is due today in your configured protocol." }
        return "Forward turn is not scheduled today. You can still log it manually."
    }
}

struct LogView: View {
    @EnvironmentObject private var store: ExpanderStore
    @State private var deleteStretch: StretchingSessionLog?
    @State private var deleteForward: ForwardTurnLog?

    private var days: [String] {
        Array(Array(Set(store.stretchingLogs.map(\.date) + store.forwardLogs.map(\.date) + [ProtocolLogic.dateKey()])).sorted().reversed())
    }

    var body: some View {
        List {
            Section("Daily status") {
                ForEach(days, id: \.self) { day in
                    let date = dateFromKey(day)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(day).font(.headline)
                        Text("Stretching completed: \(ProtocolLogic.completedStretchCount(logs: store.stretchingLogs, date: date))")
                        Text("Forward: \(ProtocolLogic.forwardStatus(settings: store.settings, logs: store.forwardLogs, date: date))")
                        Text("Current position: \(endingPosition(for: day).rawValue)")
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Stretching history") {
                if store.stretchingLogs.isEmpty {
                    Text("No stretching logs yet.")
                }
                ForEach(store.stretchingLogs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(log.sessionLabel.title) stretching").font(.headline)
                        Text("\(log.date) at \(ProtocolLogic.timeLabel(log.startedAt))")
                        Text("\(log.stretchTurnCount) turns, \(log.timerDurationMinutes) min, \(log.status.rawValue)")
                        HStack {
                            Button("Mark incomplete") {
                                store.markStretchingIncomplete(log)
                            }
                            Button("Delete", role: .destructive) {
                                deleteStretch = log
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Forward turn history") {
                if store.forwardLogs.isEmpty {
                    Text("No forward turns yet.")
                }
                ForEach(store.forwardLogs) { log in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Forward turn").font(.headline)
                        Text("\(log.date) at \(ProtocolLogic.timeLabel(log.completedAt))")
                        Text("\(log.beforePosition.rawValue) to \(log.afterPosition.rawValue)")
                        if !log.overrideReason.isEmpty {
                            Text("Override: \(log.overrideReason)")
                                .foregroundStyle(.orange)
                        }
                        Button("Delete", role: .destructive) {
                            deleteForward = log
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Calendar / Log")
        .confirmationDialog("Delete stretching log?", isPresented: deleteStretchBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleteStretch {
                    store.deleteStretchingLog(deleteStretch)
                }
                deleteStretch = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected entry.")
        }
        .confirmationDialog("Delete forward turn log?", isPresented: deleteForwardBinding, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let deleteForward {
                    store.deleteForwardLog(deleteForward)
                }
                deleteForward = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the log entry only. Set the current nut position manually in Settings if needed.")
        }
    }

    private var deleteStretchBinding: Binding<Bool> {
        Binding(get: { deleteStretch != nil }, set: { shown in
            if !shown { deleteStretch = nil }
        })
    }

    private var deleteForwardBinding: Binding<Bool> {
        Binding(get: { deleteForward != nil }, set: { shown in
            if !shown { deleteForward = nil }
        })
    }

    private func dateFromKey(_ key: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key) ?? Date()
    }

    private func endingPosition(for day: String) -> NutPosition {
        store.forwardLogs.first { $0.date == day }?.afterPosition ?? store.settings.currentNutPosition
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ExpanderStore
    @State private var customDateText = ""
    @State private var scanOpen = false
    @State private var exportOpen = false
    @State private var exportFormat = "JSON"

    var body: some View {
        Form {
            Section("Current nut position") {
                Picker("Manual correction", selection: positionBinding) {
                    ForEach(NutPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.segmented)

                Button("Scan nut position") {
                    scanOpen = true
                }
            }

            Section("Stretching protocol") {
                Stepper("Sessions per day: \(store.settings.stretchingSessionsPerDay)", value: sessionsBinding, in: 1...3)
                Picker("Default stretching turns", selection: defaultTurnsBinding) {
                    ForEach([3, 4, 5], id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                Picker("Default timer", selection: defaultTimerBinding) {
                    ForEach([15, 30, 45, 60], id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
            }

            Section("Forward turn schedule") {
                Picker("Schedule", selection: scheduleModeBinding) {
                    ForEach(ForwardScheduleMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                WeekdaySelector()

                TextField("Custom dates: YYYY-MM-DD, YYYY-MM-DD", text: $customDateText)
                    .textInputAutocapitalization(.never)
                Button("Save custom dates") {
                    let dates = customDateText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    store.updateSettings { $0.forwardTurnSchedule.customDates = Set(dates) }
                }
            }

            Section("Optional reminder times") {
                TextField("Morning stretching, e.g. 8:00 AM", text: reminderBinding(\.morningStretching))
                TextField("Evening stretching, e.g. 8:00 PM", text: reminderBinding(\.eveningStretching))
                TextField("Forward turn, e.g. 7:30 AM", text: reminderBinding(\.forwardTurn))
                Text("Reminder notifications are not enabled in this version. These times are saved as reference.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Export") {
                Picker("Format", selection: $exportFormat) {
                    Text("JSON").tag("JSON")
                    Text("CSV").tag("CSV")
                }
                .pickerStyle(.segmented)
                Button("Show export data") {
                    exportOpen = true
                }
            }

            Section {
                Text("This app is only a personal tracking tool and does not provide medical advice. Follow the protocol from your orthodontic provider.")
                    .font(.footnote.weight(.semibold))
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            customDateText = store.settings.forwardTurnSchedule.customDates.sorted().joined(separator: ", ")
        }
        .sheet(isPresented: $scanOpen) {
            ScanPlaceholderView()
        }
        .sheet(isPresented: $exportOpen) {
            ExportView(format: exportFormat)
        }
    }

    private var positionBinding: Binding<NutPosition> {
        Binding(get: { store.settings.currentNutPosition }, set: { value in
            store.updateSettings { $0.currentNutPosition = value }
        })
    }

    private var sessionsBinding: Binding<Int> {
        Binding(get: { store.settings.stretchingSessionsPerDay }, set: { value in
            store.updateSettings { $0.stretchingSessionsPerDay = value }
        })
    }

    private var defaultTurnsBinding: Binding<Int> {
        Binding(get: { store.settings.defaultStretchingTurns }, set: { value in
            store.updateSettings { $0.defaultStretchingTurns = value }
        })
    }

    private var defaultTimerBinding: Binding<Int> {
        Binding(get: { store.settings.defaultTimerDurationMinutes }, set: { value in
            store.updateSettings { $0.defaultTimerDurationMinutes = value }
        })
    }

    private var scheduleModeBinding: Binding<ForwardScheduleMode> {
        Binding(get: { store.settings.forwardTurnSchedule.mode }, set: { value in
            store.updateSettings { $0.forwardTurnSchedule.mode = value }
        })
    }

    private func reminderBinding(_ keyPath: WritableKeyPath<ReminderSettings, String>) -> Binding<String> {
        Binding(get: { store.settings.reminders[keyPath: keyPath] }, set: { value in
            store.updateSettings { $0.reminders[keyPath: keyPath] = value }
        })
    }
}

struct WeekdaySelector: View {
    @EnvironmentObject private var store: ExpanderStore

    private let weekdays = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    var body: some View {
        HStack {
            ForEach(weekdays, id: \.0) { day, label in
                Button {
                    store.updateSettings { settings in
                        if settings.forwardTurnSchedule.weekdays.contains(day) {
                            settings.forwardTurnSchedule.weekdays.remove(day)
                        } else {
                            settings.forwardTurnSchedule.weekdays.insert(day)
                        }
                    }
                } label: {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(store.settings.forwardTurnSchedule.weekdays.contains(day) ? Color.trackerSoftGreen : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.trackerBorder))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ScanPlaceholderView: View {
    @EnvironmentObject private var store: ExpanderStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected: NutPosition = .a

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Camera capture is a placeholder in this version. Manually confirm the visible letter.")
                    .font(.body.weight(.semibold))
                    .padding()
                    .background(Color.trackerWarning)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.trackerSoftGreen)
                    Text("Camera preview placeholder")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 260)

                Picker("Confirmed position", selection: $selected) {
                    ForEach(NutPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(.segmented)

                PrimaryActionButton("Use Confirmed Position") {
                    store.updateSettings { $0.currentNutPosition = selected }
                    dismiss()
                }

                Spacer()
            }
            .padding(20)
            .background(Color.trackerBackground)
            .navigationTitle("Scan nut position")
            .onAppear { selected = store.settings.currentNutPosition }
        }
    }
}

struct ExportView: View {
    @EnvironmentObject private var store: ExpanderStore
    @Environment(\.dismiss) private var dismiss
    let format: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select this text to copy it from your iPhone.")
                        .font(.body)
                    Text(format == "CSV" ? store.exportCSV() : store.exportJSON())
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
            }
            .background(Color.trackerBackground)
            .navigationTitle("Export \(format)")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

struct StatusTile: View {
    let title: String
    let value: String
    var urgent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(14)
        .background(urgent ? Color.trackerWarning : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(urgent ? Color.trackerOrange : Color.trackerBorder))
    }
}

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.trackerGreen)
                .clipShape(Circle())
            Text(text)
                .font(.title3.weight(.semibold))
        }
    }
}

struct WarningBox: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.trackerWarning)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.trackerOrange))
    }
}

struct PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(.trackerGreen)
        .controlSize(.large)
    }
}

struct SecondaryActionButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
        .tint(.trackerGreen)
        .controlSize(.large)
    }
}

extension View {
    func panelStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.trackerBorder))
    }
}

extension Color {
    static let trackerBackground = Color(red: 0.968, green: 0.970, blue: 0.952)
    static let trackerGreen = Color(red: 0.084, green: 0.278, blue: 0.239)
    static let trackerSoftGreen = Color(red: 0.863, green: 0.922, blue: 0.902)
    static let trackerBorder = Color(red: 0.729, green: 0.770, blue: 0.748)
    static let trackerWarning = Color(red: 1.000, green: 0.972, blue: 0.914)
    static let trackerOrange = Color(red: 0.704, green: 0.389, blue: 0.086)
}

private func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let seconds = seconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
