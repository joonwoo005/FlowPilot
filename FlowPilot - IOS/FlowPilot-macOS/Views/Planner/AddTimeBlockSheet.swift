import SwiftUI

// MARK: - Add Time Block Sheet (macOS)
struct AddTimeBlockSheet: View {
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    let targetDate: Date
    var editingBlock: TimeBlock? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPriority: Priority?
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var blockDate: Date
    @State private var selectedReminders: Set<Int> = []
    @State private var isRecurring = false
    @State private var selectedDays: Set<Int> = []
    @State private var showRecurringEditConfirmation = false

    private var isEditMode: Bool { editingBlock != nil }
    private var isEditingRecurringBlock: Bool { editingBlock?.isRecurring ?? false }

    init(priorityStore: OnboardingState, timeBlockStore: TimeBlockStore, targetDate: Date = Date(), editingBlock: TimeBlock? = nil) {
        self.priorityStore = priorityStore
        self.timeBlockStore = timeBlockStore
        self.targetDate = targetDate
        self.editingBlock = editingBlock

        if let block = editingBlock {
            _startTime = State(initialValue: block.startTime)
            _endTime = State(initialValue: block.endTime)
            _blockDate = State(initialValue: block.startTime)
        } else {
            let calendar = Calendar.current
            let existingBlocks = timeBlockStore.blocks(for: targetDate)
            let latestBlock = existingBlocks.max(by: { $0.endTime < $1.endTime })

            let startDate: Date
            if let latestBlock = latestBlock {
                startDate = latestBlock.endTime
            } else if calendar.isDateInToday(targetDate) {
                var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
                components.minute = 0
                startDate = calendar.date(from: components) ?? Date()
            } else {
                var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                components.hour = 9
                components.minute = 0
                startDate = calendar.date(from: components) ?? targetDate
            }

            _startTime = State(initialValue: startDate)
            _endTime = State(initialValue: startDate.addingTimeInterval(3600))
            _blockDate = State(initialValue: targetDate)
        }
    }

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
        let basicValid = selectedPriority != nil && endTime > startTime
        if isRecurring {
            return basicValid && !selectedDays.isEmpty
        }
        return basicValid
    }

    // MARK: - Remaining Hours Calculation
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

    private func hoursLeftForPriority(_ priority: Priority) -> Double {
        Double(remainingMinutesForPriority(priority)) / 60.0
    }

    private func formatHoursLeft(_ hours: Double) -> String {
        if hours == 0 {
            return "0h left"
        } else if hours == floor(hours) {
            return "\(Int(hours))h left"
        } else {
            return String(format: "%.1fh left", hours)
        }
    }

    var body: some View {
        ZStack {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(isEditMode ? "Edit Time Block" : "Add Time Block")
                        .font(Typography.headlineMedium)
                        .foregroundColor(.textPrimary)

                    Text(isEditMode ? "Modify block time and date" : "Schedule a new activity")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Priority Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("PRIORITY")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)

                        ForEach(priorityStore.priorities) { priority in
                            priorityRow(priority)
                        }
                    }

                    // Date Section (edit mode only)
                    if isEditMode {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("DATE")
                                .font(Typography.labelSmall)
                                .foregroundColor(.textMuted)

                            CustomDateInput(
                                date: Binding(
                                    get: { blockDate },
                                    set: { if let d = $0 { blockDate = d } }
                                ),
                                placeholder: "Select date",
                                accentColor: .accentPrimary,
                                allowClear: false
                            )
                        }
                    }

                    // Time Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("TIME")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)

                        HStack(spacing: Spacing.lg) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Start")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textMuted)

                                CustomTimeInput(
                                    time: $startTime,
                                    accentColor: .goldenGlow
                                )
                            }

                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("End")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textMuted)

                                CustomTimeInput(
                                    time: $endTime,
                                    accentColor: .purpleGlow
                                )
                            }
                        }

                        // Duration display
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "clock")
                                .foregroundColor(.textMuted)
                            Text("Duration: \(duration)")
                                .font(Typography.bodyMedium)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, Spacing.sm)
                    }

                    // Reminders Section
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("EARLY REMINDERS")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)

                        HStack(spacing: Spacing.sm) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                                reminderChip(minutes)
                            }
                        }
                    }

                    // Repeat Section (only in add mode)
                    if !isEditMode {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("REPEAT")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textMuted)

                                Spacer()

                                // Toggle
                                ZStack {
                                    Capsule()
                                        .fill(isRecurring ? Color.accentPrimary : Color.surfaceSecondary)
                                        .frame(width: 40, height: 22)

                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 18, height: 18)
                                        .offset(x: isRecurring ? 9 : -9)
                                }
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

                            if isRecurring {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    DaySelector(selectedDays: $selectedDays)

                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 11))
                                            .foregroundColor(.textMuted)

                                        Text("Creates blocks for next 12 weeks")
                                            .font(Typography.bodySmall)
                                            .foregroundColor(.textMuted)
                                    }
                                }
                                .padding(.top, Spacing.xs)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(Spacing.base)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.surfacePrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(Color.surfaceBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }

            Divider()

            // Action button
            HStack(spacing: Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.textSecondary)

                Spacer()

                Button {
                    saveBlock()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark")
                        Text(isEditMode ? "Save Changes" : "Add Block")
                    }
                    .foregroundColor(isValidBlock ? .white : .textMuted)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(isValidBlock ? Color.accentPrimary : Color.surfaceSecondary)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isValidBlock)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.lg)
        }
        .background(Color.backgroundSecondary)

            // Recurring edit confirmation overlay
            if showRecurringEditConfirmation {
                RecurringEditConfirmationOverlay(
                    block: editingBlock,
                    onCancel: {
                        withAnimation { showRecurringEditConfirmation = false }
                    },
                    onThisOneOnly: {
                        if let priority = selectedPriority {
                            performSave(priority: priority, updateAllFuture: false)
                        }
                    },
                    onAllFuture: {
                        if let priority = selectedPriority {
                            performSave(priority: priority, updateAllFuture: true)
                        }
                    }
                )
            }
        }
        .onAppear {
            if let block = editingBlock {
                selectedPriority = priorityStore.priorities.first { $0.id == block.priorityId }
                selectedReminders = Set(block.earlyReminders)
            }
        }
    }

    private func priorityRow(_ priority: Priority) -> some View {
        let isSelected = selectedPriority?.id == priority.id
        let hoursLeft = hoursLeftForPriority(priority)

        return HStack {
            Circle()
                .fill(priority.color)
                .frame(width: 10, height: 10)

            Text(priority.name)
                .font(Typography.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Text(formatHoursLeft(hoursLeft))
                .font(Typography.bodySmall)
                .foregroundColor(hoursLeft > 0 ? .textMuted : .accentError)

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentPrimary)
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSelected ? priority.color : Color.surfaceBorder, lineWidth: isSelected ? 2 : 1)
                )
        )
        .onTapGesture {
            Haptics.impact(.light)
            selectedPriority = priority
        }
    }

    private func reminderChip(_ minutes: Int) -> some View {
        let isSelected = selectedReminders.contains(minutes)
        let label = minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m"

        return Text(label)
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
            .onTapGesture {
                Haptics.impact(.light)
                if isSelected {
                    selectedReminders.remove(minutes)
                } else {
                    selectedReminders.insert(minutes)
                }
            }
    }

    private func saveBlock() {
        guard isValidBlock, let priority = selectedPriority else { return }

        // If editing a recurring block, show confirmation first
        if isEditMode && isEditingRecurringBlock {
            showRecurringEditConfirmation = true
            return
        }

        performSave(priority: priority, updateAllFuture: false)
    }

    private func performSave(priority: Priority, updateAllFuture: Bool) {
        // Normalize times (handle midnight end time)
        let normalizedStart = normalizeToBlockDate(startTime, isEndTime: false)
        let normalizedEnd = normalizeToBlockDate(endTime, isEndTime: true)

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
            let block = TimeBlock(
                priorityId: priority.id,
                priorityName: priority.name,
                priorityColor: priority.color,
                startTime: normalizedStart,
                endTime: normalizedEnd,
                earlyReminders: Array(selectedReminders)
            )
            timeBlockStore.addBlock(block)
            NotificationService.shared.scheduleTimeBlockNotifications(
                blockId: block.id,
                title: priority.name,
                startTime: normalizedStart,
                endTime: normalizedEnd,
                earlyReminderMinutes: Array(selectedReminders)
            )
        }

        Haptics.impact(.medium)
        dismiss()
    }

    /// Normalizes a time to the block date
    /// When isEndTime is true and the time is midnight (00:00), adds one day to represent end-of-day
    private func normalizeToBlockDate(_ date: Date, isEndTime: Bool = false) -> Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: date)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: blockDate)
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
}

// MARK: - Recurring Edit Confirmation Overlay (macOS)
struct RecurringEditConfirmationOverlay: View {
    let block: TimeBlock?
    let onCancel: () -> Void
    let onThisOneOnly: () -> Void
    let onAllFuture: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: Spacing.lg) {
                Image(systemName: "repeat")
                    .font(.system(size: 32))
                    .foregroundColor(.accentPrimary)

                VStack(spacing: Spacing.xs) {
                    Text("Edit Recurring Block")
                        .font(Typography.headlineSmall)
                        .foregroundColor(.textPrimary)

                    Text("This is part of a recurring series. Which blocks do you want to update?")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Spacing.sm) {
                    Button {
                        Haptics.impact(.medium)
                        onThisOneOnly()
                    } label: {
                        Text("This One Only")
                            .font(Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.accentPrimary)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.medium)
                        onAllFuture()
                    } label: {
                        Text("All Future")
                            .font(Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Color.accentPrimary, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Haptics.impact(.light)
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfaceSecondary)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 200)
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(Color.surfacePrimary)
            )
        }
    }
}

#Preview {
    AddTimeBlockSheet(
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore()
    )
    .frame(width: 500, height: 600)
}
