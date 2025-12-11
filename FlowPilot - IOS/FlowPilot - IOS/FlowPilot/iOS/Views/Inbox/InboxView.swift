import SwiftUI

// MARK: - Inbox View
struct InboxView: View {
    @ObservedObject var taskStore: TaskStore
    @Binding var showAddTask: Bool
    @Binding var taskToEdit: FlowTask?
    @Binding var addTaskContextDate: Date?

    @State private var showActivityLog = false
    @State private var activityFilter: TaskStore.ActivityFilter = .all
    @State private var showNavBarTitle = false
    @State private var taskToDelete: FlowTask? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with orbital glow
                Color.backgroundPrimary
                    .ignoresSafeArea()
                OrbitalBackgroundView()

                ScrollView {
                    LazyVStack(spacing: Spacing.lg, pinnedViews: []) {
                        // Custom header with Inbox title and active counter
                        HStack(alignment: .center) {
                            Text("Inbox")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.textPrimary)

                            Spacer()

                            activityLogButton

                            activeTasksCounter
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onChange(of: geo.frame(in: .global).maxY) { _, newValue in
                                        // Header is off screen when its bottom edge goes above ~100pt from top
                                        let threshold: CGFloat = 100
                                        let shouldShow = newValue < threshold
                                        if shouldShow != showNavBarTitle {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                showNavBarTitle = shouldShow
                                            }
                                        }
                                    }
                            }
                        )

                        // Day-based sections with staggered entrance animation
                        ForEach(Array(taskStore.tasksByDay.enumerated()), id: \.element.id) { index, section in
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
                                taskToDelete: $taskToDelete,
                                entranceDelay: Double(index) * 0.08
                            )
                        }

                        // Empty State (show when no inbox tasks, regardless of project tasks)
                        if taskStore.tasksByDay.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, 100)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Inbox")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .opacity(showNavBarTitle ? 1 : 0)
                }
            }
            .sheet(isPresented: $showActivityLog) {
                ActivityLogSheet(
                    taskStore: taskStore,
                    filter: $activityFilter
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .overlay(alignment: .bottomTrailing) {
                floatingAddButton
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
    }

    // MARK: - Floating Add Button
    @State private var buttonPulse = false

    private var floatingAddButton: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color.accentPrimary.opacity(0.15))
                .frame(width: 72, height: 72)
                .blur(radius: 8)
                .scaleEffect(buttonPulse ? 1.1 : 1.0)

            // Button
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.accentPrimary.opacity(0.5), radius: 16, x: 0, y: 8)
                )
        }
        .padding(.trailing, Spacing.xl)
        .padding(.bottom, Spacing.xxl)
        .onTapGesture {
            Haptics.impact(.light)
            addTaskContextDate = nil  // No context date for general add
            showAddTask = true
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                buttonPulse = true
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
                addTaskContextDate = nil  // No context date for general add
                showAddTask = true
            }
        }
    }

    // MARK: - Toolbar Buttons
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

// MARK: - Task Section
struct TaskSection: View {
    let title: String
    let titleColor: Color
    let tasks: [FlowTask]
    @ObservedObject var taskStore: TaskStore
    let onAddTask: () -> Void
    var onEditTask: ((FlowTask) -> Void)? = nil
    var date: Date? = nil
    @Binding var taskToDelete: FlowTask?
    var entranceDelay: Double = 0

    @State private var isExpanded = true
    @State private var hasAppeared = false

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
                .fill(Color.surfacePrimary.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(
                            LinearGradient(
                                colors: [titleColor.opacity(0.3), Color.surfaceBorder],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: titleColor.opacity(0.1), radius: 12, x: 0, y: 4)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(entranceDelay)) {
                hasAppeared = true
            }
        }
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

// MARK: - Task Row
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
            // Checkbox - separate tap target
            checkboxView

            // Task content - tappable for edit
            VStack(alignment: .leading, spacing: 2) {
                // Task name with animated strikethrough
                AnimatedStrikethroughText(
                    text: task.name,
                    progress: task.isCompleted ? 1 : strikethroughProgress,
                    textColor: (isPendingCompletion || task.isCompleted) ? .textMuted : .textPrimary,
                    strikeColor: .textMuted
                )
                .lineLimit(2)

                // Meta info
                HStack(spacing: Spacing.sm) {
                    // Due date
                    if let displayLabel = task.displayDueLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text(displayLabel)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(task.dueStatus.color)
                    }

                    // Priority
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
        .onLongPressGesture(minimumDuration: 0.5) {
            Haptics.impact(.medium)
            taskToDelete = task
        }
    }

    private var checkboxView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(task.dueStatus.color, lineWidth: 2)
                .frame(width: 22, height: 22)
                .opacity(isPendingCompletion || task.isCompleted ? 0 : 1)

            // Filled circle (for pending/completed)
            Circle()
                .fill(Color.accentSuccess)
                .frame(width: 22, height: 22)
                .opacity(isPendingCompletion || task.isCompleted ? 1 : 0)
                .scaleEffect(isPendingCompletion || task.isCompleted ? 1 : 0.5)

            // Checkmark with scale animation
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
            // Uncomplete the task
            Haptics.impact(.light)
            taskStore.uncompleteTask(task)
            return
        }

        if isPendingCompletion {
            // Cancel pending completion
            Haptics.impact(.light)
            cancelPendingCompletion()
        } else {
            // Start pending completion
            Haptics.impact(.medium)
            startPendingCompletion()
        }
    }

    private func startPendingCompletion() {
        isPendingCompletion = true
        SoundService.shared.playCompletionSound()

        // Animate checkmark
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            checkmarkScale = 1
        }

        // Animate strikethrough
        withAnimation(.easeInOut(duration: 0.4)) {
            strikethroughProgress = 1
        }

        // Schedule actual completion after 1.5s
        let workItem = DispatchWorkItem { [self] in
            completeTask()
        }
        completionTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func cancelPendingCompletion() {
        // Cancel timer
        completionTimer?.cancel()
        completionTimer = nil

        // Reverse animations
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
        // Reset local state since task is now completed
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
                            .fill(Color.accentError.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "trash")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.accentError)
                    }

                    // Text
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

                    // Buttons
                    VStack(spacing: Spacing.sm) {
                        // Delete button
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.accentError)
                            )
                            .onTapGesture {
                                Haptics.impact(.medium)
                                onDelete()
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

#Preview {
    let taskStore = TaskStore()

    return InboxView(
        taskStore: taskStore,
        showAddTask: .constant(false),
        taskToEdit: .constant(nil),
        addTaskContextDate: .constant(nil)
    )
    .onAppear {
        taskStore.loadDemoData()
    }
}
