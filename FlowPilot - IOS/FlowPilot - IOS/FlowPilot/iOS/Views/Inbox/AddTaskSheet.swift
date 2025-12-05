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

    var allDetectedRanges: [(range: Range<String.Index>, type: DetectionType)] = []

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
        let position: Int
        let range: Range<String.Index>
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

        // Helper to get position from range
        func position(of range: Range<String.Index>) -> Int {
            lowercased.distance(from: lowercased.startIndex, to: range.lowerBound)
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
            dateCandidates.append(Candidate(position: position(of: range), range: range, text: "Today", value: today))
        }

        // "tomorrow"
        if let range = lowercased.range(of: "tomorrow") {
            if let date = calendar.date(byAdding: .day, value: 1, to: today) {
                dateCandidates.append(Candidate(position: position(of: range), range: range, text: "Tomorrow", value: date))
            }
        }

        // "tmr"
        if let range = lowercased.range(of: " tmr") ?? lowercased.range(of: "^tmr", options: .regularExpression) {
            if let date = calendar.date(byAdding: .day, value: 1, to: today) {
                dateCandidates.append(Candidate(position: position(of: range), range: range, text: "Tomorrow", value: date))
            }
        }

        // "next week"
        if let range = lowercased.range(of: "next week") {
            if let date = calendar.date(byAdding: .day, value: 7, to: today) {
                dateCandidates.append(Candidate(position: position(of: range), range: range, text: "Next Week", value: date))
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
                    dateCandidates.append(Candidate(position: position(of: range), range: range, text: formatter.string(from: date), value: date))
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
                    dateCandidates.append(Candidate(position: position(of: range), range: range, text: formatter.string(from: date), value: date))
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
                        dateCandidates.append(Candidate(position: position(of: range), range: range, text: formatter.string(from: date), value: date))
                    }
                }
            }
        }

        // "[month] [day]" e.g., "Dec 4", "Dec 4th", "December 1st"
        if let regex = try? NSRegularExpression(pattern: "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\s+(\\d{1,2})(?:st|nd|rd|th)?", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
           let monthRange = Range(match.range(at: 1), in: lowercased),
           let dayRange = Range(match.range(at: 2), in: lowercased),
           let fullRange = Range(match.range, in: lowercased) {
            let monthStr = String(lowercased[monthRange]).prefix(3).lowercased()
            let dayStr = String(lowercased[dayRange])
            if let monthIndex = monthNames.firstIndex(of: monthStr),
               let day = extractDay(from: dayStr) {
                var components = DateComponents()
                components.month = monthIndex + 1
                components.day = day
                components.year = calendar.component(.year, from: today)
                if let date = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    dateCandidates.append(Candidate(position: position(of: fullRange), range: fullRange, text: formatter.string(from: date), value: date))
                }
            }
        }

        // "[day] [month]" e.g., "4 Dec", "4th Dec", "1st December"
        if let regex = try? NSRegularExpression(pattern: "(\\d{1,2})(?:st|nd|rd|th)?\\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*", options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
           let dayRange = Range(match.range(at: 1), in: lowercased),
           let monthRange = Range(match.range(at: 2), in: lowercased),
           let fullRange = Range(match.range, in: lowercased) {
            let dayStr = String(lowercased[dayRange])
            let monthStr = String(lowercased[monthRange]).prefix(3).lowercased()
            if let monthIndex = monthNames.firstIndex(of: monthStr),
               let day = extractDay(from: dayStr) {
                var components = DateComponents()
                components.month = monthIndex + 1
                components.day = day
                components.year = calendar.component(.year, from: today)
                if let date = calendar.date(from: components) {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    dateCandidates.append(Candidate(position: position(of: fullRange), range: fullRange, text: formatter.string(from: date), value: date))
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
                    dateCandidates.append(Candidate(position: position(of: fullRange), range: fullRange, text: formatter.string(from: date), value: date))
                }
            }
        }

        // Select earliest date candidate
        if let earliest = dateCandidates.min(by: { $0.position < $1.position }) {
            result.dateText = earliest.text
            result.dateValue = earliest.value as? Date
            result.allDetectedRanges.append((earliest.range, .date))
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

                timeCandidates.append(Candidate(position: position(of: fullRange), range: fullRange, text: timeText, value: DateComponents(hour: hour, minute: minute)))
            }
        }

        // Select earliest time candidate
        if let earliest = timeCandidates.min(by: { $0.position < $1.position }) {
            result.timeText = earliest.text
            result.timeValue = earliest.value as? DateComponents
            result.allDetectedRanges.append((earliest.range, .time))
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
                durationCandidates.append(Candidate(position: position(of: fullRange), range: fullRange, text: text, value: minutes))
            }
        }

        // Select earliest duration candidate
        if let earliest = durationCandidates.min(by: { $0.position < $1.position }) {
            result.timeBlockText = earliest.text
            result.timeBlockDuration = earliest.value as? Int
            result.allDetectedRanges.append((earliest.range, .timeBlock))
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
                    priorityCandidates.append(Candidate(position: position(of: range), range: range, text: priority.name, value: priority))
                    break
                }
            }
        }

        // Select earliest priority candidate
        if let earliest = priorityCandidates.min(by: { $0.position < $1.position }) {
            result.priorityText = earliest.text
            result.priorityValue = earliest.value as? Priority
            result.allDetectedRanges.append((earliest.range, .priority))
        }

        return result
    }

    static func cleanTaskName(_ text: String, detected: DetectedComponents) -> String {
        var cleaned = text

        // Sort ranges by start index in reverse order to remove from end first
        let sortedRanges = detected.allDetectedRanges.sorted {
            text.distance(from: text.startIndex, to: $0.range.lowerBound) >
            text.distance(from: text.startIndex, to: $1.range.lowerBound)
        }

        for (range, _) in sortedRanges {
            cleaned.removeSubrange(range)
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
    @Environment(\.dismiss) private var dismiss

    @State private var taskName = ""
    @State private var detectedComponents = DetectedComponents()

    // Manual overrides
    @State private var manualDate: Date? = nil
    @State private var manualTime: DateComponents? = nil
    @State private var manualPriority: Priority? = nil
    @State private var manualTimeBlock: Int? = nil

    // Sheet states
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showPriorityPicker = false
    @State private var showTimeBlockPicker = false

    @FocusState private var isNameFocused: Bool

    // Computed display values
    private var displayDate: (text: String?, value: Date?) {
        if let manual = manualDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return (formatter.string(from: manual), manual)
        }
        return (detectedComponents.dateText, detectedComponents.dateValue)
    }

    private var displayTime: (text: String?, value: DateComponents?) {
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
        if let manual = manualPriority {
            return (manual.name, manual)
        }
        return (detectedComponents.priorityText, detectedComponents.priorityValue)
    }

    private var displayTimeBlock: (text: String?, value: Int?) {
        if let manual = manualTimeBlock {
            if manual >= 60 {
                let hours = manual / 60
                return (hours == 1 ? "1 hour" : "\(hours) hours", manual)
            } else {
                return ("\(manual) min", manual)
            }
        }
        return (detectedComponents.timeBlockText, detectedComponents.timeBlockDuration)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundSecondary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    // Task name input with highlighting
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("What do you need to do?")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        // Input field
                        TextField("", text: $taskName, axis: .vertical)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textPrimary)
                            .focused($isNameFocused)
                            .lineLimit(3)
                            .placeholder(when: taskName.isEmpty) {
                                Text("e.g. Meeting tomorrow 2pm")
                                    .font(Typography.bodyLarge)
                                    .foregroundColor(.textMuted)
                            }
                            .padding(Spacing.base)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(isNameFocused ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 1)
                                    )
                            )
                            .onChange(of: taskName) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
                                }
                            }
                    }

                    // Detection chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            // Date chip
                            DetectionChip(
                                icon: "calendar",
                                label: displayDate.text ?? "Date",
                                isActive: displayDate.text != nil,
                                color: .dueDateToday,
                                onTap: { showDatePicker = true },
                                onClear: displayDate.text != nil ? {
                                    manualDate = nil
                                    // Re-parse to clear detected
                                    if detectedComponents.dateText != nil {
                                        taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                                            dateText: detectedComponents.dateText,
                                            dateValue: detectedComponents.dateValue,
                                            allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .date }
                                        ))
                                        detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
                                    }
                                } : nil
                            )

                            // Time chip
                            DetectionChip(
                                icon: "clock.fill",
                                label: displayTime.text ?? "Time",
                                isActive: displayTime.text != nil,
                                color: .accentWarm,
                                onTap: { showTimePicker = true },
                                onClear: displayTime.text != nil ? {
                                    manualTime = nil
                                    if detectedComponents.timeText != nil {
                                        taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                                            timeText: detectedComponents.timeText,
                                            timeValue: detectedComponents.timeValue,
                                            allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .time }
                                        ))
                                        detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
                                    }
                                } : nil
                            )

                            // Time Block chip
                            DetectionChip(
                                icon: "timer",
                                label: displayTimeBlock.text ?? "Time block",
                                isActive: displayTimeBlock.text != nil,
                                color: Color(red: 0.6, green: 0.25, blue: 0.25),
                                onTap: { showTimeBlockPicker = true },
                                onClear: displayTimeBlock.text != nil ? {
                                    manualTimeBlock = nil
                                    if detectedComponents.timeBlockText != nil {
                                        taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                                            timeBlockText: detectedComponents.timeBlockText,
                                            timeBlockDuration: detectedComponents.timeBlockDuration,
                                            allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .timeBlock }
                                        ))
                                        detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
                                    }
                                } : nil
                            )

                            // Priority chip
                            DetectionChip(
                                icon: "flag.fill",
                                label: displayPriority.text ?? "Priority",
                                isActive: displayPriority.text != nil,
                                color: .priorityPurple,
                                onTap: { showPriorityPicker = true },
                                onClear: displayPriority.text != nil ? {
                                    manualPriority = nil
                                    if detectedComponents.priorityText != nil {
                                        taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                                            priorityText: detectedComponents.priorityText,
                                            priorityValue: detectedComponents.priorityValue,
                                            allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .priority }
                                        ))
                                        detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
                                    }
                                } : nil
                            )
                        }
                    }

                    Spacer()

                    // Add button
                    PrimaryButton(
                        title: "Add Task",
                        action: addTask,
                        isEnabled: !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xxl)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: Binding(
                    get: { manualDate ?? detectedComponents.dateValue },
                    set: { manualDate = $0 }
                ))
                .presentationDetents([.height(400)])
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
                TimeBlockPickerSheet(selectedDuration: Binding(
                    get: { manualTimeBlock ?? detectedComponents.timeBlockDuration },
                    set: { manualTimeBlock = $0 }
                ))
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    // MARK: - Add Task
    private func addTask() {
        let cleanedName = SmartTextParser.cleanTaskName(taskName, detected: detectedComponents)
        guard !cleanedName.isEmpty else { return }

        // Combine date and time
        var finalDate = displayDate.value
        if let date = finalDate, let time = displayTime.value {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = time.hour
            components.minute = time.minute
            finalDate = calendar.date(from: components)
        }

        taskStore.addTask(
            name: cleanedName,
            dueDate: finalDate,
            priority: displayPriority.value
        )
        Haptics.impact(.medium)
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

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))

            Text(label)
                .font(Typography.labelSmall)
                .fontWeight(.medium)

            if isActive, let onClear = onClear {
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
        .onTapGesture {
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
                .datePickerStyle(.graphical)
                .tint(.accentPrimary)

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
    @Binding var selectedDuration: Int?
    @Environment(\.dismiss) private var dismiss

    let presets: [(label: String, minutes: Int)] = [
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("1 hour", 60),
        ("1.5 hours", 90),
        ("2 hours", 120),
        ("3 hours", 180),
        ("4 hours", 240)
    ]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Text("Time Block Duration")
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

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Spacing.sm) {
                // None option
                DurationOptionCell(
                    label: "None",
                    isSelected: selectedDuration == nil,
                    color: .textMuted
                ) {
                    selectedDuration = nil
                    Haptics.impact(.light)
                }

                ForEach(presets, id: \.minutes) { preset in
                    DurationOptionCell(
                        label: preset.label,
                        isSelected: selectedDuration == preset.minutes,
                        color: Color(red: 0.6, green: 0.25, blue: 0.25)
                    ) {
                        selectedDuration = preset.minutes
                        Haptics.impact(.light)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
    }
}

struct DurationOptionCell: View {
    let label: String
    let isSelected: Bool
    let color: Color

    let onTap: () -> Void

    var body: some View {
        Text(label)
            .font(Typography.labelSmall)
            .fontWeight(.medium)
            .foregroundColor(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(isSelected ? color : color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                    )
            )
            .onTapGesture(perform: onTap)
    }
}

#Preview {
    AddTaskSheet(taskStore: TaskStore(), priorityStore: OnboardingState())
}
