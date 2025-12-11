import SwiftUI

// MARK: - Add Task Sheet (macOS)
// Note: Shares SmartTextParser and DetectedComponents from iOS Views/Inbox/AddTaskSheet.swift
// Those types should be in Shared/ folder for cross-platform use

struct AddTaskSheet: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    var contextDate: Date? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var taskName = ""
    @State private var selectedDate: Date? = nil
    @State private var selectedTime: Date? = nil
    @State private var selectedPriority: Priority? = nil
    @State private var selectedBlock: TimeBlock? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.textSecondary)

                Spacer()

                Text("New Task")
                    .font(Typography.labelLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Add") {
                    addTask()
                }
                .buttonStyle(.plain)
                .foregroundColor(canAdd ? .accentPrimary : .textMuted)
                .disabled(!canAdd)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Task name input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("What do you need to do?")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        CustomTextField(
                            text: $taskName,
                            placeholder: "e.g. Review quarterly report",
                            axis: .vertical,
                            lineLimit: 3,
                            accentColor: .accentPrimary,
                            onSubmit: addTask
                        )
                    }

                    // Due Date
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Due Date")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        CustomDateInput(
                            date: $selectedDate,
                            placeholder: "Select date",
                            accentColor: .accentPrimary,
                            allowClear: true
                        )
                    }

                    // Time (optional)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Time (optional)")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        HStack(spacing: Spacing.md) {
                            CustomTimeInput(
                                time: Binding(
                                    get: { selectedTime ?? Date() },
                                    set: { selectedTime = $0 }
                                ),
                                accentColor: .accentPrimary
                            )

                            if selectedTime != nil {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textMuted)
                                    .onTapGesture {
                                        Haptics.impact(.light)
                                        selectedTime = nil
                                    }
                            }
                        }
                    }

                    // Priority
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Priority")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        HStack(spacing: Spacing.sm) {
                            ForEach(priorityStore.priorities) { priority in
                                priorityChip(priority)
                            }

                            if selectedPriority != nil {
                                Button {
                                    selectedPriority = nil
                                } label: {
                                    Text("Clear")
                                        .font(Typography.labelSmall)
                                        .foregroundColor(.textMuted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Time Block
                    if !timeBlockStore.timeBlocks.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Time Block")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            TimeBlockPicker(
                                selectedBlock: $selectedBlock,
                                blocks: availableBlocks,
                                placeholder: "Assign to block",
                                allowClear: true
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
            }

            Spacer()

            // Add button
            PrimaryButton(
                title: "Add Task",
                action: addTask,
                isEnabled: canAdd
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.backgroundSecondary)
        .onAppear {
            if let date = contextDate {
                selectedDate = date
            }
        }
        .onChange(of: selectedTime) { _, newTime in
            // Auto-set date when time is selected without a date
            if let time = newTime, selectedDate == nil, selectedBlock == nil {
                let calendar = Calendar.current
                let now = Date()
                let currentHour = calendar.component(.hour, from: now)
                let currentMinute = calendar.component(.minute, from: now)
                let selectedHour = calendar.component(.hour, from: time)
                let selectedMinute = calendar.component(.minute, from: time)

                // If time is after current time, use today; otherwise tomorrow
                let isTimeInFuture = (selectedHour > currentHour) || (selectedHour == currentHour && selectedMinute > currentMinute)
                let targetDate = isTimeInFuture ? calendar.startOfDay(for: now) : calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))

                selectedDate = targetDate
            }
        }
    }

    private var canAdd: Bool {
        !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var availableBlocks: [TimeBlock] {
        let now = Date()
        return timeBlockStore.timeBlocks
            .filter { $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    private func priorityChip(_ priority: Priority) -> some View {
        let isSelected = selectedPriority?.id == priority.id

        return HStack(spacing: Spacing.xs) {
            Circle()
                .fill(priority.color)
                .frame(width: 8, height: 8)

            Text(priority.name)
                .font(Typography.labelSmall)
        }
        .foregroundColor(isSelected ? .white : priority.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(isSelected ? priority.color : priority.color.opacity(0.1))
        )
        .onTapGesture {
            Haptics.impact(.light)
            selectedPriority = isSelected ? nil : priority
        }
    }

    private func addTask() {
        let name = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Get date and time separately
        let finalDate = selectedDate
        let finalTime: DueTime? = selectedTime.map { time in
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: time)
            let minute = calendar.component(.minute, from: time)
            return DueTime(hour: hour, minute: minute)
        }

        taskStore.addTask(
            name: name,
            dueDate: finalDate,
            dueTime: finalTime,
            priority: selectedPriority,
            timeBlockId: selectedBlock?.id
        )

        Haptics.impact(.medium)
        dismiss()
    }
}

#Preview {
    AddTaskSheet(
        taskStore: TaskStore(),
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore()
    )
    .frame(width: 450, height: 500)
}
