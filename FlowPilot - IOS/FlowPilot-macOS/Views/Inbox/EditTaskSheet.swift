import SwiftUI

// MARK: - Edit Task Sheet (macOS)
struct EditTaskSheet: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Environment(\.dismiss) private var dismiss

    @State private var taskName: String = ""
    @State private var selectedDate: Date? = nil
    @State private var selectedTime: Date? = nil
    @State private var selectedPriority: Priority? = nil
    @State private var selectedBlock: TimeBlock? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(role: .destructive) {
                    taskStore.deleteTask(task)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.accentError)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Edit Task")
                    .font(Typography.labelLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Save") {
                    saveChanges()
                }
                .buttonStyle(.plain)
                .foregroundColor(hasChanges ? .accentPrimary : .textMuted)
                .disabled(!hasChanges)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Task name input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Task Name")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        CustomTextField(
                            text: $taskName,
                            placeholder: "Task name",
                            axis: .vertical,
                            lineLimit: 3,
                            accentColor: .accentPrimary
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

                    // Priority & Time (same row)
                    HStack(alignment: .top, spacing: Spacing.xl) {
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

                        // Time
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Time")
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

            // Action buttons
            HStack(spacing: Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfaceSecondary)
                )

                Spacer()

                PrimaryButton(
                    title: "Save Changes",
                    action: saveChanges,
                    isEnabled: hasChanges && !taskName.isEmpty
                )
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.backgroundSecondary)
        .onAppear {
            taskName = task.name
            selectedDate = task.dueDate
            selectedPriority = task.priority

            // Load time from separate dueTime field
            if let time = task.dueTime {
                // Create a Date from the time for the CustomTimeInput
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = time.hour
                components.minute = time.minute
                selectedTime = calendar.date(from: components)
            }

            // Find linked block
            if let blockId = task.timeBlockId {
                selectedBlock = timeBlockStore.timeBlocks.first { $0.id == blockId }
            }
        }
    }

    private var hasChanges: Bool {
        let currentTime: DueTime? = selectedTime.map { time in
            let calendar = Calendar.current
            return DueTime(hour: calendar.component(.hour, from: time), minute: calendar.component(.minute, from: time))
        }
        return taskName != task.name ||
            selectedDate != task.dueDate ||
            currentTime != task.dueTime ||
            selectedPriority?.id != task.priority?.id ||
            selectedBlock?.id != task.timeBlockId
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

    private func saveChanges() {
        var updatedTask = task
        updatedTask.name = taskName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get date and time separately
        updatedTask.dueDate = selectedDate
        updatedTask.dueTime = selectedTime.map { time in
            let calendar = Calendar.current
            return DueTime(hour: calendar.component(.hour, from: time), minute: calendar.component(.minute, from: time))
        }
        updatedTask.priority = selectedPriority
        updatedTask.timeBlockId = selectedBlock?.id

        taskStore.updateTask(updatedTask)
        Haptics.notification(.success)
        dismiss()
    }
}

#Preview {
    EditTaskSheet(
        task: FlowTask(name: "Review quarterly report", dueDate: Date()),
        taskStore: TaskStore(),
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore()
    )
    .frame(width: 450, height: 500)
}
