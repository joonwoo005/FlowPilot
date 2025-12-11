import SwiftUI

// MARK: - Text Detection Result
struct DetectedComponents {
    var dateText: String?
    var dateValue: Date?
    var timeText: String?
    var timeValue: DateComponents?
    var priorityText: String?
    var priorityValue: Priority?
    var timeBlockText: String?
    var timeBlockDuration: Int? // minutes

    // Store positions as integers for reliable cross-string usage
    var allDetectedRanges: [(startOffset: Int, endOffset: Int, type: DetectionType)] = []

    enum DetectionType {
        case date, time, priority, timeBlock

        var color: Color {
            switch self {
            case .date: return .dueDateToday
            case .time: return .accentWarm
            case .priority: return .priorityPurple
            case .timeBlock: return Color(red: 0.6, green: 0.25, blue: 0.25)
            }
        }
    }
}

// MARK: - Smart Text Parser
class SmartTextParser {
    // Candidate match with position for sorting
    struct Candidate {
        let startOffset: Int
        let endOffset: Int
        let text: String
        let value: Any
    }

    static func parse(_ text: String, priorities: [Priority] = []) -> DetectedComponents {
        var result = DetectedComponents()
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today)

        // Day name mappings
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let shortDayNames = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let fullMonthNames = ["january", "february", "march", "april", "may", "june",
                              "july", "august", "september", "october", "november", "december"]

        // Helper to get integer offsets from range
        func offsets(of range: Range<String.Index>) -> (start: Int, end: Int) {
            let start = lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
            let end = lowercased.distance(from: lowercased.startIndex, to: range.upperBound)
            return (start, end)
        }

        // Helper to extract day number from ordinal or plain number
        func extractDay(from str: String) -> Int? {
            let cleaned = str.replacingOccurrences(of: "st|nd|rd|th", with: "", options: .regularExpression)
            return Int(cleaned)
        }

        // MARK: - Collect ALL Date Candidates
        var dateCandidates: [Candidate] = []

        // "today"
        if let range = lowercased.range(of: "today") {
            let pos = offsets(of: range)
            dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: "Today", value: today))
        }

        // "tomorrow"
        if let range = lowercased.range(of: "tomorrow") {
            if let date = calendar.date(byAdding: .day, value: 1, to: today) {
                let pos = offsets(of: range)
                dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: "Tomorrow", value: date))
            }
        }

        // "tmr"
        if let range = lowercased.range(of: " tmr") ?? lowercased.range(of: "^tmr", options: .regularExpression) {
            if let date = calendar.date(byAdding: .day, value: 1, to: today) {
                let pos = offsets(of: range)
                dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: "Tomorrow", value: date))
            }
        }

        // "next week"
        if let range = lowercased.range(of: "next week") {
            if let date = calendar.date(byAdding: .day, value: 7, to: today) {
                let pos = offsets(of: range)
                dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: "Next Week", value: date))
            }
        }

        // "next [day]" patterns
        for (index, dayName) in dayNames.enumerated() {
            if let range = lowercased.range(of: "next \(dayName)") {
                let targetWeekday = index + 1
                var daysToAdd = targetWeekday - todayWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }
                daysToAdd += 7

                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"
                if let date = calendar.date(byAdding: .day, value: daysToAdd, to: today) {
                    let pos = offsets(of: range)
                    dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: formatter.string(from: date), value: date))
                }
            }
        }

        // "on [day]" patterns
        for (index, dayName) in dayNames.enumerated() {
            if let range = lowercased.range(of: "on \(dayName)") ?? lowercased.range(of: "on \(shortDayNames[index])") {
                let targetWeekday = index + 1
                var daysToAdd = targetWeekday - todayWeekday
                if daysToAdd <= 0 { daysToAdd += 7 }

                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"
                if let date = calendar.date(byAdding: .day, value: daysToAdd, to: today) {
                    let pos = offsets(of: range)
                    dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: formatter.string(from: date), value: date))
                }
            }
        }

        // Standalone day names
        for (index, dayName) in dayNames.enumerated() {
            let patterns = [" \(dayName) ", " \(dayName)$", "^\(dayName) ", " \(shortDayNames[index]) ", " \(shortDayNames[index])$"]
            for pattern in patterns {
                if let range = lowercased.range(of: pattern, options: .regularExpression) {
                    let targetWeekday = index + 1
                    var daysToAdd = targetWeekday - todayWeekday
                    if daysToAdd <= 0 { daysToAdd += 7 }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEE, MMM d"
                    if let date = calendar.date(byAdding: .day, value: daysToAdd, to: today) {
                        let pos = offsets(of: range)
                        dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: formatter.string(from: date), value: date))
                    }
                }
            }
        }

        // "[month] [day]" e.g., "Dec 4", "Dec 4th", "December 1st"
        if let regex = try? NSRegularExpression(pattern: "(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\\s+(\\d{1,2})(?:st|nd|rd|th)?", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
           let monthRange = Range(match.range(at: 1), in: lowercased),
           let dayRange = Range(match.range(at: 2), in: lowercased),
           let fullRange = Range(match.range, in: lowercased) {
            let monthStr = String(lowercased[monthRange]).lowercased()
            let dayStr = String(lowercased[dayRange])
            // Check full month name first, then short form
            let monthIndex = fullMonthNames.firstIndex(of: monthStr) ?? monthNames.firstIndex(of: String(monthStr.prefix(3)))
            if let monthIndex = monthIndex,
               let day = extractDay(from: dayStr) {
                var components = DateComponents()
                components.month = monthIndex + 1
                components.day = day
                components.year = calendar.component(.year, from: today)
                // If date is in the past, roll forward to next year
                if let tempDate = calendar.date(from: components), tempDate < today {
                    components.year! += 1
                }
                if let date = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    let pos = offsets(of: fullRange)
                    dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: formatter.string(from: date), value: date))
                }
            }
        }

        // "[day] [month]" e.g., "4 Dec", "4th Dec", "1st December"
        if let regex = try? NSRegularExpression(pattern: "(\\d{1,2})(?:st|nd|rd|th)?\\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
           let dayRange = Range(match.range(at: 1), in: lowercased),
           let monthRange = Range(match.range(at: 2), in: lowercased),
           let fullRange = Range(match.range, in: lowercased) {
            let dayStr = String(lowercased[dayRange])
            let monthStr = String(lowercased[monthRange]).lowercased()
            // Check full month name first, then short form
            let monthIndex = fullMonthNames.firstIndex(of: monthStr) ?? monthNames.firstIndex(of: String(monthStr.prefix(3)))
            if let monthIndex = monthIndex,
               let day = extractDay(from: dayStr) {
                var components = DateComponents()
                components.month = monthIndex + 1
                components.day = day
                components.year = calendar.component(.year, from: today)
                // If date is in the past, roll forward to next year
                if let tempDate = calendar.date(from: components), tempDate < today {
                    components.year! += 1
                }
                if let date = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    let pos = offsets(of: fullRange)
                    dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: formatter.string(from: date), value: date))
                }
            }
        }

        // "on the [ordinal]" or "the [ordinal]"
        if let regex = try? NSRegularExpression(pattern: "(?:on\\s+)?the\\s+(\\d{1,2})(?:st|nd|rd|th)", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
           let dayRange = Range(match.range(at: 1), in: lowercased),
           let fullRange = Range(match.range, in: lowercased) {
            let dayStr = String(lowercased[dayRange])
            if let day = Int(dayStr), day >= 1, day <= 31 {
                let currentDay = calendar.component(.day, from: today)
                let currentMonth = calendar.component(.month, from: today)
                let currentYear = calendar.component(.year, from: today)

                var components = DateComponents()
                components.day = day
                components.year = currentYear
                components.month = day > currentDay ? currentMonth : (currentMonth == 12 ? 1 : currentMonth + 1)
                if day <= currentDay && currentMonth == 12 {
                    components.year = currentYear + 1
                }

                if let date = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    let pos = offsets(of: fullRange)
                    dateCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: formatter.string(from: date), value: date))
                }
            }
        }

        // Select earliest date candidate
        if let earliest = dateCandidates.min(by: { $0.startOffset < $1.startOffset }) {
            result.dateText = earliest.text
            result.dateValue = earliest.value as? Date
            result.allDetectedRanges.append((earliest.startOffset, earliest.endOffset, .date))
        }

        // MARK: - Collect ALL Time Candidates
        var timeCandidates: [Candidate] = []
        let timePatterns = [
            "at\\s+(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)",
            "(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)",
            "at\\s+(\\d{1,2}):(\\d{2})"
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
               let fullRange = Range(match.range, in: lowercased) {

                var hour = 0
                var minute = 0
                var isPM = false

                if let hourRange = Range(match.range(at: 1), in: lowercased) {
                    hour = Int(lowercased[hourRange]) ?? 0
                }
                if match.numberOfRanges > 2, let minRange = Range(match.range(at: 2), in: lowercased) {
                    minute = Int(lowercased[minRange]) ?? 0
                }
                if match.numberOfRanges > 3, let ampmRange = Range(match.range(at: 3), in: lowercased) {
                    isPM = lowercased[ampmRange].lowercased() == "pm"
                }

                if isPM && hour < 12 { hour += 12 }
                else if !isPM && hour == 12 { hour = 0 }

                let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
                let ampm = hour >= 12 ? "pm" : "am"
                let timeText = minute > 0 ? "\(displayHour):\(String(format: "%02d", minute))\(ampm)" : "\(displayHour)\(ampm)"

                let pos = offsets(of: fullRange)
                timeCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: timeText, value: DateComponents(hour: hour, minute: minute)))
            }
        }

        // Select earliest time candidate
        if let earliest = timeCandidates.min(by: { $0.startOffset < $1.startOffset }) {
            result.timeText = earliest.text
            result.timeValue = earliest.value as? DateComponents
            result.allDetectedRanges.append((earliest.startOffset, earliest.endOffset, .time))
        }

        // MARK: - Collect ALL Duration Candidates
        var durationCandidates: [Candidate] = []
        let durationPatterns: [(String, Bool)] = [
            ("for\\s+(\\d+)\\s*(hour|hr|h)s?", true),
            ("for\\s+(\\d+)\\s*(minute|min|m)s?", false),
            ("(\\d+)\\s*(hr|h)(?:our)?s?(?:\\s|$)", true),
            ("(\\d+)\\s*(min|m)(?:ute)?s?(?:\\s|$)", false)
        ]

        for (pattern, isHours) in durationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
               let fullRange = Range(match.range, in: lowercased),
               let valueRange = Range(match.range(at: 1), in: lowercased) {
                let value = Int(lowercased[valueRange]) ?? 0
                let minutes = isHours ? value * 60 : value
                let text = isHours ? (value == 1 ? "1 hour" : "\(value) hours") : "\(value) min"
                let pos = offsets(of: fullRange)
                durationCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: text, value: minutes))
            }
        }

        // Select earliest duration candidate
        if let earliest = durationCandidates.min(by: { $0.startOffset < $1.startOffset }) {
            result.timeBlockText = earliest.text
            result.timeBlockDuration = earliest.value as? Int
            result.allDetectedRanges.append((earliest.startOffset, earliest.endOffset, .timeBlock))
        }

        // MARK: - Collect ALL Priority Candidates
        var priorityCandidates: [Candidate] = []

        // Match against user's priority names (case-insensitive)
        for priority in priorities {
            let priorityNameLower = priority.name.lowercased()
            // Look for priority name with word boundaries
            let patterns = [
                " \(priorityNameLower) ",
                " \(priorityNameLower)$",
                "^\(priorityNameLower) ",
                "^\(priorityNameLower)$",
                "#\(priorityNameLower)"
            ]
            for pattern in patterns {
                if let range = lowercased.range(of: pattern, options: .regularExpression) {
                    let pos = offsets(of: range)
                    priorityCandidates.append(Candidate(startOffset: pos.start, endOffset: pos.end, text: priority.name, value: priority))
                    break
                }
            }
        }

        // Select earliest priority candidate
        if let earliest = priorityCandidates.min(by: { $0.startOffset < $1.startOffset }) {
            result.priorityText = earliest.text
            result.priorityValue = earliest.value as? Priority
            result.allDetectedRanges.append((earliest.startOffset, earliest.endOffset, .priority))
        }

        return result
    }

    static func cleanTaskName(_ text: String, detected: DetectedComponents) -> String {
        var cleaned = text

        // Sort ranges by start offset in reverse order to remove from end first
        let sortedRanges = detected.allDetectedRanges.sorted { $0.startOffset > $1.startOffset }

        for (startOffset, endOffset, _) in sortedRanges {
            // Convert offsets to indices
            guard let startIndex = text.index(text.startIndex, offsetBy: startOffset, limitedBy: text.endIndex),
                  let endIndex = text.index(text.startIndex, offsetBy: endOffset, limitedBy: text.endIndex),
                  startIndex < endIndex else {
                continue
            }
            cleaned.removeSubrange(startIndex..<endIndex)
        }

        // Clean up extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}

// MARK: - Add Task Sheet
struct AddTaskSheet: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    var lockedBlock: TimeBlock? = nil
    var editingTask: FlowTask? = nil
    var contextDate: Date? = nil  // The day section date (if adding from a specific day)
    @Environment(\.dismiss) private var dismiss

    private var isEditMode: Bool {
        editingTask != nil
    }

    @State private var taskName = ""
    @State private var detectedComponents = DetectedComponents()

    // Manual overrides
    @State private var manualDate: Date? = nil
    @State private var manualTime: DateComponents? = nil
    @State private var manualPriority: Priority? = nil
    @State private var selectedBlock: TimeBlock? = nil  // Selected time block

    // Computed property to check if values are locked from a block (either lockedBlock or selectedBlock)
    private var hasLockedBlock: Bool {
        lockedBlock != nil || selectedBlock != nil
    }

    // Check if block is user-selected (can be cleared) vs locked from context (cannot be cleared)
    private var isBlockUserSelected: Bool {
        selectedBlock != nil && lockedBlock == nil
    }

    private var activeBlock: TimeBlock? {
        lockedBlock ?? selectedBlock
    }

    private var lockedPriority: Priority? {
        guard let block = activeBlock else { return nil }
        return priorityStore.priorities.first { $0.id == block.priorityId }
    }

    // Sheet states
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showPriorityPicker = false
    @State private var showTimeBlockPicker = false
    @State private var showAddBlockSheet = false

    // Animation states for chip highlights
    @State private var dateJustDetected = false
    @State private var timeJustDetected = false
    @State private var priorityJustDetected = false
    @State private var timeBlockJustDetected = false

    // Validation
    @State private var showNoDescriptionError = false

    @FocusState private var isNameFocused: Bool

    // Computed property for cleaned task name
    private var cleanedTaskName: String {
        SmartTextParser.cleanTaskName(taskName, detected: detectedComponents)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Computed display values
    private var displayDate: (text: String?, value: Date?) {
        // Active block (locked or selected) takes priority
        if let block = activeBlock {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            let date = Calendar.current.startOfDay(for: block.startTime)
            return (formatter.string(from: date), date)
        }
        if let manual = manualDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return (formatter.string(from: manual), manual)
        }
        return (detectedComponents.dateText, detectedComponents.dateValue)
    }

    private var displayTime: (text: String?, value: DateComponents?) {
        // Active block (locked or selected) takes priority
        if let block = activeBlock {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: block.startTime)
            let minute = calendar.component(.minute, from: block.startTime)
            let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
            let ampm = hour >= 12 ? "pm" : "am"
            let text = minute > 0 ? "\(displayHour):\(String(format: "%02d", minute))\(ampm)" : "\(displayHour)\(ampm)"
            return (text, DateComponents(hour: hour, minute: minute))
        }
        if let manual = manualTime {
            let hour = manual.hour ?? 0
            let minute = manual.minute ?? 0
            let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
            let ampm = hour >= 12 ? "pm" : "am"
            let text = minute > 0 ? "\(displayHour):\(String(format: "%02d", minute))\(ampm)" : "\(displayHour)\(ampm)"
            return (text, manual)
        }
        return (detectedComponents.timeText, detectedComponents.timeValue)
    }

    private var displayPriority: (text: String?, value: Priority?) {
        // Active block's priority takes priority
        if let priority = lockedPriority {
            return (priority.name, priority)
        }
        if let manual = manualPriority {
            return (manual.name, manual)
        }
        return (detectedComponents.priorityText, detectedComponents.priorityValue)
    }

    // Display for Block chip - shows block name and time range when selected
    private var displayBlock: (text: String?, block: TimeBlock?) {
        if let block = activeBlock {
            return ("\(block.priorityName) • \(block.formattedTimeRange)", block)
        }
        return (nil, nil)
    }

    // MARK: - Block Context Banner
    @ViewBuilder
    private var blockContextBanner: some View {
        if let block = lockedBlock {
            HStack(spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(block.priorityColor)
                    .frame(width: 3, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Adding to \(block.priorityName)")
                        .font(Typography.labelMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)

                    Text(block.formattedTimeRange)
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Image(systemName: "link")
                    .font(.system(size: 12))
                    .foregroundColor(block.priorityColor)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(block.priorityColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(block.priorityColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Task Name Input Section
    private var taskNameInputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("What do you need to do?")
                .font(Typography.labelMedium)
                .foregroundColor(.textSecondary)

            // Input field with inline highlighting
            ZStack(alignment: .topLeading) {
                // Highlighted text layer with rounded pill backgrounds
                if !taskName.isEmpty && !detectedComponents.allDetectedRanges.isEmpty {
                    HighlightedTextView(
                        text: taskName,
                        detectedRanges: detectedComponents.allDetectedRanges
                    )
                    .padding(Spacing.base)
                }

                // Editable TextField (on top, transparent text when highlights exist)
                TextField("", text: $taskName, axis: .vertical)
                    .font(Typography.bodyLarge)
                    .foregroundColor(detectedComponents.allDetectedRanges.isEmpty ? .textPrimary : .clear)
                    .focused($isNameFocused)
                    .lineLimit(3)
                    .padding(Spacing.base)
                    .tint(.accentPrimary)

                // Placeholder
                if taskName.isEmpty {
                    Text("e.g. Meeting tomorrow 2pm")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                        .padding(Spacing.base)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(isNameFocused ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 1)
                    )
            )
            .onChange(of: taskName) {
                handleTaskNameChange()
            }
        }
    }

    // MARK: - Task Name Change Handler
    private func handleTaskNameChange() {
        // Capture previous detection count
        let previousCount = detectedComponents.allDetectedRanges.count
        let previousRanges = detectedComponents.allDetectedRanges

        let newDetections = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)

        withAnimation(.easeOut(duration: 0.15)) {
            detectedComponents = newDetections
        }

        // Auto-insert spaces when a new detection is made
        let newCount = newDetections.allDetectedRanges.count
        if newCount > previousCount && !taskName.hasSuffix("  ") {
            DispatchQueue.main.async {
                if !taskName.hasSuffix("  ") {
                    taskName.append("  ")
                }
            }
        }

        // Hide error if user adds actual task description
        let cleaned = SmartTextParser.cleanTaskName(taskName, detected: newDetections)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty && showNoDescriptionError {
            withAnimation(.easeOut(duration: 0.15)) {
                showNoDescriptionError = false
            }
        }

        // Check for newly detected components and trigger highlights
        let hadDate = previousCount > 0 && previousRanges.contains { $0.type == .date }
        let hadTime = previousCount > 0 && previousRanges.contains { $0.type == .time }
        let hadPriority = previousCount > 0 && previousRanges.contains { $0.type == .priority }
        let hadTimeBlock = previousCount > 0 && previousRanges.contains { $0.type == .timeBlock }

        if !hadDate && detectedComponents.dateText != nil {
            dateJustDetected = true
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { dateJustDetected = false }
            }
        }
        if !hadTime && detectedComponents.timeText != nil {
            timeJustDetected = true
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { timeJustDetected = false }
            }

            // Auto-set date when time is detected without a date
            if detectedComponents.dateValue == nil && manualDate == nil && activeBlock == nil {
                if let timeValue = detectedComponents.timeValue,
                   let hour = timeValue.hour,
                   let minute = timeValue.minute {
                    let calendar = Calendar.current
                    let now = Date()
                    let currentHour = calendar.component(.hour, from: now)
                    let currentMinute = calendar.component(.minute, from: now)

                    // Compare time: if detected time is after current time, use today; otherwise tomorrow
                    let isTimeInFuture = (hour > currentHour) || (hour == currentHour && minute > currentMinute)
                    let targetDate = isTimeInFuture ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))

                    manualDate = targetDate
                }
            }
        }
        if !hadPriority && detectedComponents.priorityText != nil {
            priorityJustDetected = true
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { priorityJustDetected = false }
            }
        }
        if !hadTimeBlock && detectedComponents.timeBlockText != nil {
            timeBlockJustDetected = true
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { timeBlockJustDetected = false }
            }
        }

        // Check if the detected date/time falls within a time block
        checkForCoincidingBlock()
    }

    // MARK: - Detection Chips Section
    private var detectionChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // Date chip
                DetectionChip(
                    icon: "calendar",
                    label: displayDate.text ?? "Date",
                    isActive: displayDate.text != nil,
                    color: .dueDateToday,
                    onTap: { showDatePicker = true },
                    onClear: displayDate.text != nil ? { clearDateChip() } : nil,
                    isHighlighted: dateJustDetected,
                    isLocked: hasLockedBlock
                )

                // Time chip
                DetectionChip(
                    icon: "clock.fill",
                    label: displayTime.text ?? "Time",
                    isActive: displayTime.text != nil,
                    color: .accentWarm,
                    onTap: { showTimePicker = true },
                    onClear: displayTime.text != nil ? { clearTimeChip() } : nil,
                    isHighlighted: timeJustDetected,
                    isLocked: hasLockedBlock
                )

                // Time Block chip
                DetectionChip(
                    icon: activeBlock != nil ? "rectangle.stack" : "calendar.badge.clock",
                    label: displayBlock.text ?? "Block",
                    isActive: displayBlock.block != nil,
                    color: activeBlock?.priorityColor ?? .accentPrimary,
                    onTap: { showTimeBlockPicker = true },
                    onClear: isBlockUserSelected ? { clearBlockSelection() } : nil,
                    isHighlighted: timeBlockJustDetected,
                    isLocked: lockedBlock != nil  // Only locked if from context, not user-selected
                )

                // Priority chip
                DetectionChip(
                    icon: "flag.fill",
                    label: displayPriority.text ?? "Priority",
                    isActive: displayPriority.text != nil,
                    color: lockedPriority?.color ?? .priorityPurple,
                    onTap: { showPriorityPicker = true },
                    onClear: displayPriority.text != nil ? { clearPriorityChip() } : nil,
                    isHighlighted: priorityJustDetected,
                    isLocked: hasLockedBlock
                )
            }
        }
    }

    // MARK: - Chip Clear Handlers
    private func clearDateChip() {
        manualDate = nil
        if detectedComponents.dateText != nil {
            taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                dateText: detectedComponents.dateText,
                dateValue: detectedComponents.dateValue,
                allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .date }
            ))
            detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
        }
    }

    private func clearTimeChip() {
        manualTime = nil
        if detectedComponents.timeText != nil {
            taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                timeText: detectedComponents.timeText,
                timeValue: detectedComponents.timeValue,
                allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .time }
            ))
            detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
        }
    }

    private func clearBlockSelection() {
        // Clear the selected block and all auto-populated values
        selectedBlock = nil
        manualDate = nil
        manualTime = nil
        manualPriority = nil
    }

    private func clearPriorityChip() {
        manualPriority = nil
        if detectedComponents.priorityText != nil {
            taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                priorityText: detectedComponents.priorityText,
                priorityValue: detectedComponents.priorityValue,
                allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .priority }
            ))
            detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
        }
    }

    // MARK: - Auto-detect Time Block from Date/Time
    /// Finds a time block that contains the given date and time
    private func findCoincidingBlock(date: Date, time: DateComponents) -> TimeBlock? {
        let calendar = Calendar.current
        guard let hour = time.hour else { return nil }
        let minute = time.minute ?? 0

        // Create the full datetime by combining the date with the time
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute
        dateComponents.second = 0

        guard let taskDateTime = calendar.date(from: dateComponents) else { return nil }

        // Find a block that contains this datetime
        for block in timeBlockStore.timeBlocks {
            if taskDateTime >= block.startTime && taskDateTime < block.endTime {
                return block
            }
        }
        return nil
    }

    /// Check if current date/time selection falls within a time block and auto-select it
    private func checkForCoincidingBlock() {
        // Don't override if there's already a locked block from context
        guard lockedBlock == nil else { return }

        // Get the effective date and time (from manual selection or detection)
        let effectiveDate: Date?
        if let manual = manualDate {
            effectiveDate = manual
        } else {
            effectiveDate = detectedComponents.dateValue
        }

        let effectiveTime: DateComponents?
        if let manual = manualTime {
            effectiveTime = manual
        } else {
            effectiveTime = detectedComponents.timeValue
        }

        // Both date and time must be set to check for coinciding blocks
        guard let date = effectiveDate, let time = effectiveTime else {
            // Clear auto-selected block if date or time is removed
            if selectedBlock != nil && lockedBlock == nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedBlock = nil
                }
            }
            return
        }

        // Find coinciding block
        if let coincidingBlock = findCoincidingBlock(date: date, time: time) {
            // Only update if it's different from current selection
            if selectedBlock?.id != coincidingBlock.id {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedBlock = coincidingBlock
                    // Also trigger the highlight animation
                    timeBlockJustDetected = true
                }
                Haptics.impact(.light)
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await MainActor.run { timeBlockJustDetected = false }
                }
            }
        } else {
            // Clear selection if no longer coinciding (but only if it was auto-selected)
            if selectedBlock != nil {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedBlock = nil
                }
            }
        }
    }

    // MARK: - Bottom Action Section
    @ViewBuilder
    private var bottomActionSection: some View {
        VStack(spacing: 0) {
            // Error message
            if showNoDescriptionError {
                errorMessageView
            }

            // Add/Save button
            addTaskButton
        }
    }

    private var errorMessageView: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
            Text("Please add a task description")
                .font(Typography.bodySmall)
        }
        .foregroundColor(.dueDateOverdue)
        .padding(.bottom, Spacing.sm)
    }

    private var addTaskButton: some View {
        let buttonTitle = isEditMode ? "Save Changes" : "Add Task"
        let buttonAction = isEditMode ? saveTask : addTask
        let isEnabled = !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return PrimaryButton(
            title: buttonTitle,
            action: buttonAction,
            isEnabled: isEnabled
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundSecondary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    // Block context banner when adding to a specific block
                    blockContextBanner

                    // Task name input with highlighting
                    taskNameInputSection

                    // Detection chips
                    detectionChipsSection

                    Spacer()

                    // Bottom section (error + button)
                    bottomActionSection
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle(isEditMode ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        Haptics.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
            })
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: Binding(
                    get: { manualDate ?? detectedComponents.dateValue },
                    set: { manualDate = $0 }
                ))
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(selectedTime: Binding(
                    get: { manualTime ?? detectedComponents.timeValue },
                    set: { manualTime = $0 }
                ))
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPriorityPicker) {
                PriorityPickerSheet(
                    priorities: priorityStore.priorities,
                    selectedPriority: Binding(
                        get: { manualPriority ?? detectedComponents.priorityValue },
                        set: { manualPriority = $0 }
                    )
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTimeBlockPicker) {
                TimeBlockPickerSheet(
                    timeBlockStore: timeBlockStore,
                    selectedBlock: $selectedBlock,
                    contextDate: contextDate,
                    onCreateBlock: { showAddBlockSheet = true }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                isNameFocused = true

                // Pre-fill data when editing an existing task
                if let task = editingTask {
                    taskName = task.name

                    // Pre-fill date
                    manualDate = task.dueDate

                    // Pre-fill time (now separate field)
                    if let time = task.dueTime {
                        manualTime = time.asDateComponents
                    }

                    // Pre-fill priority
                    manualPriority = task.priority

                    // Pre-fill block if task has one
                    if let blockId = task.timeBlockId {
                        selectedBlock = timeBlockStore.timeBlocks.first { $0.id == blockId }
                    }
                }
            }
            .onChange(of: selectedBlock) { _, newBlock in
                // Auto-populate date/time/priority when a block is selected
                if let block = newBlock {
                    let calendar = Calendar.current
                    manualDate = calendar.startOfDay(for: block.startTime)
                    let hour = calendar.component(.hour, from: block.startTime)
                    let minute = calendar.component(.minute, from: block.startTime)
                    manualTime = DateComponents(hour: hour, minute: minute)
                    manualPriority = priorityStore.priorities.first { $0.id == block.priorityId }
                }
            }
            .onChange(of: manualDate) { _, _ in
                // Check if the new date/time combination falls within a time block
                checkForCoincidingBlock()
            }
            .onChange(of: manualTime) { _, newTime in
                // Auto-set date when time is manually selected without a date
                if let time = newTime,
                   displayDate.value == nil && activeBlock == nil,
                   let hour = time.hour,
                   let minute = time.minute {
                    let calendar = Calendar.current
                    let now = Date()
                    let currentHour = calendar.component(.hour, from: now)
                    let currentMinute = calendar.component(.minute, from: now)

                    // If time is after current time, use today; otherwise tomorrow
                    let isTimeInFuture = (hour > currentHour) || (hour == currentHour && minute > currentMinute)
                    let targetDate = isTimeInFuture ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))

                    manualDate = targetDate
                }

                // Check if the new date/time combination falls within a time block
                checkForCoincidingBlock()
            }
            .sheet(isPresented: $showAddBlockSheet) {
                AddTimeBlockSheet(
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore,
                    targetDate: contextDate ?? Date()
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Build Attributed String for Highlighting
    private func buildAttributedString() -> AttributedString {
        var attributedString = AttributedString(taskName)

        // Apply default styling
        attributedString.font = Typography.bodyLarge
        attributedString.foregroundColor = .textPrimary

        // Process each detected range (now uses integer offsets)
        for (startOffset, endOffset, type) in detectedComponents.allDetectedRanges {
            // Convert to indices in the original taskName
            guard let startIndex = taskName.index(taskName.startIndex, offsetBy: startOffset, limitedBy: taskName.endIndex),
                  let endIndex = taskName.index(taskName.startIndex, offsetBy: endOffset, limitedBy: taskName.endIndex),
                  startIndex < endIndex else {
                continue
            }

            // Convert String range to AttributedString range
            let stringRange = startIndex..<endIndex
            if let attrStart = AttributedString.Index(stringRange.lowerBound, within: attributedString),
               let attrEnd = AttributedString.Index(stringRange.upperBound, within: attributedString) {
                attributedString[attrStart..<attrEnd].foregroundColor = .white
                attributedString[attrStart..<attrEnd].backgroundColor = type.color
            }
        }

        return attributedString
    }

    // MARK: - Add Task
    private func addTask() {
        let cleanedName = SmartTextParser.cleanTaskName(taskName, detected: detectedComponents)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if there's actual task description (not just detected components)
        guard !cleanedName.isEmpty else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showNoDescriptionError = true
            }
            Haptics.notification(.warning)
            return
        }

        // Hide error if it was showing
        showNoDescriptionError = false

        // Get date and time separately
        let finalDate = displayDate.value
        let finalTime: DueTime? = displayTime.value.flatMap { components in
            guard let hour = components.hour else { return nil }
            return DueTime(hour: hour, minute: components.minute ?? 0)
        }

        taskStore.addTask(
            name: cleanedName,
            dueDate: finalDate,
            dueTime: finalTime,
            priority: displayPriority.value,
            timeBlockId: activeBlock?.id
        )

        Haptics.impact(.medium)
        dismiss()
    }

    // MARK: - Save Task (Edit Mode)
    private func saveTask() {
        guard let originalTask = editingTask else { return }

        let cleanedName = SmartTextParser.cleanTaskName(taskName, detected: detectedComponents)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if there's actual task description
        guard !cleanedName.isEmpty else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showNoDescriptionError = true
            }
            Haptics.notification(.warning)
            return
        }

        showNoDescriptionError = false

        // Get date and time separately
        let finalDate = displayDate.value
        let finalTime: DueTime? = displayTime.value.flatMap { components in
            guard let hour = components.hour else { return nil }
            return DueTime(hour: hour, minute: components.minute ?? 0)
        }

        // Create updated task preserving original properties
        var updatedTask = originalTask
        updatedTask.name = cleanedName
        updatedTask.dueDate = finalDate
        updatedTask.dueTime = finalTime
        updatedTask.priority = displayPriority.value
        updatedTask.timeBlockId = activeBlock?.id

        taskStore.updateTask(updatedTask)

        Haptics.notification(.success)
        dismiss()
    }
}

// MARK: - Detection Chip
struct DetectionChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    let onTap: () -> Void
    let onClear: (() -> Void)?
    var isHighlighted: Bool = false
    var isLocked: Bool = false

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(label)
                .font(Typography.labelSmall)
                .fontWeight(.medium)

            if isLocked {
                // Lock icon for locked chips
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            } else if isActive, let onClear = onClear {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.7))
                    .padding(3)
                    .background(Circle().fill(Color.white.opacity(0.15)))
                    .onTapGesture {
                        Haptics.impact(.light)
                        onClear()
                    }
            }
        }
        .foregroundColor(isActive ? .white : color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(isActive ? color : color.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(isActive ? 0 : 0.3), lineWidth: 1)
                )
        )
        .overlay(
            // Animated highlight ring
            Capsule()
                .stroke(color, lineWidth: isHighlighted ? 2 : 0)
                .opacity(isHighlighted ? 1 : 0)
        )
        .opacity(isLocked ? 0.8 : (isHighlighted ? 0.85 : 1.0))
        .animation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true), value: isHighlighted)
        .onTapGesture {
            guard !isLocked else { return }
            Haptics.impact(.light)
            onTap()
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Binding var selectedDate: Date?
    @Environment(\.dismiss) private var dismiss

    @State private var pickerDate = Date()

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Select Date")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("Done")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentPrimary)
                    .onTapGesture {
                        selectedDate = pickerDate
                        Haptics.impact(.light)
                        dismiss()
                    }
            }
            .padding(.top, Spacing.base)

            DatePicker("", selection: $pickerDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 180)

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
        .onAppear {
            pickerDate = selectedDate ?? Date()
        }
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @Binding var selectedTime: DateComponents?
    @Environment(\.dismiss) private var dismiss

    @State private var hour: Int = 9
    @State private var minute: Int = 0
    @State private var isPM: Bool = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Select Time")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("Done")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentPrimary)
                    .onTapGesture {
                        var h = hour
                        if isPM && hour < 12 { h += 12 }
                        else if !isPM && hour == 12 { h = 0 }
                        selectedTime = DateComponents(hour: h, minute: minute)
                        Haptics.impact(.light)
                        dismiss()
                    }
            }
            .padding(.top, Spacing.base)

            HStack(spacing: Spacing.md) {
                // Hour picker
                Picker("Hour", selection: $hour) {
                    ForEach(1...12, id: \.self) { h in
                        Text("\(h)").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)

                Text(":")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.textPrimary)

                // Minute picker
                Picker("Minute", selection: $minute) {
                    ForEach([0, 15, 30, 45], id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 60)

                // AM/PM picker
                Picker("AM/PM", selection: $isPM) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.wheel)
                .frame(width: 60)
            }
            .frame(height: 150)

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
        .onAppear {
            if let time = selectedTime {
                let h = time.hour ?? 9
                hour = h > 12 ? h - 12 : (h == 0 ? 12 : h)
                minute = time.minute ?? 0
                isPM = h >= 12
            }
        }
    }
}

// MARK: - Priority Picker Sheet
struct PriorityPickerSheet: View {
    let priorities: [Priority]
    @Binding var selectedPriority: Priority?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Select Priority")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("Done")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentPrimary)
                    .onTapGesture {
                        Haptics.impact(.light)
                        dismiss()
                    }
            }
            .padding(.top, Spacing.base)

            if priorities.isEmpty {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "flag.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.textMuted)

                    Text("No priorities set up")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textSecondary)

                    Text("Add priorities in onboarding or settings")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        // None option
                        PriorityOptionRow(
                            name: "None",
                            color: .textMuted,
                            isSelected: selectedPriority == nil
                        ) {
                            selectedPriority = nil
                            Haptics.impact(.light)
                        }

                        ForEach(priorities) { priority in
                            PriorityOptionRow(
                                name: priority.name,
                                color: priority.color,
                                isSelected: selectedPriority?.id == priority.id
                            ) {
                                selectedPriority = priority
                                Haptics.impact(.light)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
    }
}

struct PriorityOptionRow: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            Text(name)
                .font(Typography.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentPrimary)
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(isSelected ? Color.accentPrimary.opacity(0.1) : Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSelected ? Color.accentPrimary.opacity(0.3) : Color.surfaceBorder, lineWidth: 1)
                )
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Time Block Picker Sheet
struct TimeBlockPickerSheet: View {
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var selectedBlock: TimeBlock?
    var contextDate: Date?  // If set, filter to this date only
    let onCreateBlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    // Get available blocks based on context (only current and future blocks)
    private var availableBlocks: [TimeBlock] {
        let now = Date()

        if let date = contextDate {
            // Filter to specific date, excluding past blocks
            return timeBlockStore.blocks(for: date)
                .filter { $0.endTime > now }  // Only blocks that haven't ended
                .sorted { $0.startTime < $1.startTime }
        } else {
            // Show all future blocks (blocks that haven't ended yet)
            return timeBlockStore.timeBlocks
                .filter { $0.endTime > now }  // Only blocks that haven't ended
                .sorted { $0.startTime < $1.startTime }
        }
    }

    // Group blocks by week, then by day for display
    private var blocksByWeekAndDay: [(weekLabel: String, days: [(date: Date, blocks: [TimeBlock])])] {
        let calendar = Calendar.current
        var grouped: [Date: [TimeBlock]] = [:]

        for block in availableBlocks {
            let day = calendar.startOfDay(for: block.startTime)
            grouped[day, default: []].append(block)
        }

        let sortedDays = grouped.keys.sorted().map { date in
            (date: date, blocks: grouped[date]!.sorted { $0.startTime < $1.startTime })
        }

        // Group days by week
        var weekGroups: [(weekStart: Date, weekLabel: String, days: [(date: Date, blocks: [TimeBlock])])] = []

        for dayGroup in sortedDays {
            let weekStart = dayGroup.date.startOfWeek()
            let weekLabel = formatWeekLabel(for: dayGroup.date)

            if let lastIndex = weekGroups.lastIndex(where: { $0.weekStart == weekStart }) {
                weekGroups[lastIndex].days.append(dayGroup)
            } else {
                weekGroups.append((weekStart: weekStart, weekLabel: weekLabel, days: [dayGroup]))
            }
        }

        return weekGroups.map { (weekLabel: $0.weekLabel, days: $0.days) }
    }

    private func formatWeekLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let todayWeekStart = Date().startOfWeek()
        let targetWeekStart = date.startOfWeek()

        // Calculate weeks difference using days (more reliable than weekOfYear)
        let daysDiff = calendar.dateComponents([.day], from: todayWeekStart, to: targetWeekStart).day ?? 0
        let weeksDiff = daysDiff / 7

        switch weeksDiff {
        case 0:
            return "This Week"
        case 1:
            return "Next Week"
        case -1:
            return "Last Week"
        default:
            // Show the week's date range for other weeks
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) ?? targetWeekStart
            return "\(formatter.string(from: targetWeekStart)) - \(formatter.string(from: weekEnd))"
        }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Time Block")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text("Done")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentPrimary)
                    .onTapGesture {
                        Haptics.impact(.light)
                        dismiss()
                    }
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.base)
            .padding(.bottom, Spacing.md)

            if availableBlocks.isEmpty {
                // Empty state
                VStack(spacing: Spacing.lg) {
                    Spacer()

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.textMuted)

                    Text("No blocks available")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textSecondary)

                    Text(contextDate != nil ? "Create a block for this day" : "Create a block to schedule tasks")
                        .font(Typography.bodySmall)
                        .foregroundColor(.textMuted)
                        .multilineTextAlignment(.center)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Create Block")
                            .font(Typography.bodyMedium)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
                    .onTapGesture {
                        Haptics.impact(.light)
                        dismiss()
                        onCreateBlock()
                    }

                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.lg) {
                        // "None" option to clear selection
                        if selectedBlock != nil {
                            BlockOptionRow(
                                block: nil,
                                isSelected: false,
                                label: "No block",
                                subtitle: "Remove block assignment"
                            ) {
                                selectedBlock = nil
                                Haptics.impact(.light)
                                dismiss()
                            }
                            .padding(.horizontal, Spacing.xl)
                        }

                        ForEach(Array(blocksByWeekAndDay.enumerated()), id: \.offset) { _, weekGroup in
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                // Week header
                                Text(weekGroup.weekLabel.uppercased())
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textMuted)
                                    .tracking(1)
                                    .padding(.horizontal, Spacing.xl)
                                    .padding(.top, Spacing.sm)

                                // Days within this week
                                ForEach(Array(weekGroup.days.enumerated()), id: \.offset) { _, dayGroup in
                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        // Day header
                                        Text(formatDayHeader(dayGroup.date))
                                            .font(Typography.labelMedium)
                                            .foregroundColor(.textSecondary)
                                            .padding(.horizontal, Spacing.xl)

                                        // Blocks for this day
                                        ForEach(dayGroup.blocks) { block in
                                            BlockOptionRow(
                                                block: block,
                                                isSelected: selectedBlock?.id == block.id,
                                                label: block.priorityName,
                                                subtitle: "\(block.formattedTimeRange) • \(block.formattedDuration)"
                                            ) {
                                                selectedBlock = block
                                                Haptics.impact(.medium)
                                                dismiss()
                                            }
                                            .padding(.horizontal, Spacing.xl)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .background(Color.backgroundSecondary)
    }
}

struct BlockOptionRow: View {
    let block: TimeBlock?
    let isSelected: Bool
    let label: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(block?.priorityColor ?? Color.textMuted)
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Text(subtitle)
                    .font(Typography.labelSmall)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentPrimary)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(isSelected ? Color.accentPrimary.opacity(0.1) : Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSelected ? Color.accentPrimary.opacity(0.3) : Color.surfaceBorder, lineWidth: 1)
                )
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Highlighted Text View with Rounded Rectangles
struct HighlightedTextView: View {
    let text: String
    let detectedRanges: [(startOffset: Int, endOffset: Int, type: DetectedComponents.DetectionType)]

    var body: some View {
        FlowLayout(spacing: 0) {
            ForEach(Array(buildSegments().enumerated()), id: \.offset) { _, segment in
                if let type = segment.type {
                    // Highlighted text - background extends slightly beyond text
                    Text(segment.text)
                        .font(Typography.bodyLarge)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(type.color)
                                .padding(.horizontal, -2)
                                .padding(.vertical, -1)
                        )
                } else {
                    ForEach(Array(splitWords(segment.text).enumerated()), id: \.offset) { _, word in
                        Text(word).font(Typography.bodyLarge).foregroundColor(.textPrimary)
                    }
                }
            }
        }
    }

    private struct Segment { let text: String; let type: DetectedComponents.DetectionType? }

    private func buildSegments() -> [Segment] {
        guard !text.isEmpty else { return [] }
        var segments: [Segment] = []
        var offset = 0
        for (start, end, type) in detectedRanges.sorted(by: { $0.startOffset < $1.startOffset }) {
            guard let si = text.index(text.startIndex, offsetBy: start, limitedBy: text.endIndex),
                  let ei = text.index(text.startIndex, offsetBy: end, limitedBy: text.endIndex),
                  start >= offset, si < ei else { continue }
            if offset < start, let ci = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex) {
                segments.append(Segment(text: String(text[ci..<si]), type: nil))
            }
            segments.append(Segment(text: String(text[si..<ei]), type: type))
            offset = end
        }
        if offset < text.count, let ci = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex) {
            segments.append(Segment(text: String(text[ci...]), type: nil))
        }
        return segments
    }

    private func splitWords(_ s: String) -> [String] {
        var r: [String] = []; var c = ""
        for ch in s { if ch == " " { if !c.isEmpty { r.append(c); c = "" }; r.append(" ") } else { c.append(ch) } }
        if !c.isEmpty { r.append(c) }; return r
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in arrange(proposal: proposal, subviews: subviews).positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y),
                              proposal: ProposedViewSize(subviews[i].sizeThatFits(.unspecified)))
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var pos: [CGPoint] = []; var x: CGFloat = 0, y: CGFloat = 0, lh: CGFloat = 0, tw: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > maxW && x > 0 { x = 0; y += lh + spacing; lh = 0 }
            pos.append(CGPoint(x: x, y: y)); x += sz.width; lh = max(lh, sz.height); tw = max(tw, x)
        }
        return (CGSize(width: tw, height: y + lh), pos)
    }
}

#Preview {
    AddTaskSheet(taskStore: TaskStore(), priorityStore: OnboardingState(), timeBlockStore: TimeBlockStore())
}
