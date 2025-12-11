import SwiftUI

// MARK: - Block Conflict
enum BlockConflict: Equatable {
    case overlapsWithBlock(blockName: String, blockTime: String, overlapMinutes: Int)
    case beforeWakeTime(wakeTime: String, overlapMinutes: Int)
    case afterSleepTime(sleepTime: String, overlapMinutes: Int)
    case exceedsAllocation(priorityName: String, blockDuration: String, remaining: String, exceededBy: String)

    var message: String {
        switch self {
        case .overlapsWithBlock(let name, let time, let minutes):
            return "Overlaps with \"\(name)\" (\(time)) by \(formatMinutes(minutes))"
        case .beforeWakeTime(let wake, let minutes):
            return "Starts \(formatMinutes(minutes)) before wake time (\(wake))"
        case .afterSleepTime(let sleep, let minutes):
            return "Extends \(formatMinutes(minutes)) past sleep time (\(sleep))"
        case .exceedsAllocation(let name, let duration, let remaining, let exceeded):
            return "\(duration) block exceeds \"\(name)\" remaining time (\(remaining)) by \(exceeded)"
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Add Time Block Sheet
struct AddTimeBlockSheet: View {
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    let targetDate: Date // Date to create/edit block for
    var editingBlock: TimeBlock? = nil  // Block being edited (nil = add mode)
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPriority: Priority?
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var blockDate: Date  // The date for the block (editable in edit mode)

    private var isEditMode: Bool { editingBlock != nil }
    private var isEditingRecurringBlock: Bool { editingBlock?.isRecurring ?? false }

    init(priorityStore: OnboardingState, timeBlockStore: TimeBlockStore, targetDate: Date = Date(), editingBlock: TimeBlock? = nil) {
        self.priorityStore = priorityStore
        self.timeBlockStore = timeBlockStore
        self.targetDate = targetDate
        self.editingBlock = editingBlock

        // If editing, use the existing block's values
        if let block = editingBlock {
            _startTime = State(initialValue: block.startTime)
            _endTime = State(initialValue: block.endTime)
            _blockDate = State(initialValue: block.startTime)
            // selectedPriority will be set in onAppear
        } else {
            // Initialize times for the target date (add mode)
            let calendar = Calendar.current
            let now = Date()

            // Check for existing blocks on the target date
            let existingBlocks = timeBlockStore.blocks(for: targetDate)
            let latestBlock = existingBlocks.max(by: { $0.endTime < $1.endTime })

            let startDate: Date
            if let latestBlock = latestBlock {
                // Start at the end of the latest block
                startDate = latestBlock.endTime
            } else if calendar.isDateInToday(targetDate) {
                // No blocks today - use current hour
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
                components.minute = 0
                startDate = calendar.date(from: components) ?? now
            } else {
                // No blocks on future/past date - use 9 AM
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = 9
                components.minute = 0
                startDate = calendar.date(from: components) ?? targetDate
            }

            // End time is 1 hour after start
            let endDate = startDate.addingTimeInterval(3600)

            _startTime = State(initialValue: startDate)
            _endTime = State(initialValue: endDate)
            _blockDate = State(initialValue: targetDate)
        }
    }

    @State private var showEarlyReminders = true
    @State private var selectedReminders: Set<Int> = []
    @State private var customReminderText: String = ""

    @State private var isEditingStartTime = false
    @State private var isEditingEndTime = false
    @State private var isEditingDate = false

    // Recurring block state
    @State private var isRecurring = false
    @State private var selectedDays: Set<Int> = []

    // Recurring edit confirmation
    @State private var showRecurringEditConfirmation = false

    private let reminderOptions = [5, 10, 15, 30, 60]

    private var duration: String {
        let interval = endTime.timeIntervalSince(startTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private var isValidBlock: Bool {
        let basicValid = selectedPriority != nil && endTime > startTime && conflicts.isEmpty
        // If recurring mode is on, require at least one day selected
        if isRecurring {
            return basicValid && !selectedDays.isEmpty
        }
        return basicValid
    }

    // MARK: - Conflict Detection
    private var conflicts: [BlockConflict] {
        var result: [BlockConflict] = []

        let normalizedStart = normalizeToTargetDate(startTime, isEndTime: false)
        let normalizedEnd = normalizeToTargetDate(endTime, isEndTime: true)

        // Check for conflicts with existing blocks on the effective date
        // Exclude the editing block from overlap checks
        for block in timeBlockStore.blocks(for: effectiveDate) {
            // Skip the block being edited
            if let editingBlock = editingBlock, block.id == editingBlock.id {
                continue
            }

            if let overlap = calculateOverlap(
                start1: normalizedStart, end1: normalizedEnd,
                start2: block.startTime, end2: block.endTime
            ) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                let blockTime = "\(timeFormatter.string(from: block.startTime)) - \(timeFormatter.string(from: block.endTime))"

                result.append(.overlapsWithBlock(
                    blockName: block.priorityName,
                    blockTime: blockTime,
                    overlapMinutes: overlap
                ))
            }
        }

        // Check for sleep schedule conflicts
        let sleepSchedule = priorityStore.sleepSchedule
        let calendar = Calendar.current

        // Get wake and sleep times for the effective date
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: sleepSchedule.wakeTime)
        let sleepComponents = calendar.dateComponents([.hour, .minute], from: sleepSchedule.sleepTime)

        let wakeOnTarget = calendar.date(bySettingHour: wakeComponents.hour ?? 7, minute: wakeComponents.minute ?? 0, second: 0, of: effectiveDate)!
        let sleepOnTarget = calendar.date(bySettingHour: sleepComponents.hour ?? 23, minute: sleepComponents.minute ?? 0, second: 0, of: effectiveDate)!

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        // Check if start time is before wake time
        if normalizedStart < wakeOnTarget {
            let overlapMinutes = Int(wakeOnTarget.timeIntervalSince(normalizedStart) / 60)
            result.append(.beforeWakeTime(
                wakeTime: timeFormatter.string(from: wakeOnTarget),
                overlapMinutes: overlapMinutes
            ))
        }

        // Check if end time is after sleep time
        if normalizedEnd > sleepOnTarget {
            let overlapMinutes = Int(normalizedEnd.timeIntervalSince(sleepOnTarget) / 60)
            result.append(.afterSleepTime(
                sleepTime: timeFormatter.string(from: sleepOnTarget),
                overlapMinutes: overlapMinutes
            ))
        }

        // Check if block duration exceeds remaining allocation for priority
        if let priority = selectedPriority {
            let blockDurationMinutes = Int(normalizedEnd.timeIntervalSince(normalizedStart) / 60)
            var remainingMinutes = remainingMinutesForPriority(priority)

            // In edit mode, add back the original block's duration to remaining
            if let editingBlock = editingBlock, editingBlock.priorityId == priority.id {
                remainingMinutes += editingBlock.durationInMinutes
            }

            if blockDurationMinutes > remainingMinutes {
                let exceededByMinutes = blockDurationMinutes - remainingMinutes
                result.append(.exceedsAllocation(
                    priorityName: priority.name,
                    blockDuration: formatDuration(minutes: blockDurationMinutes),
                    remaining: formatDuration(minutes: remainingMinutes),
                    exceededBy: formatDuration(minutes: exceededByMinutes)
                ))
            }
        }

        return result
    }

    private func formatDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }

    private func remainingMinutesForPriority(_ priority: Priority) -> Int {
        // Weekly allocation in minutes
        let weeklyAllocationMinutes = Int(priority.hoursPerWeek * 60)
        let weekStart = targetDate.startOfWeek()
        let weekEnd = targetDate.endOfWeek()

        // Already scheduled this week for this priority
        let scheduledThisWeekMinutes = timeBlockStore.timeBlocks
            .filter { $0.priorityId == priority.id && $0.startTime >= weekStart && $0.startTime < weekEnd }
            .reduce(0) { $0 + $1.durationInMinutes }

        return max(0, weeklyAllocationMinutes - scheduledThisWeekMinutes)
    }

    private func calculateOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> Int? {
        // Check if ranges overlap
        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)

        if overlapStart < overlapEnd {
            return Int(overlapEnd.timeIntervalSince(overlapStart) / 60)
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        // Priority Section
                        prioritySection

                        // Date Section (only in edit mode)
                        if isEditMode {
                            dateSelectionSection
                        }

                        // Time Selection
                        timeSelectionSection

                        // Duration Display
                        durationView

                        // Repeat Section (only in add mode)
                        if !isEditMode {
                            repeatSection
                        }

                        // Conflict Warnings
                        if !conflicts.isEmpty {
                            conflictWarningsView
                        }

                        // Early Reminders
                        earlyRemindersSection
                    }
                    .padding(.horizontal, Spacing.base)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                }
                .frame(maxHeight: .infinity)

                // Add Block Button
                addBlockButton
            }

            // Recurring edit confirmation overlay
            if showRecurringEditConfirmation {
                RecurringEditConfirmationOverlay(
                    block: editingBlock,
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRecurringEditConfirmation = false
                        }
                    },
                    onThisOneOnly: {
                        if let priority = selectedPriority {
                            saveBlock(priority: priority, updateAllFuture: false)
                        }
                    },
                    onAllFuture: {
                        if let priority = selectedPriority {
                            saveBlock(priority: priority, updateAllFuture: true)
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            // Request notification permission
            NotificationService.shared.requestPermission { _ in }

            // Set values when editing
            if let block = editingBlock {
                selectedPriority = priorityStore.priorities.first { $0.id == block.priorityId }
                selectedReminders = Set(block.earlyReminders)
            }
        }
        .onChange(of: isEditingStartTime) { _, isEditing in
            if isEditing { isEditingDate = false }
        }
        .onChange(of: isEditingEndTime) { _, isEditing in
            if isEditing { isEditingDate = false }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(isEditMode ? "Edit Time Block" : "Add Time Block")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text(isEditMode ? "Modify block time and date" : "Schedule a new activity")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.surfaceSecondary)
                )
                .onTapGesture {
                    Haptics.impact(.light)
                    dismiss()
                }
        }
        .padding(.horizontal, Spacing.base)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Priority Section
    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("PRIORITY")
                .font(Typography.labelSmall)
                .foregroundColor(.textMuted)
                .tracking(1)

            VStack(spacing: Spacing.sm) {
                ForEach(priorityStore.priorities) { priority in
                    TimeBlockPriorityRow(
                        priority: priority,
                        hoursLeft: hoursLeftForPriority(priority),
                        isSelected: selectedPriority?.id == priority.id,
                        targetDate: targetDate,
                        onTap: {
                            Haptics.impact(.light)
                            selectedPriority = priority
                        }
                    )
                }
            }
        }
    }

    /// The effective date for the block (uses blockDate in edit mode, targetDate in add mode)
    private var effectiveDate: Date {
        isEditMode ? blockDate : targetDate
    }

    /// Takes a Date and returns a new Date with the effective date's year/month/day but the same hour/minute
    /// When isEndTime is true and the time is midnight (00:00), adds one day to represent end-of-day
    private func normalizeToTargetDate(_ date: Date, isEndTime: Bool = false) -> Date {
        let calendar = Calendar.current

        // Get time components from the input date
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)

        // Get date components from effective date (blockDate in edit mode, targetDate in add mode)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: effectiveDate)

        // Combine effective date with the time from input
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = 0

        guard let normalizedDate = calendar.date(from: dateComponents) else { return date }

        // If this is an end time and it's midnight (00:00), it represents end of day
        // Add one day to make it midnight after the target date
        if isEndTime && timeComponents.hour == 0 && timeComponents.minute == 0 {
            return calendar.date(byAdding: .day, value: 1, to: normalizedDate) ?? normalizedDate
        }

        return normalizedDate
    }

    private func hoursLeftForPriority(_ priority: Priority) -> Double {
        Double(remainingMinutesForPriority(priority)) / 60.0
    }

    // MARK: - Date Selection Section (Edit Mode)
    private var dateSelectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DATE")
                .font(Typography.labelSmall)
                .foregroundColor(.textMuted)
                .tracking(1)

            VStack(spacing: Spacing.sm) {
                // Date display button
                HStack {
                    Text(formattedBlockDate)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.base)
                .padding(.vertical, Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(isEditingDate ? Color.accentPrimary : Color.surfaceBorder, lineWidth: isEditingDate ? 2 : 1)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    isEditingStartTime = false
                    isEditingEndTime = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isEditingDate.toggle()
                    }
                }

                // Expandable date picker
                if isEditingDate {
                    DatePicker("", selection: $blockDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var formattedBlockDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: blockDate)
    }

    // MARK: - Time Selection Section
    private var timeSelectionSection: some View {
        VStack(spacing: Spacing.md) {
            // Time range display row
            HStack(spacing: 0) {
                // Start Time Display
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("START")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                        .tracking(1)

                    HStack(spacing: 4) {
                        Text(formatTimeDisplay(startTime))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(.textPrimary)

                        Text(formatPeriod(startTime))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isEditingStartTime ? .accentPrimary : .textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(isEditingStartTime ? Color.accentPrimary.opacity(0.08) : Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(isEditingStartTime ? Color.accentPrimary : Color.surfaceBorder, lineWidth: isEditingStartTime ? 2 : 1)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if isEditingStartTime {
                            isEditingStartTime = false
                        } else {
                            isEditingStartTime = true
                            isEditingEndTime = false
                            isEditingDate = false
                        }
                    }
                }

                // Arrow connector
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textMuted)
                    .frame(width: 40)

                // End Time Display
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("END")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                        .tracking(1)

                    HStack(spacing: 4) {
                        Text(formatTimeDisplay(endTime))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .foregroundColor(.textPrimary)

                        Text(formatPeriod(endTime))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isEditingEndTime ? .accentPrimary : .textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(isEditingEndTime ? Color.accentPrimary.opacity(0.08) : Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(isEditingEndTime ? Color.accentPrimary : Color.surfaceBorder, lineWidth: isEditingEndTime ? 2 : 1)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if isEditingEndTime {
                            isEditingEndTime = false
                        } else {
                            isEditingEndTime = true
                            isEditingStartTime = false
                            isEditingDate = false
                        }
                    }
                }
            }

            // Full-width time picker (shown below both time displays)
            if isEditingStartTime || isEditingEndTime {
                DatePicker(
                    "",
                    selection: isEditingStartTime ? $startTime : $endTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 150)
                .clipped()
                .padding(Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(Color.surfaceBorder, lineWidth: 1)
                        )
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }

    private func formatTimeDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }

    private func formatPeriod(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }

    // MARK: - Duration View
    private var durationView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "clock")
                .font(.system(size: 16))
                .foregroundColor(.textMuted)

            Text("Duration:")
                .font(Typography.bodyMedium)
                .foregroundColor(.textSecondary)

            Text(duration)
                .font(Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Repeat Section
    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with toggle
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentWarm.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "repeat")
                        .font(.system(size: 14))
                        .foregroundColor(.accentWarm)
                }

                Text("Repeat")
                    .font(Typography.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Toggle
                ZStack {
                    Capsule()
                        .fill(isRecurring ? Color.accentPrimary : Color.surfaceSecondary)
                        .frame(width: 48, height: 28)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                        .offset(x: isRecurring ? 10 : -10)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isRecurring.toggle()
                        if !isRecurring {
                            selectedDays.removeAll()
                        }
                    }
                }
            }

            // Day selector (shown when recurring is enabled)
            if isRecurring {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("REPEAT ON")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                        .tracking(0.5)

                    DaySelector(selectedDays: $selectedDays)

                    // Helper text
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.textMuted)

                        Text("Creates blocks for next 12 weeks")
                            .font(Typography.bodySmall)
                            .foregroundColor(.textMuted)
                    }
                    .padding(.top, Spacing.xs)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Conflict Warnings View
    private var conflictWarningsView: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: conflictIcon(for: conflict))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentError)

                    Text(conflict.message)
                        .font(Typography.bodySmall)
                        .foregroundColor(.accentError)

                    Spacer()
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(Color.accentError.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .stroke(Color.accentError.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func conflictIcon(for conflict: BlockConflict) -> String {
        switch conflict {
        case .overlapsWithBlock:
            return "calendar.badge.exclamationmark"
        case .beforeWakeTime:
            return "sunrise.fill"
        case .afterSleepTime:
            return "moon.fill"
        case .exceedsAllocation:
            return "hourglass.bottomhalf.filled"
        }
    }

    // MARK: - Early Reminders Section
    private var earlyRemindersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentPrimary)
                }

                Text("Early Reminders")
                    .font(Typography.bodyLarge)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.surfaceSecondary)
                        .frame(width: 28, height: 28)

                    Image(systemName: showEarlyReminders ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showEarlyReminders.toggle()
                }
            }

            if showEarlyReminders {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Helper text with subtle styling
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.accentSuccess.opacity(0.7))

                        Text("You'll always be notified when the block starts")
                            .font(Typography.bodySmall)
                            .foregroundColor(.textMuted)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.accentSuccess.opacity(0.08))
                    )

                    // Reminder chips section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("REMIND ME BEFORE")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)
                            .tracking(0.5)

                        FlowLayout(spacing: Spacing.sm) {
                            ForEach(reminderOptions, id: \.self) { minutes in
                                ReminderChip(
                                    minutes: minutes,
                                    isSelected: selectedReminders.contains(minutes),
                                    onTap: {
                                        Haptics.impact(.light)
                                        if selectedReminders.contains(minutes) {
                                            selectedReminders.remove(minutes)
                                        } else {
                                            selectedReminders.insert(minutes)
                                        }
                                    }
                                )
                            }

                            // Show custom reminders as chips
                            ForEach(Array(selectedReminders.filter { !reminderOptions.contains($0) }).sorted(), id: \.self) { minutes in
                                CustomReminderChip(
                                    minutes: minutes,
                                    onRemove: {
                                        Haptics.impact(.light)
                                        selectedReminders.remove(minutes)
                                    }
                                )
                            }
                        }
                    }

                    // Custom reminder input with inline add
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("ADD CUSTOM")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)
                            .tracking(0.5)

                        HStack(spacing: Spacing.sm) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textMuted)

                                TextField("", text: $customReminderText)
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(.textPrimary)
                                    .keyboardType(.numberPad)
                                    .placeholder(when: customReminderText.isEmpty) {
                                        Text("e.g. 45")
                                            .font(Typography.bodyMedium)
                                            .foregroundColor(.textMuted.opacity(0.5))
                                    }

                                Text("min")
                                    .font(Typography.bodySmall)
                                    .foregroundColor(.textMuted)
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm + 2)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfaceSecondary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(customReminderText.isEmpty ? Color.surfaceBorder : Color.accentPrimary.opacity(0.5), lineWidth: 1)
                                    )
                            )

                            // Add button - only visible when there's input
                            if !customReminderText.isEmpty {
                                Text("Add")
                                    .font(Typography.labelMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.vertical, Spacing.sm + 2)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentPrimary)
                                    )
                                    .onTapGesture {
                                        if let minutes = Int(customReminderText), minutes > 0 {
                                            Haptics.impact(.light)
                                            selectedReminders.insert(minutes)
                                            customReminderText = ""
                                        }
                                    }
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: customReminderText.isEmpty)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Add/Save Block Button
    private var addBlockButton: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))

            Text(isEditMode ? "Save Changes" : "Add Block")
                .font(Typography.bodyLarge)
                .fontWeight(.semibold)
        }
        .foregroundColor(isValidBlock ? .white : .textMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(isValidBlock ? Color.accentPrimary : Color.surfaceSecondary)
        )
        .padding(.horizontal, Spacing.base)
        .padding(.bottom, Spacing.xl)
        .onTapGesture {
            guard isValidBlock, let priority = selectedPriority else { return }
            Haptics.impact(.medium)

            // If editing a recurring block, show confirmation first
            if isEditMode && isEditingRecurringBlock {
                showRecurringEditConfirmation = true
                return
            }

            saveBlock(priority: priority, updateAllFuture: false)
        }
    }

    /// Save the block (single or all future recurring)
    private func saveBlock(priority: Priority, updateAllFuture: Bool) {
        // Normalize times to the effective date (handle midnight end time)
        let normalizedStart = normalizeToTargetDate(startTime, isEndTime: false)
        let normalizedEnd = normalizeToTargetDate(endTime, isEndTime: true)

        if isEditMode, let existingBlock = editingBlock {
            if updateAllFuture && existingBlock.isRecurring {
                // Update all future recurring blocks
                timeBlockStore.updateFutureRecurringBlocks(
                    from: existingBlock,
                    newPriorityId: priority.id,
                    newPriorityName: priority.name,
                    newPriorityColor: priority.color,
                    newStartTime: normalizedStart,
                    newEndTime: normalizedEnd,
                    newEarlyReminders: Array(selectedReminders)
                )
            } else {
                // Update only this block
                var updatedBlock = TimeBlock(
                    id: existingBlock.id,
                    priorityId: priority.id,
                    priorityName: priority.name,
                    priorityColor: priority.color,
                    startTime: normalizedStart,
                    endTime: normalizedEnd,
                    earlyReminders: Array(selectedReminders),
                    createdAt: existingBlock.createdAt
                )
                // Clear recurrence info when editing only this one
                if existingBlock.isRecurring {
                    updatedBlock.recurrenceId = nil
                    updatedBlock.recurringDays = nil
                }
                timeBlockStore.updateBlock(updatedBlock)

                // Cancel old notifications and schedule new ones
                NotificationService.shared.cancelTimeBlockNotifications(blockId: existingBlock.id)
                NotificationService.shared.scheduleTimeBlockNotifications(
                    blockId: updatedBlock.id,
                    title: priority.name,
                    startTime: normalizedStart,
                    endTime: normalizedEnd,
                    earlyReminderMinutes: Array(selectedReminders)
                )
            }
        } else if isRecurring && !selectedDays.isEmpty {
            // Create recurring blocks (notifications handled inside addRecurringBlock)
            timeBlockStore.addRecurringBlock(
                priority: priority,
                startTime: normalizedStart,
                endTime: normalizedEnd,
                earlyReminders: Array(selectedReminders),
                recurringDays: selectedDays
            )
        } else {
            // Create single new block
            let block = TimeBlock(
                priorityId: priority.id,
                priorityName: priority.name,
                priorityColor: priority.color,
                startTime: normalizedStart,
                endTime: normalizedEnd,
                earlyReminders: Array(selectedReminders)
            )
            timeBlockStore.addBlock(block)

            // Schedule notifications
            NotificationService.shared.scheduleTimeBlockNotifications(
                blockId: block.id,
                title: priority.name,
                startTime: normalizedStart,
                endTime: normalizedEnd,
                earlyReminderMinutes: Array(selectedReminders)
            )
        }

        dismiss()
    }
}

// MARK: - Recurring Edit Confirmation Overlay
struct RecurringEditConfirmationOverlay: View {
    let block: TimeBlock?
    let onCancel: () -> Void
    let onThisOneOnly: () -> Void
    let onAllFuture: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    Haptics.impact(.light)
                    onCancel()
                }

            // Confirmation card
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Spacing.lg) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "repeat")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.accentPrimary)
                    }

                    // Text
                    VStack(spacing: Spacing.xs) {
                        Text("Edit Recurring Block")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        Text("This is part of a recurring series. Which blocks do you want to update?")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Buttons
                    VStack(spacing: Spacing.sm) {
                        // This one only
                        Text("This One Only")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.accentPrimary)
                            )
                            .onTapGesture {
                                Haptics.impact(.medium)
                                onThisOneOnly()
                            }

                        // All future
                        Text("All Future")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.accentPrimary, lineWidth: 1.5)
                            )
                            .onTapGesture {
                                Haptics.impact(.medium)
                                onAllFuture()
                            }

                        // Cancel button
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfaceSecondary)
                            )
                            .onTapGesture {
                                Haptics.impact(.light)
                                onCancel()
                            }
                    }
                }
                .padding(Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(Color.surfacePrimary)
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
                .offset(y: showContent ? 0 : 300)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}

// MARK: - Time Block Priority Row
struct TimeBlockPriorityRow: View {
    let priority: Priority
    let hoursLeft: Double
    let isSelected: Bool
    let targetDate: Date
    let onTap: () -> Void

    /// Determine the week label based on targetDate relative to today
    private var weekLabel: String {
        let calendar = Calendar.current
        let todayWeekStart = Date().startOfWeek()
        let targetWeekStart = targetDate.startOfWeek()

        // Calculate weeks difference using days (more reliable than weekOfYear)
        let daysDiff = calendar.dateComponents([.day], from: todayWeekStart, to: targetWeekStart).day ?? 0
        let weeksDiff = daysDiff / 7

        switch weeksDiff {
        case 0:
            return "this week"
        case 1:
            return "next week"
        case -1:
            return "last week"
        default:
            // Show the week's date range for other weeks
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: targetWeekStart) ?? targetWeekStart
            return "\(formatter.string(from: targetWeekStart))-\(formatter.string(from: weekEnd))"
        }
    }

    private var hoursLeftText: String {
        let totalMinutes = Int(hoursLeft * 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)hr \(minutes)m \(weekLabel)"
        } else if hours > 0 {
            return "\(hours)hr \(weekLabel)"
        } else {
            return "\(minutes)m \(weekLabel)"
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(priority.color)
                .frame(width: 10, height: 10)

            Text(priority.name)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)

            Spacer()

            Text(hoursLeftText)
                .font(Typography.bodySmall)
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSelected ? priority.color : Color.surfaceBorder, lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Reminder Chip
struct ReminderChip: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var label: String {
        if minutes >= 60 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        Text(label)
            .font(Typography.labelMedium)
            .foregroundColor(isSelected ? .accentPrimary : .textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.accentPrimary.opacity(0.15) : Color.surfaceSecondary)
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 1)
                    )
            )
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
    }
}

// MARK: - Custom Reminder Chip (with remove button)
struct CustomReminderChip: View {
    let minutes: Int
    let onRemove: () -> Void

    private var label: String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(Typography.labelMedium)
                .foregroundColor(.accentWarm)

            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.accentWarm.opacity(0.7))
        }
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(Color.accentWarm.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(Color.accentWarm.opacity(0.5), lineWidth: 1)
                )
        )
        .contentShape(Capsule())
        .onTapGesture(perform: onRemove)
    }
}

#Preview {
    AddTimeBlockSheet(
        priorityStore: {
            let state = OnboardingState()
            state.priorities = [
                Priority(id: UUID(), name: "School", color: .priorityGreen, hoursPerWeek: 35),
                Priority(id: UUID(), name: "Work", color: .priorityCyan, hoursPerWeek: 35)
            ]
            return state
        }(),
        timeBlockStore: TimeBlockStore()
    )
}
