import SwiftUI

// MARK: - Edit Task Sheet
struct EditTaskSheet: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Environment(\.dismiss) private var dismiss

    @State private var taskName: String = ""
    @State private var selectedDate: Date? = nil
    @State private var selectedTime: DueTime? = nil
    @State private var selectedPriority: Priority? = nil
    @State private var selectedTimeBlock: TimeBlock? = nil
    @State private var detectedComponents = DetectedComponents()

    @State private var isEditingName = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @State private var showPriorityPicker = false
    @State private var showTimeBlockPicker = false

    // Animation states for chip highlights
    @State private var dateJustDetected = false
    @State private var timeJustDetected = false
    @State private var priorityJustDetected = false
    @State private var timeBlockJustDetected = false

    @FocusState private var nameFieldFocused: Bool

    private var linkedTimeBlock: TimeBlock? {
        guard let blockId = task.timeBlockId else { return nil }
        return timeBlockStore.timeBlocks.first { $0.id == blockId }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Task Name Section (Hero)
                        taskNameSection
                            .padding(.top, Spacing.lg)

                        // Details List
                        VStack(spacing: 0) {
                            // Due Date Row
                            DetailRow(
                                icon: "calendar",
                                iconColor: .dueDateToday,
                                label: "Due Date",
                                value: formattedDate,
                                isSet: selectedDate != nil,
                                onTap: {
                                    Haptics.impact(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showDatePicker.toggle()
                                        showPriorityPicker = false
                                        showTimeBlockPicker = false
                                    }
                                },
                                onClear: selectedDate != nil ? {
                                    Haptics.impact(.light)
                                    withAnimation { selectedDate = nil }
                                } : nil
                            )

                            if showDatePicker {
                                DatePicker("", selection: Binding(
                                    get: { selectedDate ?? Date() },
                                    set: { selectedDate = $0 }
                                ), displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding(.horizontal, Spacing.base)
                                .padding(.bottom, Spacing.md)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Divider()
                                .background(Color.surfaceBorder.opacity(0.5))
                                .padding(.leading, 52)

                            // Due Time Row
                            DetailRow(
                                icon: "clock.fill",
                                iconColor: .accentWarm,
                                label: "Due Time",
                                value: formattedTime,
                                isSet: selectedTime != nil,
                                onTap: {
                                    Haptics.impact(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showTimePicker.toggle()
                                        showDatePicker = false
                                        showPriorityPicker = false
                                        showTimeBlockPicker = false
                                    }
                                },
                                onClear: selectedTime != nil ? {
                                    Haptics.impact(.light)
                                    withAnimation { selectedTime = nil }
                                } : nil
                            )

                            if showTimePicker {
                                timePickerContent
                            }

                            Divider()
                                .background(Color.surfaceBorder.opacity(0.5))
                                .padding(.leading, 52)

                            // Time Block Row (only if attached)
                            if linkedTimeBlock != nil || selectedTimeBlock != nil {
                                DetailRow(
                                    icon: "clock.fill",
                                    iconColor: (selectedTimeBlock ?? linkedTimeBlock)?.priorityColor ?? .textMuted,
                                    label: "Time Block",
                                    value: timeBlockValue,
                                    isSet: true,
                                    onTap: {
                                        Haptics.impact(.light)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            showTimeBlockPicker.toggle()
                                            showDatePicker = false
                                            showPriorityPicker = false
                                        }
                                    },
                                    onClear: {
                                        Haptics.impact(.light)
                                        withAnimation { selectedTimeBlock = nil }
                                    }
                                )

                                if showTimeBlockPicker {
                                    timeBlockPickerContent
                                }

                                Divider()
                                    .background(Color.surfaceBorder.opacity(0.5))
                                    .padding(.leading, 52)
                            }

                            // Priority Row
                            DetailRow(
                                icon: "flag.fill",
                                iconColor: selectedPriority?.color ?? .textMuted,
                                label: "Priority",
                                value: selectedPriority?.name ?? "None",
                                isSet: selectedPriority != nil,
                                onTap: {
                                    Haptics.impact(.light)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showPriorityPicker.toggle()
                                        showDatePicker = false
                                        showTimeBlockPicker = false
                                    }
                                },
                                onClear: selectedPriority != nil ? {
                                    Haptics.impact(.light)
                                    withAnimation { selectedPriority = nil }
                                } : nil
                            )

                            if showPriorityPicker {
                                priorityPickerContent
                            }
                        }
                        .padding(.top, Spacing.xl)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, Spacing.base)
                }

                // Bottom Save Bar
                VStack {
                    Spacer()
                    saveBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }

                ToolbarItem(placement: .principal) {
                    Text("Edit Task")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
            }
            .onAppear {
                taskName = task.name
                selectedDate = task.dueDate
                selectedTime = task.dueTime
                selectedTimeBlock = linkedTimeBlock
                selectedPriority = task.priority
            }
        }
    }

    // MARK: - Task Name Section
    private var taskNameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if isEditingName {
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
                        .focused($nameFieldFocused)
                        .lineLimit(3)
                        .onSubmit {
                            isEditingName = false
                        }
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
                                .stroke(nameFieldFocused ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 1)
                        )
                )
                .onChange(of: taskName) {
                    handleTaskNameChange()
                }

                // Detection chips
                detectionChipsSection
            } else {
                Text(taskName.isEmpty ? "Untitled Task" : taskName)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(taskName.isEmpty ? .textMuted : .textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        isEditingName = true
                        nameFieldFocused = true
                    }
            }

            // Subtle separator
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Detection Chips Section
    private var detectionChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                // Date chip
                DetectionChip(
                    icon: "calendar",
                    label: detectedComponents.dateText ?? selectedDate.map { formattedDateShort($0) } ?? "Date",
                    isActive: detectedComponents.dateText != nil || selectedDate != nil,
                    color: .dueDateToday,
                    onTap: { showDatePicker = true },
                    onClear: (detectedComponents.dateText != nil || selectedDate != nil) ? { clearDateDetection() } : nil,
                    isHighlighted: dateJustDetected,
                    isLocked: false
                )

                // Priority chip
                DetectionChip(
                    icon: "flag.fill",
                    label: detectedComponents.priorityText ?? selectedPriority?.name ?? "Priority",
                    isActive: detectedComponents.priorityText != nil || selectedPriority != nil,
                    color: selectedPriority?.color ?? .priorityPurple,
                    onTap: { showPriorityPicker = true },
                    onClear: (detectedComponents.priorityText != nil || selectedPriority != nil) ? { clearPriorityDetection() } : nil,
                    isHighlighted: priorityJustDetected,
                    isLocked: false
                )
            }
        }
        .padding(.top, Spacing.xs)
    }

    private func formattedDateShort(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func clearDateDetection() {
        selectedDate = nil
        if detectedComponents.dateText != nil {
            taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                dateText: detectedComponents.dateText,
                dateValue: detectedComponents.dateValue,
                allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .date }
            ))
            detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
        }
    }

    private func clearPriorityDetection() {
        selectedPriority = nil
        if detectedComponents.priorityText != nil {
            taskName = SmartTextParser.cleanTaskName(taskName, detected: DetectedComponents(
                priorityText: detectedComponents.priorityText,
                priorityValue: detectedComponents.priorityValue,
                allDetectedRanges: detectedComponents.allDetectedRanges.filter { $0.type == .priority }
            ))
            detectedComponents = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)
        }
    }

    // MARK: - Task Name Change Handler
    private func handleTaskNameChange() {
        // Capture previous detection state
        let previousRanges = detectedComponents.allDetectedRanges
        let hadDate = previousRanges.contains { $0.type == .date }
        let hadPriority = previousRanges.contains { $0.type == .priority }

        let newDetections = SmartTextParser.parse(taskName, priorities: priorityStore.priorities)

        withAnimation(.easeOut(duration: 0.15)) {
            detectedComponents = newDetections
        }

        // Auto-apply detected values
        if let detectedDate = newDetections.dateValue {
            selectedDate = detectedDate
        }
        if let detectedPriority = newDetections.priorityValue {
            selectedPriority = detectedPriority
        }

        // Trigger chip highlight animations for new detections
        if !hadDate && newDetections.dateText != nil {
            dateJustDetected = true
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { dateJustDetected = false }
            }
        }
        if !hadPriority && newDetections.priorityText != nil {
            priorityJustDetected = true
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { priorityJustDetected = false }
            }
        }
    }

    // MARK: - Formatted Values
    private var formattedDate: String {
        guard let date = selectedDate else { return "Not set" }
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private var formattedTime: String {
        guard let time = selectedTime else { return "Not set" }
        return time.formatted
    }

    private var timeBlockValue: String {
        guard let block = selectedTimeBlock ?? linkedTimeBlock else { return "None" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(block.priorityName) · \(formatter.string(from: block.startTime))"
    }

    // MARK: - Priority Picker Content
    private var priorityPickerContent: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(priorityStore.priorities) { priority in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 10, height: 10)

                    Text(priority.name)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    if selectedPriority?.id == priority.id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentPrimary)
                    }
                }
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedPriority?.id == priority.id ? priority.color.opacity(0.1) : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedPriority = priority
                        showPriorityPicker = false
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Time Picker Content
    private var timePickerContent: some View {
        TimePickerInline(selectedTime: $selectedTime, onDone: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                showTimePicker = false
            }
        })
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Time Block Picker Content
    private var timeBlockPickerContent: some View {
        VStack(spacing: Spacing.xs) {
            let todayBlocks = timeBlockStore.timeBlocks.filter {
                Calendar.current.isDateInToday($0.startTime) && !$0.isPast
            }

            if todayBlocks.isEmpty {
                Text("No upcoming blocks today")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.textMuted)
                    .padding(.vertical, Spacing.md)
            } else {
                ForEach(todayBlocks) { block in
                    HStack(spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(block.priorityColor)
                            .frame(width: 3, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.priorityName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textPrimary)

                            Text(formatBlockTime(block))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.textMuted)
                        }

                        Spacer()

                        if selectedTimeBlock?.id == block.id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.accentPrimary)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                    .padding(.horizontal, Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTimeBlock?.id == block.id ? block.priorityColor.opacity(0.1) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedTimeBlock = block
                            showTimeBlockPicker = false
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.sm)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func formatBlockTime(_ block: TimeBlock) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: block.startTime)) – \(formatter.string(from: block.endTime))"
    }

    // MARK: - Save Bar
    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.surfaceBorder)

            HStack {
                // Delete button
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentError)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.accentError.opacity(0.1))
                    )
                    .onTapGesture {
                        Haptics.impact(.medium)
                        taskStore.deleteTask(task)
                        dismiss()
                    }

                Spacer()

                // Save button
                Text("Save Changes")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hasChanges ? .white : .textMuted)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(hasChanges ? Color.accentPrimary : Color.surfaceSecondary)
                    )
                    .onTapGesture {
                        guard hasChanges else { return }
                        Haptics.impact(.medium)
                        saveChanges()
                        dismiss()
                    }
            }
            .padding(.horizontal, Spacing.base)
            .padding(.vertical, Spacing.md)
            .background(Color.backgroundPrimary)
        }
    }

    private var hasChanges: Bool {
        taskName != task.name ||
        selectedDate != task.dueDate ||
        selectedTime != task.dueTime ||
        selectedPriority?.id != task.priority?.id ||
        selectedTimeBlock?.id != task.timeBlockId
    }

    private func saveChanges() {
        var updatedTask = task
        // Clean task name from detected components
        let cleanedName = SmartTextParser.cleanTaskName(taskName, detected: detectedComponents)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        updatedTask.name = cleanedName.isEmpty ? taskName.trimmingCharacters(in: .whitespacesAndNewlines) : cleanedName
        updatedTask.dueDate = selectedDate
        updatedTask.dueTime = selectedTime
        updatedTask.priority = selectedPriority
        updatedTask.timeBlockId = selectedTimeBlock?.id

        taskStore.updateTask(updatedTask)
    }
}

// MARK: - Time Picker Inline
struct TimePickerInline: View {
    @Binding var selectedTime: DueTime?
    let onDone: () -> Void

    @State private var hour: Int = 9
    @State private var minute: Int = 0
    @State private var isPM: Bool = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                // Hour picker
                Picker("Hour", selection: $hour) {
                    ForEach(1...12, id: \.self) { h in
                        Text("\(h)").tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 120)

                Text(":")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.textPrimary)

                // Minute picker
                Picker("Minute", selection: $minute) {
                    ForEach([0, 15, 30, 45], id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 50, height: 120)

                // AM/PM picker
                Picker("AM/PM", selection: $isPM) {
                    Text("AM").tag(false)
                    Text("PM").tag(true)
                }
                .pickerStyle(.wheel)
                .frame(width: 60, height: 120)
            }

            Text("Done")
                .font(Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.accentPrimary)
                .onTapGesture {
                    var h = hour
                    if isPM && hour < 12 { h += 12 }
                    else if !isPM && hour == 12 { h = 0 }
                    selectedTime = DueTime(hour: h, minute: minute)
                    Haptics.impact(.light)
                    onDone()
                }
        }
        .onAppear {
            if let time = selectedTime {
                let h = time.hour
                hour = h > 12 ? h - 12 : (h == 0 ? 12 : h)
                minute = time.minute
                isPM = h >= 12
            }
        }
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let isSet: Bool
    let onTap: () -> Void
    var onClear: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Label & Value
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(value)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isSet ? .textPrimary : .textMuted)
            }

            Spacer()

            // Clear button or chevron
            if let onClear = onClear {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.textMuted.opacity(0.5))
                    .onTapGesture {
                        onClear()
                    }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textMuted.opacity(0.4))
            }
        }
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    EditTaskSheet(
        task: FlowTask(name: "Morning workout", dueDate: Date()),
        taskStore: TaskStore(),
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore()
    )
}
