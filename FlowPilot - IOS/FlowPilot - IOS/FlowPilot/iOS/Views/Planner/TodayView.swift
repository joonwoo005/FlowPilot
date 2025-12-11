import SwiftUI

// MARK: - Identifiable Date Wrapper (for sheet presentation)
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Today View (with swipe navigation)
struct TodayView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var resetToToday: Bool  // When toggled, resets view to today
    @Binding var externalTargetDate: Date?  // When set from Calendar, navigate to this date

    // Page index: 0 = today, negative = past, positive = future
    // We use a range of -30 to +30 days (61 total pages)
    private let dateRange = -30...30
    @State private var currentPageIndex: Int = 30 // Index 30 = today (offset 0)

    @State private var addBlockDate: IdentifiableDate? = nil  // Use item-based sheet for fresh content
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

    // Convert a date to page index
    private func indexForDate(_ date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)
        let dayOffset = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
        // Clamp to valid range (-30 to +30)
        let clampedOffset = max(-30, min(30, dayOffset))
        return 30 + clampedOffset
    }

    // Get the currently selected date based on page index
    private var selectedDate: Date {
        dateForIndex(currentPageIndex)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with orbital glow
                Color.backgroundPrimary
                    .ignoresSafeArea()
                OrbitalBackgroundView()

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
                                addBlockDate = IdentifiableDate(date: dateForIndex(index))
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
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(item: $addBlockDate) { identifiableDate in
                AddTimeBlockSheet(
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore,
                    targetDate: identifiableDate.date
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
                        },
                        onDeleteAllFuture: {
                            if let block = blockToDelete {
                                timeBlockStore.deleteFutureRecurringBlocks(from: block)
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
            .onChange(of: externalTargetDate) { _, newDate in
                if let date = newDate {
                    withAnimation {
                        currentPageIndex = indexForDate(date)
                    }
                    // Clear the target after navigating
                    externalTargetDate = nil
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

    /// Check if any priority has remaining allocation time for the week of the viewed date
    private var hasRemainingAllocation: Bool {
        let weekStart = date.startOfWeek()
        let weekEnd = date.endOfWeek()

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
                // Custom Header (matches InboxView alignment)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(headerTitle)
                        .font(.system(size: 34, weight: .bold))
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

                // Time blocks or empty state
                if blocks.isEmpty {
                    EmptyBlocksView(
                        onAddBlock: onAddBlock,
                        canAddBlock: canAddBlock,
                        isPastDate: isPast
                    )
                    .padding(.top, Spacing.xl)
                } else {
                    // Time blocks list
                    VStack(spacing: Spacing.sm) {
                        ForEach(blocks) { block in
                            TimeBlockRow(block: block, taskStore: taskStore, timeBlockStore: timeBlockStore, onAddTask: {
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
                    .padding(.top, Spacing.md)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.xxxl)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Empty Blocks View
struct EmptyBlocksView: View {
    let onAddBlock: () -> Void
    var canAddBlock: Bool = true
    var isPastDate: Bool = false

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

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(emptyStateMessage)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.textMuted)

            if showAddButton {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                    Text("Add block")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.textMuted.opacity(0.7))
                .padding(.top, 2)
                .onTapGesture {
                    Haptics.impact(.light)
                    onAddBlock()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }
}

// MARK: - Time Block Row (Compact Design)
struct TimeBlockRow: View {
    let block: TimeBlock
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var timeBlockStore: TimeBlockStore
    var onAddTask: (() -> Void)? = nil

    @State private var pulseAnimation = false
    @State private var currentTime = Date()
    @State private var timer: Timer?
    @State private var conflictPulse = false

    private var isActive: Bool {
        let calendar = Calendar.current
        guard calendar.isDate(block.startTime, inSameDayAs: currentTime) else { return false }
        return block.startTime <= currentTime && currentTime <= block.endTime
    }

    private var isPast: Bool {
        let calendar = Calendar.current
        if !calendar.isDate(block.endTime, inSameDayAs: currentTime) {
            return block.endTime < calendar.startOfDay(for: currentTime)
        }
        return block.endTime < currentTime
    }

    private var hasConflict: Bool {
        timeBlockStore.hasConflict(block)
    }

    /// Calculates the appropriate timer interval based on time remaining
    private var timerInterval: TimeInterval {
        let remaining = block.endTime.timeIntervalSince(currentTime)
        if remaining <= 60 { return 1 }          // <1 min: every second
        if remaining <= 600 { return 5 }         // <10 min: every 5 seconds
        if remaining <= 3600 { return 10 }       // <1 hour: every 10 seconds
        return 60                                 // >1 hour: every minute
    }

    private var progress: CGFloat {
        if isPast { return 1.0 }
        if !isActive { return 0.0 }
        let total = block.endTime.timeIntervalSince(block.startTime)
        let elapsed = currentTime.timeIntervalSince(block.startTime)
        return min(max(CGFloat(elapsed / total), 0), 1)
    }

    private var timeRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let start = formatter.string(from: block.startTime)
        let end = formatter.string(from: block.endTime)
        formatter.dateFormat = "a"
        let period = formatter.string(from: block.endTime).lowercased()
        return "\(start) – \(end) \(period)"
    }

    private var linkedTasks: [FlowTask] {
        taskStore.tasks.filter { $0.timeBlockId == block.id && !$0.isCompleted }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Accent bar - thin elegant line (red if conflict)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(hasConflict ? Color.accentError : block.priorityColor)
                .frame(width: 3)
                .shadow(color: hasConflict ? Color.accentError.opacity(0.6) : (isActive ? block.priorityColor.opacity(0.6) : .clear), radius: (isActive || hasConflict) ? 4 : 0)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Header row: Priority name + duration
                HStack(alignment: .center, spacing: 8) {
                    Text(block.priorityName)
                        .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                        .foregroundColor(isPast ? .textMuted : .textPrimary)

                    // Live indicator
                    if isActive {
                        Circle()
                            .fill(Color.accentSuccess)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.accentSuccess.opacity(0.8), radius: pulseAnimation ? 4 : 2)
                    }

                    // Conflict indicator
                    if hasConflict && !isPast {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text("Overlap")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.accentError)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.accentError.opacity(0.15))
                        )
                        .scaleEffect(conflictPulse ? 1.05 : 1.0)
                    }

                    Spacer()

                    // Duration pill
                    Text(block.formattedDuration)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isActive ? block.priorityColor : .textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isActive ? block.priorityColor.opacity(0.12) : Color.surfaceSecondary.opacity(0.6))
                        )
                }

                // Time range + progress
                HStack(spacing: 8) {
                    Text(timeRangeFormatted)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.textMuted)

                    // Inline progress indicator
                    if isActive {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(block.priorityColor.opacity(0.2))
                                Capsule()
                                    .fill(block.priorityColor)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(width: 40, height: 3)
                    } else if isPast {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.accentSuccess)
                    }
                }

                // Tasks (compact)
                if !linkedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(linkedTasks) { task in
                            BlockTaskRow(task: task, taskStore: taskStore)
                        }
                    }
                    .padding(.top, 4)
                }

                // Add tasks (only if not past)
                if !isPast {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Add task")
                            .font(.system(size: 12, weight: .regular))
                    }
                    .foregroundColor(.textMuted.opacity(0.7))
                    .padding(.top, linkedTasks.isEmpty ? 2 : 4)
                    .contentShape(Rectangle())
                    .onTapGesture { onAddTask?() }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Outer glow for active or conflicting blocks
                if isActive {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(block.priorityColor.opacity(0.15))
                        .blur(radius: 8)
                        .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                } else if hasConflict && !isPast {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentError.opacity(0.1))
                        .blur(radius: 6)
                        .scaleEffect(conflictPulse ? 1.01 : 1.0)
                }

                RoundedRectangle(cornerRadius: 10)
                    .fill(hasConflict && !isPast ? Color.accentError.opacity(0.04) : (isActive ? block.priorityColor.opacity(0.06) : Color.surfacePrimary.opacity(0.85)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: hasConflict && !isPast
                                        ? [Color.accentError.opacity(0.5), Color.accentError.opacity(0.2)]
                                        : (isActive
                                            ? [block.priorityColor.opacity(0.5), block.priorityColor.opacity(0.2)]
                                            : [Color.surfaceBorder.opacity(0.6), Color.surfaceBorder.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: (isActive || hasConflict) ? 1.5 : 0.5
                            )
                    )
                    .shadow(color: hasConflict && !isPast ? Color.accentError.opacity(0.15) : (isActive ? block.priorityColor.opacity(0.2) : Color.black.opacity(0.1)), radius: isActive ? 12 : 6, x: 0, y: 4)
            }
        )
        .opacity(isPast ? 0.5 : 1)
        .onAppear {
            startPulseIfActive()
            startTimerIfNeeded()
            startConflictPulseIfNeeded()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isActive) { _, active in
            if active {
                startPulseIfActive()
            } else {
                pulseAnimation = false
            }
        }
        .onChange(of: timeBlockStore.refreshTrigger) { _, _ in
            // App returned to foreground - refresh immediately
            currentTime = Date()
            restartTimerIfNeeded()
        }
    }

    /// Whether this block needs timer updates (active or could transition soon)
    private var needsTimerUpdates: Bool {
        // Don't need updates if block is definitively in the past
        if isPast { return false }
        // Need updates if block is active (to show progress and detect end)
        if isActive { return true }
        // Need updates if block starts within 1 minute (to detect start)
        let timeUntilStart = block.startTime.timeIntervalSince(currentTime)
        if timeUntilStart > 0 && timeUntilStart <= 60 { return true }
        return false
    }

    private func startPulseIfActive() {
        guard isActive else { pulseAnimation = false; return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }

    private func startConflictPulseIfNeeded() {
        guard hasConflict && !isPast else { conflictPulse = false; return }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            conflictPulse = true
        }
    }

    private func startTimerIfNeeded() {
        currentTime = Date()
        if needsTimerUpdates {
            scheduleTimer()
        }
    }

    private func scheduleTimer() {
        stopTimer()
        let interval = timerInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentTime = Date()
            // Stop timer if no longer needed (block ended)
            if !needsTimerUpdates {
                stopTimer()
                return
            }
            // Check if we need to change interval (e.g., crossed a threshold)
            let newInterval = timerInterval
            if newInterval != interval {
                restartTimerIfNeeded()
            }
        }
        // Allow timer to fire during scrolling
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func restartTimerIfNeeded() {
        stopTimer()
        if needsTimerUpdates {
            scheduleTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
        HStack(spacing: 6) {
            // Compact checkbox
            checkboxView

            // Task name with animated strikethrough
            BlockAnimatedStrikethroughText(
                text: task.name,
                progress: task.isCompleted ? 1 : strikethroughProgress,
                textColor: (isPendingCompletion || task.isCompleted) ? .textMuted : .textSecondary,
                strikeColor: .textMuted,
                fontSize: 13
            )
            .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(task.isCompleted ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
    }

    private var checkboxView: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.textMuted.opacity(0.6), lineWidth: 1)
                .frame(width: 14, height: 14)
                .opacity(isPendingCompletion || task.isCompleted ? 0 : 1)

            // Filled circle (for pending/completed)
            Circle()
                .fill(Color.accentSuccess)
                .frame(width: 14, height: 14)
                .opacity(isPendingCompletion || task.isCompleted ? 1 : 0)
                .scaleEffect(isPendingCompletion || task.isCompleted ? 1 : 0.5)

            // Checkmark with scale animation
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .bold))
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
    var fontSize: CGFloat = 13

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular))
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
    var onDeleteAllFuture: (() -> Void)? = nil  // Called when deleting all future recurring blocks

    @State private var showContent = false
    @State private var deleteTasks = false  // Default: move tasks to inbox

    private var isRecurring: Bool {
        block?.isRecurring ?? false
    }

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
                            VStack(spacing: 4) {
                                Text("\(block.priorityName) · \(block.formattedTimeRange)")
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)

                                if isRecurring {
                                    HStack(spacing: 4) {
                                        Image(systemName: "repeat")
                                            .font(.system(size: 10, weight: .medium))
                                        Text("Recurring block")
                                            .font(Typography.bodySmall)
                                    }
                                    .foregroundColor(.textMuted)
                                }
                            }
                        }
                    }

                    // Task handling options (only show if not recurring, or simplified for recurring)
                    if !isRecurring {
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
                    }

                    // Buttons
                    VStack(spacing: Spacing.sm) {
                        if isRecurring {
                            // Recurring block: show two delete options
                            Text("This One Only")
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

                            Text("All Future")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.accentError)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(Color.accentError, lineWidth: 1.5)
                                )
                                .onTapGesture {
                                    Haptics.impact(.medium)
                                    onDeleteAllFuture?()
                                }
                        } else {
                            // Non-recurring block: single delete button
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
    TodayView(taskStore: TaskStore(), priorityStore: OnboardingState(), timeBlockStore: TimeBlockStore(), resetToToday: .constant(false), externalTargetDate: .constant(nil))
}
