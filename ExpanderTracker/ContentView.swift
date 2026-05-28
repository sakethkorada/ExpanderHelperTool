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
        .tint(.trackerInk)
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
                    Text("Current bolt position")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(currentPosition.label)
                        .font(.system(size: 86, weight: .black, design: .default))
                        .monospacedDigit()
                    Text("Position \(currentPosition.index + 1) of \(store.settings.boltPositionCount)")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(nextAction)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.trackerInk)
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

                if ProtocolLogic.completedStretchCount(logs: store.stretchingLogs, date: today) >= store.settings.stretchingSessionsPerDay {
                    SecondaryActionButton("Start Extra Stretching Session") { path.append(.stretch) }
                } else {
                    PrimaryActionButton("Start Stretching Session") { path.append(.stretch) }
                }
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

    private var currentPosition: BoltPositionSnapshot {
        let settings = store.settings.normalized
        return BoltPositionSnapshot(
            index: settings.currentBoltIndex,
            label: BoltMath.getDisplayLabel(index: settings.currentBoltIndex, labels: settings.boltLabels)
        )
    }

    private var morningStatus: String {
        ProtocolLogic.stretchingStatus(.morning, logs: store.stretchingLogs, date: today)
    }

    private var eveningStatus: String {
        ProtocolLogic.stretchingStatus(.evening, logs: store.stretchingLogs, date: today)
    }

    private var nextAction: String {
        if morningStatus != "Completed" { return "Next: morning stretching" }
        if forwardStatus.hasPrefix("Due") { return "Next: forward turn due" }
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Mirror check")
                        .font(.headline)
                    PositionLine(title: "Start position", position: startPosition)
                    PositionLine(title: "Move forward \(turns) turns to", position: temporaryTarget)
                    PositionLine(title: "Move back \(turns) turns to", position: returnTarget)
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 12) {
                    StepRow(number: 1, text: "Turn forward \(turns) times to \(temporaryTarget.label).")
                    StepRow(number: 2, text: "Start the timer.")
                    StepRow(number: 3, text: "Turn back \(turns) times to \(returnTarget.label).")
                    StepRow(number: 4, text: "Confirm you returned to the start position.")
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Timer")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(formatTime(remainingSeconds))
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .monospacedDigit()
                    Text("Stretching does not change permanent bolt position.")
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
        .confirmationDialog("Did you return to \(returnTarget.label)?", isPresented: $confirmReverseTurns, titleVisibility: .visible) {
            Button("Yes, complete") {
                let start = startedAt ?? Date()
                store.logStretchingSession(label: label, turns: turns, timerMinutes: timerMinutes, startedAt: start, completedAt: Date())
                dismiss()
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("Expected final position: \(returnTarget.displayText)")
        }
    }

    private var startPosition: BoltPositionSnapshot {
        let settings = store.settings.normalized
        return BoltPositionSnapshot(
            index: settings.currentBoltIndex,
            label: BoltMath.getDisplayLabel(index: settings.currentBoltIndex, labels: settings.boltLabels)
        )
    }

    private var temporaryTarget: BoltPositionSnapshot {
        let settings = store.settings.normalized
        let index = BoltMath.calculateStretchForwardTarget(
            startIndex: settings.currentBoltIndex,
            stretchTurnCount: turns,
            totalPositions: settings.boltPositionCount
        )
        return BoltPositionSnapshot(index: index, label: BoltMath.getDisplayLabel(index: index, labels: settings.boltLabels))
    }

    private var returnTarget: BoltPositionSnapshot {
        let settings = store.settings.normalized
        let index = BoltMath.calculateStretchReturnTarget(
            forwardTargetIndex: temporaryTarget.index,
            stretchTurnCount: turns,
            totalPositions: settings.boltPositionCount
        )
        return BoltPositionSnapshot(index: index, label: BoltMath.getDisplayLabel(index: index, labels: settings.boltLabels))
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
                    Text("Current position")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(startPosition.label)
                        .font(.system(size: 72, weight: .black, design: .default))
                    Text(startPosition.displayText)
                        .foregroundStyle(.secondary)
                    Text("After \(turnCount) forward \(turnCount == 1 ? "turn" : "turns")")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(finalPosition.label)
                        .font(.system(size: 72, weight: .black, design: .default))
                    Text(finalPosition.displayText)
                        .foregroundStyle(.secondary)
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Path")
                        .font(.headline)
                    Text(pathText)
                        .font(.title3.weight(.semibold))
                        .lineLimit(nil)
                }
                .panelStyle()

                WarningBox(text: warningText)

                PrimaryActionButton("Confirm Forward Session") {
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
        .confirmationDialog("Confirm forward session?", isPresented: $confirm, titleVisibility: .visible) {
            Button("I completed it") {
                store.logForwardTurn(turns: turnCount, wasScheduled: due)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(pathText)
        }
        .confirmationDialog("Forward turn already logged today", isPresented: $overrideConfirm, titleVisibility: .visible) {
            Button("Override and log", role: .destructive) {
                store.logForwardTurn(turns: turnCount, wasScheduled: false, overrideReason: "Manual override after same-day warning")
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
        ProtocolLogic.isForwardTurnDue(settings: store.settings, forwardLogs: store.forwardLogs)
    }

    private var warningText: String {
        if alreadyDone { return "A forward turn was already logged today. Override requires confirmation." }
        if due { return "Forward turn is due today in your configured protocol." }
        return "Forward turn is not scheduled today. You can still log it manually."
    }

    private var turnCount: Int {
        store.settings.normalized.forwardTurnsPerSession
    }

    private var path: [BoltPositionSnapshot] {
        let settings = store.settings.normalized
        return BoltMath.forwardPath(startIndex: settings.currentBoltIndex, turnCount: turnCount, labels: settings.boltLabels)
    }

    private var startPosition: BoltPositionSnapshot {
        path.first ?? BoltPositionSnapshot(index: 0, label: "")
    }

    private var finalPosition: BoltPositionSnapshot {
        path.last ?? startPosition
    }

    private var pathText: String {
        path.map(\.label).joined(separator: " -> ")
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
                        if let forwardSummary = forwardSummary(for: day) {
                            Text("Bolt: \(forwardSummary.startPositionLabel) to \(forwardSummary.endPositionLabel)")
                        } else {
                            Text("Bolt: \(currentPosition.displayText)")
                        }
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
                        Text("Start \(log.startPositionLabel) -> target \(log.temporaryTargetLabel) -> return \(log.returnTargetLabel)")
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
                        Text("\(log.numberOfTurns) turns: \(log.startPositionLabel) to \(log.endPositionLabel)")
                        Text(log.wasScheduled ? "Scheduled" : "Manual override")
                            .foregroundStyle(.secondary)
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
            Text("This removes the log entry only. Set the current bolt position manually in Settings if needed.")
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

    private func forwardSummary(for day: String) -> ForwardTurnLog? {
        store.forwardLogs.first { $0.date == day }
    }

    private var currentPosition: BoltPositionSnapshot {
        let settings = store.settings.normalized
        return BoltPositionSnapshot(
            index: settings.currentBoltIndex,
            label: BoltMath.getDisplayLabel(index: settings.currentBoltIndex, labels: settings.boltLabels)
        )
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ExpanderStore
    @State private var scanOpen = false
    @State private var exportOpen = false
    @State private var exportFormat = "JSON"
    @State private var pendingBoltCount = 6
    @State private var confirmBoltCountChange = false

    var body: some View {
        Form {
            Section("Bolt positions") {
                Stepper("Number of positions: \(pendingBoltCount)", value: $pendingBoltCount, in: 2...12)
                Button("Apply position count") {
                    confirmBoltCountChange = true
                }
                ForEach(0..<store.settings.normalized.boltPositionCount, id: \.self) { index in
                    TextField("Position \(index + 1)", text: labelBinding(index))
                        .textInputAutocapitalization(.characters)
                }
            }

            Section("Current bolt position") {
                Picker("Manual correction", selection: currentBoltIndexBinding) {
                    ForEach(0..<store.settings.normalized.boltPositionCount, id: \.self) { index in
                        Text("Position \(index + 1): \(BoltMath.getDisplayLabel(index: index, labels: store.settings.boltLabels))").tag(index)
                    }
                }

                Button("Scan bolt position") {
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
                Stepper("Turns per forward session: \(store.settings.forwardTurnsPerSession)", value: forwardTurnsPerSessionBinding, in: 1...12)
                Picker("Schedule", selection: scheduleModeBinding) {
                    ForEach(ForwardScheduleMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                WeekdaySelector()

                Stepper("Weekly target: \(store.settings.forwardTurnSchedule.weeklyTargetCount)", value: weeklyTargetBinding, in: 1...7)
                Text("Weekdays are used for the specific-weekdays mode. Weekly target is used for the times-per-week mode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            pendingBoltCount = store.settings.normalized.boltPositionCount
        }
        .confirmationDialog("Change number of bolt positions?", isPresented: $confirmBoltCountChange, titleVisibility: .visible) {
            Button("Apply change") {
                store.updateSettings { settings in
                    settings.boltPositionCount = max(2, pendingBoltCount)
                }
            }
            Button("Cancel", role: .cancel) {
                pendingBoltCount = store.settings.normalized.boltPositionCount
            }
        } message: {
            Text("This may add placeholder labels, remove extra labels, or move the current saved position into the new range.")
        }
        .sheet(isPresented: $scanOpen) {
            ScanPlaceholderView()
        }
        .sheet(isPresented: $exportOpen) {
            ExportView(format: exportFormat)
        }
    }

    private var currentBoltIndexBinding: Binding<Int> {
        Binding(get: { store.settings.normalized.currentBoltIndex }, set: { value in
            store.updateSettings { $0.currentBoltIndex = value }
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

    private var forwardTurnsPerSessionBinding: Binding<Int> {
        Binding(get: { store.settings.forwardTurnsPerSession }, set: { value in
            store.updateSettings { $0.forwardTurnsPerSession = value }
        })
    }

    private var weeklyTargetBinding: Binding<Int> {
        Binding(get: { store.settings.forwardTurnSchedule.weeklyTargetCount }, set: { value in
            store.updateSettings { $0.forwardTurnSchedule.weeklyTargetCount = value }
        })
    }

    private func labelBinding(_ index: Int) -> Binding<String> {
        Binding(get: {
            BoltMath.getDisplayLabel(index: index, labels: store.settings.normalized.boltLabels)
        }, set: { value in
            store.updateSettings { settings in
                var labels = settings.normalized.boltLabels
                if labels.indices.contains(index) {
                    labels[index] = value
                }
                settings.boltLabels = labels
            }
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
                        .background(store.settings.forwardTurnSchedule.weekdays.contains(day) ? Color.trackerSelected : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.trackerBorder))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ScanPlaceholderView: View {
    @EnvironmentObject private var store: ExpanderStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Camera capture is a placeholder in this version. Manually confirm the visible letter.")
                    .font(.body.weight(.semibold))
                    .padding()
                    .background(Color.trackerWarning)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.trackerCard)
                    Text("Camera preview placeholder")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 260)

                Picker("Confirmed position", selection: $selectedIndex) {
                    ForEach(0..<store.settings.normalized.boltPositionCount, id: \.self) { index in
                        Text(BoltMath.getDisplayLabel(index: index, labels: store.settings.boltLabels)).tag(index)
                    }
                }
                .pickerStyle(.segmented)

                PrimaryActionButton("Use Confirmed Position") {
                    store.updateSettings { $0.currentBoltIndex = selectedIndex }
                    dismiss()
                }

                Spacer()
            }
            .padding(20)
            .background(Color.trackerBackground)
            .navigationTitle("Scan bolt position")
            .onAppear { selectedIndex = store.settings.normalized.currentBoltIndex }
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

struct PositionLine: View {
    let title: String
    let position: BoltPositionSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(position.displayText)
                    .font(.headline.weight(.bold))
            }
            Spacer()
            Text(position.label)
                .font(.title2.weight(.black))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
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
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(12)
        .background(Color.trackerCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(urgent ? Color.trackerInk : Color.trackerBorder, lineWidth: urgent ? 1.5 : 1))
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
                .background(Color.trackerInk)
                .clipShape(RoundedRectangle(cornerRadius: 4))
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
            .background(Color.trackerSelected)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.trackerBorder))
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
        .tint(.trackerInk)
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
        .tint(.trackerInk)
        .controlSize(.large)
    }
}

extension View {
    func panelStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.trackerCard)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.trackerBorder))
    }
}

extension Color {
    static let trackerBackground = Color(red: 0.980, green: 0.980, blue: 0.980)
    static let trackerCard = Color.white
    static let trackerInk = Color(red: 0.067, green: 0.067, blue: 0.067)
    static let trackerSelected = Color(red: 0.918, green: 0.918, blue: 0.918)
    static let trackerBorder = Color(red: 0.847, green: 0.847, blue: 0.847)
    static let trackerWarning = Color(red: 0.940, green: 0.940, blue: 0.940)
    static let trackerOrange = Color(red: 0.350, green: 0.350, blue: 0.350)
}

private func formatTime(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let seconds = seconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}
