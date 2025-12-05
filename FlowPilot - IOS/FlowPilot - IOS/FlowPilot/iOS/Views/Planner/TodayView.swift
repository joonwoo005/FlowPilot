import SwiftUI

// MARK: - Today View (with swipe navigation)
struct TodayView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var resetToToday: Bool  // When toggled, resets view to today

    // Page index: 0 = today, negative = past, positive = future
    // We use a range of -30 to +30 days (61 total pages)
    private let dateRange = -30...30
    @State private var currentPageIndex: Int = 30 // Index 30 = today (offset 0)

    @State private var showAddBlock = false
    @State private var dateForNewBlock: Date = Date()
    @State private var blockToDelete: TimeBlock? = nil
    @State private var blockForNewTask: TimeBlock? = nil
    @State private var blockToEdit: TimeBlock? = nil

    private var awakeHours: Int {
        Int(priorityStore.sleepSchedule.availableHoursPerDay)
    }

    // Convert page index to actual date
    private func dateForIndex(_ index: Int) -> Date {
        let offset = index - 30 // Convert to offset from today
        return Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }

    // Get the currently selected date based on page index
    private var selectedDate: Date {
        dateForIndex(currentPageIndex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                // Swipeable pages
                TabView(selection: $currentPageIndex) {
                    ForEach(0..<61, id: \.self) { index in
                        DayPageView(
                            date: dateForIndex(index),
                            taskStore: taskStore,
                            priorityStore: priorityStore,
                            timeBlockStore: timeBlockStore,
                            awakeHours: awakeHours,
                            onAddBlock: {
                                dateForNewBlock = dateForIndex(index)
                                showAddBlock = true
                            },
                            onDeleteBlock: { block in
                                blockToDelete = block
                            },
                            onAddTaskToBlock: { block in
                                blockForNewTask = block
                            },
                            onEditBlock: { block in
                                blockToEdit = block
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddBlock) {
                AddTimeBlockSheet(
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore,
                    targetDate: dateForNewBlock
                )
            }
            .sheet(item: $blockToEdit) { block in
                AddTimeBlockSheet(
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore,
                    targetDate: block.startTime,
                    editingBlock: block
                )
            }
            .sheet(item: $blockForNewTask) { block in
                AddTaskSheet(
                    taskStore: taskStore,
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore,
                    lockedBlock: block
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .overlay {
                if blockToDelete != nil {
                    DeleteBlockConfirmationOverlay(
                        block: blockToDelete,
                        onCancel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                blockToDelete = nil
                            }
                        },
                        onDelete: { deleteTasks in
                            if let block = blockToDelete {
                                // TODO: Handle tasks based on deleteTasks flag
                                // if deleteTasks: delete all tasks in the block
                                // else: move tasks to inbox (unschedule them)
                                timeBlockStore.deleteBlock(block)
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                blockToDelete = nil
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .onChange(of: resetToToday) { _, _ in
                withAnimation {
                    currentPageIndex = 30  // Reset to today
                }
            }
        }
    }
}

// MARK: - Day Page View (single day's content)
struct DayPageView: View {
    let date: Date
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    let awakeHours: Int
    let onAddBlock: () -> Void
    let onDeleteBlock: (TimeBlock) -> Void
    let onAddTaskToBlock: (TimeBlock) -> Void
    let onEditBlock: (TimeBlock) -> Void

    private var blocks: [TimeBlock] {
        timeBlockStore.blocks(for: date)
    }

    private var plannedHours: Double {
        Double(blocks.reduce(0) { $0 + $1.durationInMinutes }) / 60.0
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }

    private var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(date)
    }

    private var isPast: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
    }

    /// Get the start of the week (Monday at 00:00) for a given date
    private func startOfWeek(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday = 2
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Get the end of the week (Sunday at 23:59:59) for a given date
    private func endOfWeek(for date: Date) -> Date {
        let weekStart = startOfWeek(for: date)
        return Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? date
    }

    /// Check if any priority has remaining allocation time for the week of the viewed date
    private var hasRemainingAllocation: Bool {
        let weekStart = startOfWeek(for: date)
        let weekEnd = endOfWeek(for: date)

        for priority in priorityStore.priorities {
            let allocatedMinutes = Int(priority.hoursPerWeek * 60) // Weekly allocation in minutes
            let usedMinutes = timeBlockStore.timeBlocks
                .filter { $0.priorityId == priority.id && $0.startTime >= weekStart && $0.startTime < weekEnd }
                .reduce(0) { $0 + $1.durationInMinutes }
            if allocatedMinutes > usedMinutes {
                return true
            }
        }
        return false
    }

    /// Whether to show add block button (not past, and has remaining allocation)
    private var canAddBlock: Bool {
        !isPast && hasRemainingAllocation
    }

    private var headerTitle: String {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        if isTomorrow { return "Tomorrow" }

        // For other days, show the day name
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var hoursText: String {
        let planned = plannedHours == 0 ? "0" : String(format: "%.1f", plannedHours)
        return "\(planned) hours / \(awakeHours) awake hours planned"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Custom Header
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(headerTitle)
                        .font(Typography.displayLarge)
                        .foregroundColor(.textPrimary)

                    // Show date + day only when title is "Today", "Yesterday", "Tomorrow"
                    // Otherwise just show the date (since day name is already the title)
                    if isToday || isYesterday || isTomorrow {
                        HStack(spacing: Spacing.xs) {
                            Text(formattedDate)
                            Text("·")
                                .foregroundColor(.textMuted)
                            Text(dayOfWeek)
                        }
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textSecondary)
                    } else {
                        Text(formattedDate)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textSecondary)
                    }

                    Text(hoursText)
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textMuted)
                        .padding(.top, Spacing.xs)

                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(height: 1)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.base)

                // Time blocks or empty state
                if blocks.isEmpty {
                    EmptyBlocksView(
                        onAddBlock: onAddBlock,
                        canAddBlock: canAddBlock,
                        isPastDate: isPast
                    )
                    .padding(.horizontal, Spacing.base)
                    .padding(.top, Spacing.xl)
                } else {
                    // Time blocks list
                    VStack(spacing: Spacing.sm) {
                        ForEach(blocks) { block in
                            TimeBlockRow(block: block, taskStore: taskStore, onAddTask: {
                                Haptics.impact(.light)
                                onAddTaskToBlock(block)
                            })
                            .onTapGesture {
                                Haptics.impact(.light)
                                onEditBlock(block)
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                Haptics.impact(.medium)
                                onDeleteBlock(block)
                            }
                        }

                        // Add another block button (only if can add blocks)
                        if canAddBlock {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Add block")
                                    .font(Typography.bodySmall)
                            }
                            .foregroundColor(.textMuted)
                            .padding(.vertical, Spacing.md)
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                Haptics.impact(.light)
                                onAddBlock()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.base)
                    .padding(.top, Spacing.md)
                }
            }
            .padding(.top, Spacing.base)
        }
    }
}

// MARK: - Empty Blocks View
struct EmptyBlocksView: View {
    let onAddBlock: () -> Void
    var canAddBlock: Bool = true
    var isPastDate: Bool = false

    /// Determine what state to show: past, no allocation, or can add
    private var showAddButton: Bool {
        canAddBlock && !isPastDate
    }

    private var emptyStateMessage: String {
        if isPastDate {
            return "No blocks were planned"
        } else if !canAddBlock {
            return "All time allocated"
        } else {
            return "No blocks planned"
        }
    }

    private var iconName: String {
        if isPastDate || !canAddBlock {
            return "calendar"
        } else {
            return "calendar.badge.plus"
        }
    }

    private var iconColor: Color {
        if isPastDate || !canAddBlock {
            return .textMuted
        } else {
            return .accentWarm
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Dashed container suggesting "drop zone"
            VStack(spacing: Spacing.md) {
                // Icon with warm glow
                ZStack {
                    // Subtle glow behind icon
                    Circle()
                        .fill(Color.accentWarm.opacity(showAddButton ? 0.1 : 0.05))
                        .frame(width: 64, height: 64)
                        .blur(radius: 8)

                    // Icon container
                    Circle()
                        .fill(Color.surfacePrimary)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(iconColor)
                        )
                }

                // Copy
                VStack(spacing: Spacing.xs) {
                    Text(emptyStateMessage)
                        .font(Typography.bodyLarge)
                        .fontWeight(.medium)
                        .foregroundColor(.textSecondary)

                    if showAddButton {
                        Text("Add time blocks to structure your day")
                            .font(Typography.bodySmall)
                            .foregroundColor(.textMuted)
                            .multilineTextAlignment(.center)
                    }
                }

                // Add block button (only if can add blocks)
                if showAddButton {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add block")
                            .font(Typography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.accentWarm)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.accentWarm.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentWarm.opacity(0.25), lineWidth: 1)
                            )
                    )
                    .padding(.top, Spacing.xs)
                    .onTapGesture {
                        onAddBlock()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(Color.surfaceBorder.opacity(0.6))
            )
        }
    }
}

// MARK: - Time Block Row
struct TimeBlockRow: View {
    let block: TimeBlock
    @ObservedObject var taskStore: TaskStore
    var onAddTask: (() -> Void)? = nil

    @State private var pulseAnimation = false

    private var isActive: Bool {
        block.isActive
    }

    private var isPast: Bool {
        block.isPast
    }

    private var progress: CGFloat {
        if isPast { return 1.0 }
        if !isActive { return 0.0 }

        let now = Date()
        let total = block.endTime.timeIntervalSince(block.startTime)
        let elapsed = now.timeIntervalSince(block.startTime)
        return min(max(CGFloat(elapsed / total), 0), 1)
    }

    private var startTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mma"
        return formatter.string(from: block.startTime).uppercased()
    }

    private var endTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mma"
        return formatter.string(from: block.endTime).uppercased()
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Left side - Times and duration
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(startTimeFormatted)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(isActive ? .textPrimary : (isPast ? .textMuted : .textPrimary))

                    // Live indicator for active blocks
                    if isActive {
                        Circle()
                            .fill(Color.accentSuccess)
                            .frame(width: 8, height: 8)
                            .shadow(color: Color.accentSuccess.opacity(0.6), radius: pulseAnimation ? 6 : 2)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    }
                }

                Text(endTimeFormatted)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.textMuted)

                // Duration badge
                Text(block.formattedDuration)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? block.priorityColor : .textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isActive ? block.priorityColor.opacity(0.15) : Color.surfaceSecondary)
                    )
                    .padding(.top, Spacing.xs)
            }

            // Color indicator bar - thicker and glowing when active
            RoundedRectangle(cornerRadius: 2)
                .fill(block.priorityColor)
                .frame(width: isActive ? 4 : 3)
                .shadow(color: isActive ? block.priorityColor.opacity(0.5) : .clear, radius: isActive ? 4 : 0)

            // Right side - Priority name, progress, tasks, status
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Priority name
                Text(block.priorityName)
                    .font(.system(size: 22, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isPast ? .textMuted : .textPrimary)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(block.priorityColor.opacity(0.2))
                            .frame(height: isActive ? 3 : 2)

                        // Progress fill
                        Rectangle()
                            .fill(block.priorityColor)
                            .frame(width: geometry.size.width * progress, height: isActive ? 3 : 2)
                            .shadow(color: isActive ? block.priorityColor.opacity(0.4) : .clear, radius: isActive ? 3 : 0)
                    }
                }
                .frame(height: isActive ? 3 : 2)

                // Tasks linked to this block
                ForEach(taskStore.tasks.filter { $0.timeBlockId == block.id }) { task in
                    BlockTaskRow(task: task, taskStore: taskStore)
                }

                // Status / Add tasks button
                if !isPast {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Add tasks")
                            .font(Typography.bodyMedium)
                    }
                    .foregroundColor(.textMuted)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onAddTask?()
                    }
                } else {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentSuccess)
                        Text("Completed")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.base)
        .background(
            ZStack {
                // Glow layer for active blocks
                if isActive {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(block.priorityColor.opacity(0.03))

                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(block.priorityColor.opacity(pulseAnimation ? 0.4 : 0.25), lineWidth: 1.5)
                        .shadow(color: block.priorityColor.opacity(0.2), radius: pulseAnimation ? 8 : 4)
                } else {
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfacePrimary)

                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                }
            }
        )
        .opacity(isPast ? 0.6 : 1)
        .onAppear {
            startPulseIfActive()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startPulseIfActive()
            } else {
                pulseAnimation = false
            }
        }
    }

    private func startPulseIfActive() {
        guard isActive else {
            pulseAnimation = false
            return
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Block Task Row (compact task display within a block)
struct BlockTaskRow: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore

    @State private var isPendingCompletion = false
    @State private var strikethroughProgress: CGFloat = 0
    @State private var checkmarkScale: CGFloat = 0
    @State private var completionTimer: DispatchWorkItem?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Checkbox
            checkboxView

            // Task name with animated strikethrough
            BlockAnimatedStrikethroughText(
                text: task.name,
                progress: task.isCompleted ? 1 : strikethroughProgress,
                textColor: (isPendingCompletion || task.isCompleted) ? .textMuted : .textSecondary,
                strikeColor: .textMuted
            )
            .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(task.isCompleted ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }

    private var checkboxView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.textMuted, lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .opacity(isPendingCompletion || task.isCompleted ? 0 : 1)

            // Filled circle (for pending/completed)
            Circle()
                .fill(Color.accentSuccess)
                .frame(width: 18, height: 18)
                .opacity(isPendingCompletion || task.isCompleted ? 1 : 0)
                .scaleEffect(isPendingCompletion || task.isCompleted ? 1 : 0.5)

            // Checkmark with scale animation
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
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

// MARK: - Block Animated Strikethrough Text
struct BlockAnimatedStrikethroughText: View {
    let text: String
    let progress: CGFloat
    let textColor: Color
    let strikeColor: Color

    var body: some View {
        Text(text)
            .font(Typography.bodySmall)
            .foregroundColor(textColor)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(strikeColor)
                        .frame(width: geometry.size.width * progress, height: 1)
                        .offset(y: geometry.size.height / 2 - 0.5)
                }
            }
    }
}

// MARK: - Delete Block Confirmation Overlay
struct DeleteBlockConfirmationOverlay: View {
    let block: TimeBlock?
    let onCancel: () -> Void
    let onDelete: (Bool) -> Void  // Bool: true = delete tasks, false = move to inbox

    @State private var showContent = false
    @State private var deleteTasks = false  // Default: move tasks to inbox

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
                        Text("Delete Block?")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        if let block = block {
                            Text("\(block.priorityName) · \(block.formattedTimeRange)")
                                .font(Typography.bodyMedium)
                                .foregroundColor(.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Task handling options
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("What about tasks in this block?")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textMuted)

                        // Move to inbox option
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: deleteTasks ? "circle" : "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(deleteTasks ? .textMuted : .accentPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Move to Inbox")
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(.textPrimary)
                                Text("Tasks will be unscheduled")
                                    .font(Typography.bodySmall)
                                    .foregroundColor(.textMuted)
                            }

                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(deleteTasks ? Color.clear : Color.accentPrimary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(deleteTasks ? Color.surfaceBorder : Color.accentPrimary.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .onTapGesture {
                            Haptics.impact(.light)
                            deleteTasks = false
                        }

                        // Delete tasks option
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: deleteTasks ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(deleteTasks ? .accentError : .textMuted)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete Tasks")
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(.textPrimary)
                                Text("Tasks will be permanently removed")
                                    .font(Typography.bodySmall)
                                    .foregroundColor(.textMuted)
                            }

                            Spacer()
                        }
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(deleteTasks ? Color.accentError.opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(deleteTasks ? Color.accentError.opacity(0.3) : Color.surfaceBorder, lineWidth: 1)
                                )
                        )
                        .onTapGesture {
                            Haptics.impact(.light)
                            deleteTasks = true
                        }
                    }

                    // Buttons
                    VStack(spacing: Spacing.sm) {
                        // Delete button
                        Text("Delete Block")
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
                                onDelete(deleteTasks)
                            }

                        // Cancel button
                        Text("Cancel")
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
    TodayView(taskStore: TaskStore(), priorityStore: OnboardingState(), timeBlockStore: TimeBlockStore(), resetToToday: .constant(false))
}
