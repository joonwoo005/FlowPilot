import SwiftUI

// MARK: - Priority Section View
struct PrioritySectionView: View {
    let priority: Priority
    let tasks: [FlowTask]
    @ObservedObject var taskStore: TaskStore
    @Binding var taskToDelete: FlowTask?
    var onEditTask: ((FlowTask) -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                HStack(spacing: Spacing.sm) {
                    // Priority color indicator
                    Circle()
                        .fill(priority.color)
                        .frame(width: 10, height: 10)

                    Text(priority.name)
                        .font(Typography.labelLarge)
                        .foregroundColor(.textPrimary)

                    Text("(\(tasks.count))")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                // Hours allocation badge
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(Int(priority.hoursPerWeek))h/wk")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(priority.color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(priority.color.opacity(0.12))
                )

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .padding(.leading, Spacing.sm)
            }
            .padding(Spacing.base)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            // Tasks list
            if isExpanded {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(height: 1)

                    if tasks.isEmpty {
                        // Empty state
                        HStack {
                            Text("No tasks in this priority")
                                .font(Typography.bodySmall)
                                .foregroundColor(.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.base)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(tasks) { task in
                                BrowseTaskRow(
                                    task: task,
                                    taskStore: taskStore,
                                    taskToDelete: $taskToDelete,
                                    onEdit: { onEditTask?(task) }
                                )

                                if task.id != tasks.last?.id {
                                    Rectangle()
                                        .fill(Color.surfaceBorder.opacity(0.5))
                                        .frame(height: 1)
                                        .padding(.leading, Spacing.xxxl)
                                }
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Browse Task Row (Simplified for Browse view)
struct BrowseTaskRow: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore
    @Binding var taskToDelete: FlowTask?
    var onEdit: (() -> Void)? = nil

    @State private var isPendingCompletion = false
    @State private var strikethroughProgress: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var completionTimer: DispatchWorkItem?

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Checkbox
            checkboxView

            // Task content
            VStack(alignment: .leading, spacing: 2) {
                AnimatedStrikethroughText(
                    text: task.name,
                    progress: task.isCompleted ? 1 : strikethroughProgress,
                    textColor: (isPendingCompletion || task.isCompleted) ? .textMuted : .textPrimary,
                    strikeColor: .textMuted
                )
                .lineLimit(2)

                // Due date
                if let displayLabel = task.displayDueLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(displayLabel)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(task.dueStatus.color)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !task.isCompleted else { return }
                Haptics.impact(.light)
                onEdit?()
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .opacity(task.isCompleted ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
        .onLongPressGesture(minimumDuration: 0.5) {
            Haptics.impact(.medium)
            taskToDelete = task
        }
    }

    private var checkboxView: some View {
        ZStack {
            Circle()
                .stroke(task.dueStatus.color, lineWidth: 2)
                .frame(width: 26, height: 26)
                .opacity(isPendingCompletion || task.isCompleted ? 0 : 1)

            Circle()
                .fill(Color.accentSuccess)
                .frame(width: 26, height: 26)
                .opacity(isPendingCompletion || task.isCompleted ? 1 : 0)
                .scaleEffect(isPendingCompletion || task.isCompleted ? 1 : 0.5)

            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkScale > 0 ? 1 : 0)
        }
        .contentShape(Circle())
        .onTapGesture {
            handleCheckboxTap()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPendingCompletion)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: checkmarkScale)
    }

    private func handleCheckboxTap() {
        if task.isCompleted {
            Haptics.impact(.light)
            taskStore.uncompleteTask(task)
            return
        }

        if isPendingCompletion {
            Haptics.impact(.light)
            cancelPendingCompletion()
        } else {
            Haptics.impact(.medium)
            startPendingCompletion()
        }
    }

    private func startPendingCompletion() {
        isPendingCompletion = true
        SoundService.shared.playCompletionSound()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            checkmarkScale = 1
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            strikethroughProgress = 1
        }

        let workItem = DispatchWorkItem { [self] in
            completeTask()
        }
        completionTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func cancelPendingCompletion() {
        completionTimer?.cancel()
        completionTimer = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            checkmarkScale = 0
            isPendingCompletion = false
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            strikethroughProgress = 0
        }
    }

    private func completeTask() {
        taskStore.completeTask(task)
        isPendingCompletion = false
        strikethroughProgress = 0
        checkmarkScale = 0
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack {
            PrioritySectionView(
                priority: Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 10),
                tasks: [
                    FlowTask(name: "Morning workout"),
                    FlowTask(name: "Meal prep", dueDate: Date())
                ],
                taskStore: TaskStore(),
                taskToDelete: .constant(nil)
            )
        }
        .padding()
    }
}
