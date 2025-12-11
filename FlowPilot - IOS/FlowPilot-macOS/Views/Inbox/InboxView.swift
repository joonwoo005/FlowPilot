import SwiftUI

// MARK: - Inbox View (macOS)
struct InboxView: View {
    @ObservedObject var taskStore: TaskStore
    @Binding var showAddTask: Bool
    @Binding var taskToEdit: FlowTask?
    @Binding var addTaskContextDate: Date?

    @State private var showActivityLog = false
    @State private var activityFilter: TaskStore.ActivityFilter = .all
    @State private var taskToDelete: FlowTask? = nil

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ContentOrbitalBackground()

            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    // Header with title and controls
                    HStack(alignment: .center) {
                        Text("Inbox")
                            .font(Typography.displayMedium)
                            .foregroundColor(.white)

                        Spacer()

                        HStack(spacing: Spacing.md) {
                            activityLogButton
                            activeTasksCounter
                        }
                    }
                    .padding(.bottom, Spacing.md)

                    // Day-based sections
                    ForEach(taskStore.tasksByDay) { section in
                        TaskSection(
                            title: section.title,
                            titleColor: section.color,
                            tasks: section.tasks,
                            taskStore: taskStore,
                            onAddTask: {
                                addTaskContextDate = section.date
                                showAddTask = true
                            },
                            onEditTask: { task in taskToEdit = task },
                            date: section.date,
                            taskToDelete: $taskToDelete
                        )
                    }

                    // Empty State (show when no inbox tasks, regardless of project tasks)
                    if taskStore.tasksByDay.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Inbox")
        .sheet(isPresented: $showActivityLog) {
            ActivityLogSheet(
                taskStore: taskStore,
                filter: $activityFilter
            )
            .frame(minWidth: 500, minHeight: 400)
        }
        .overlay {
            if taskToDelete != nil {
                DeleteConfirmationOverlay(
                    task: taskToDelete,
                    onCancel: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            taskToDelete = nil
                        }
                    },
                    onDelete: {
                        if let task = taskToDelete {
                            taskStore.deleteTask(task)
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            taskToDelete = nil
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Active Tasks Counter
    private var activeTasksCounter: some View {
        HStack(spacing: 4) {
            Text("\(taskStore.activeTaskCount)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.accentPrimary)

            Text("active")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.accentPrimary.opacity(0.1))
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 60)

            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.accentPrimary.opacity(0.2), radius: 20, x: 0, y: 0)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentPrimary)
            }

            VStack(spacing: Spacing.sm) {
                Text("All clear!")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("No tasks in your inbox")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }

            // Add task button
            HStack(spacing: Spacing.xs) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Add a task")
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
                addTaskContextDate = nil
                showAddTask = true
            }
        }
    }

    // MARK: - Activity Log Button
    private var activityLogButton: some View {
        Image(systemName: "clock.arrow.circlepath")
            .font(.system(size: 18))
            .foregroundColor(.textSecondary)
            .onTapGesture {
                Haptics.impact(.light)
                showActivityLog = true
            }
    }
}

// MARK: - Task Section (macOS)
struct TaskSection: View {
    let title: String
    let titleColor: Color
    let tasks: [FlowTask]
    @ObservedObject var taskStore: TaskStore
    let onAddTask: () -> Void
    var onEditTask: ((FlowTask) -> Void)? = nil
    var date: Date? = nil
    @Binding var taskToDelete: FlowTask?

    @State private var isExpanded = true

    private var formattedDateSubtitle: String? {
        guard let date = date else { return nil }
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM d"

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        return "\(monthFormatter.string(from: date)) • \(dayFormatter.string(from: date))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Section Header
            HStack {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(titleColor)
                        .frame(width: 8, height: 8)

                    Text(title)
                        .font(Typography.labelMedium)
                        .foregroundColor(titleColor)

                    if let subtitle = formattedDateSubtitle {
                        Text("•")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textMuted)

                        Text(subtitle)
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)
                    }

                    Text("(\(tasks.count))")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            // Tasks
            if isExpanded {
                VStack(spacing: Spacing.xs) {
                    ForEach(tasks) { task in
                        TaskRow(
                            task: task,
                            taskStore: taskStore,
                            taskToDelete: $taskToDelete,
                            onEdit: { onEditTask?(task) }
                        )
                    }

                    // Add task button
                    addTaskButton
                }
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
                .shadow(color: titleColor.opacity(0.10), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Add Task Button
    private var addTaskButton: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))

            Text("Add task")
                .font(Typography.bodySmall)
        }
        .foregroundColor(.textMuted)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            onAddTask()
        }
    }
}

// MARK: - Task Row (macOS)
struct TaskRow: View {
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

                // Meta info
                HStack(spacing: Spacing.sm) {
                    if let displayLabel = task.displayDueLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(displayLabel)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(task.dueStatus.color)
                    }

                    if let priority = task.priority {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 6, height: 6)
                            Text(priority.name)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.textSecondary)
                    }
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
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .opacity(task.isCompleted ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
        .contextMenu {
            Button(role: .destructive) {
                taskToDelete = task
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var checkboxView: some View {
        ZStack {
            Circle()
                .stroke(task.dueStatus.color, lineWidth: 2)
                .frame(width: 22, height: 22)
                .opacity(isPendingCompletion || task.isCompleted ? 0 : 1)

            Circle()
                .fill(Color.accentSuccess)
                .frame(width: 22, height: 22)
                .opacity(isPendingCompletion || task.isCompleted ? 1 : 0)
                .scaleEffect(isPendingCompletion || task.isCompleted ? 1 : 0.5)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
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

// MARK: - Animated Strikethrough Text
struct AnimatedStrikethroughText: View {
    let text: String
    let progress: CGFloat
    let textColor: Color
    let strikeColor: Color

    var body: some View {
        Text(text)
            .font(Typography.bodyMedium)
            .foregroundColor(textColor)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(strikeColor)
                        .frame(width: geometry.size.width * progress, height: 1.5)
                        .offset(y: geometry.size.height / 2 - 0.75)
                }
            }
    }
}

// MARK: - Delete Confirmation Overlay
struct DeleteConfirmationOverlay: View {
    let task: FlowTask?
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    Haptics.impact(.light)
                    onCancel()
                }

            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(Color.accentError.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "trash")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.accentError)
                }

                VStack(spacing: Spacing.xs) {
                    Text("Delete Task?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    if let task = task {
                        Text(task.name)
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }

                HStack(spacing: Spacing.md) {
                    Button("Cancel") {
                        Haptics.impact(.light)
                        onCancel()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.surfaceSecondary)
                    )

                    Button("Delete") {
                        Haptics.impact(.medium)
                        onDelete()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.accentError)
                    )
                }
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(Color.surfacePrimary)
            )
            .scaleEffect(showContent ? 1 : 0.9)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}

#Preview {
    let taskStore = TaskStore()

    return InboxView(
        taskStore: taskStore,
        showAddTask: .constant(false),
        taskToEdit: .constant(nil),
        addTaskContextDate: .constant(nil)
    )
    .frame(width: 800, height: 600)
    .onAppear {
        taskStore.loadDemoData()
    }
}
