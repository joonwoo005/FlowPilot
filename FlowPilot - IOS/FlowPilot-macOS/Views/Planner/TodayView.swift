import SwiftUI

// MARK: - Identifiable Date Wrapper
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

// MARK: - Today View (macOS)
struct TodayView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var resetToToday: Bool
    @Binding var externalTargetDate: Date?

    @State private var selectedDate: Date = Date()
    @State private var addBlockDate: IdentifiableDate? = nil
    @State private var blockToDelete: TimeBlock? = nil
    @State private var blockForNewTask: TimeBlock? = nil
    @State private var blockToEdit: TimeBlock? = nil

    private var awakeHours: Int {
        Int(priorityStore.sleepSchedule.availableHoursPerDay)
    }

    private var blocks: [TimeBlock] {
        timeBlockStore.blocks(for: selectedDate)
    }

    private var plannedHours: Double {
        Double(blocks.reduce(0) { $0 + $1.durationInMinutes }) / 60.0
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var isPast: Bool {
        Calendar.current.compare(selectedDate, to: Date(), toGranularity: .day) == .orderedAscending
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ContentOrbitalBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header with navigation
                    dayHeader

                    // Time blocks or empty state
                    if blocks.isEmpty {
                        emptyBlocksView
                    } else {
                        blocksListView
                    }
                }
                .padding(Spacing.xl)
            }
            .scrollContentBackground(.hidden)
        }
        .sheet(item: $addBlockDate) { identifiableDate in
            AddTimeBlockSheet(
                priorityStore: priorityStore,
                timeBlockStore: timeBlockStore,
                targetDate: identifiableDate.date
            )
            .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(item: $blockToEdit) { block in
            AddTimeBlockSheet(
                priorityStore: priorityStore,
                timeBlockStore: timeBlockStore,
                targetDate: block.startTime,
                editingBlock: block
            )
            .frame(minWidth: 500, minHeight: 600)
        }
        .sheet(item: $blockForNewTask) { block in
            AddTaskSheet(
                taskStore: taskStore,
                priorityStore: priorityStore,
                timeBlockStore: timeBlockStore
            )
            .frame(minWidth: 400, minHeight: 300)
        }
        .overlay {
            if blockToDelete != nil {
                DeleteBlockConfirmationOverlay(
                    block: blockToDelete,
                    onCancel: {
                        withAnimation { blockToDelete = nil }
                    },
                    onDelete: { _ in
                        if let block = blockToDelete {
                            timeBlockStore.deleteBlock(block)
                        }
                        withAnimation { blockToDelete = nil }
                    },
                    onDeleteAllFuture: {
                        if let block = blockToDelete {
                            timeBlockStore.deleteFutureRecurringBlocks(from: block)
                        }
                        withAnimation { blockToDelete = nil }
                    }
                )
            }
        }
        .onChange(of: resetToToday) { _, _ in
            withAnimation { selectedDate = Date() }
        }
        .onChange(of: externalTargetDate) { _, newDate in
            if let date = newDate {
                withAnimation { selectedDate = date }
                externalTargetDate = nil
            }
        }
    }

    // MARK: - Day Header
    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(headerTitle)
                        .font(Typography.displayMedium)
                        .foregroundColor(.white)

                    HStack(spacing: Spacing.xs) {
                        Text(formattedDate)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textSecondary)

                        Text("•")
                            .foregroundColor(.textMuted)

                        Text(dayOfWeek)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                // Navigation controls
                HStack(spacing: Spacing.lg) {
                    // Previous day
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.surfaceSecondary))
                        .onTapGesture {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3)) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            }
                        }

                    // Today indicator
                    Circle()
                        .fill(isToday ? Color.accentPrimary : Color.surfaceSecondary)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.accentPrimary, lineWidth: isToday ? 0 : 2)
                        )
                        .onTapGesture {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3)) {
                                selectedDate = Date()
                            }
                        }

                    // Next day
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.surfaceSecondary))
                        .onTapGesture {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3)) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            }
                        }
                }
            }

            Text(hoursText)
                .font(Typography.bodyMedium)
                .foregroundColor(.textMuted)

            Divider()
        }
    }

    private var headerTitle: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: selectedDate)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var hoursText: String {
        let planned = plannedHours == 0 ? "0" : String(format: "%.1f", plannedHours)
        return "\(planned) hours / \(awakeHours) awake hours planned"
    }

    // MARK: - Empty Blocks View
    private var emptyBlocksView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.textMuted)

            Text(isPast ? "No blocks were planned" : "No blocks planned")
                .font(Typography.bodyLarge)
                .foregroundColor(.textSecondary)

            if !isPast {
                Button {
                    Haptics.impact(.light)
                    addBlockDate = IdentifiableDate(date: selectedDate)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                        Text("Add block")
                    }
                    .foregroundColor(.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
    }

    // MARK: - Blocks List View
    private var blocksListView: some View {
        VStack(spacing: Spacing.md) {
            ForEach(blocks) { block in
                TimeBlockRow(block: block, taskStore: taskStore, timeBlockStore: timeBlockStore, onAddTask: {
                    blockForNewTask = block
                })
                .onTapGesture {
                    Haptics.impact(.light)
                    blockToEdit = block
                }
                .contextMenu {
                    Button("Edit") { blockToEdit = block }
                    Button("Add Task") { blockForNewTask = block }
                    Divider()
                    Button("Delete", role: .destructive) { blockToDelete = block }
                }
            }

            if !isPast {
                Button {
                    Haptics.impact(.light)
                    addBlockDate = IdentifiableDate(date: selectedDate)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                        Text("Add block")
                    }
                    .font(Typography.bodySmall)
                    .foregroundColor(.textMuted)
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.sm)
            }
        }
    }
}

// MARK: - Time Block Row (macOS)
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

    private var linkedTasks: [FlowTask] {
        taskStore.tasks.filter { $0.timeBlockId == block.id && !$0.isCompleted }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Accent bar (red if conflict)
            RoundedRectangle(cornerRadius: 2)
                .fill(hasConflict ? Color.accentError : block.priorityColor)
                .frame(width: 4)
                .shadow(color: hasConflict ? Color.accentError.opacity(0.6) : (isActive ? block.priorityColor.opacity(0.6) : .clear), radius: (isActive || hasConflict) ? 4 : 0)

            // Content
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack {
                    Text(block.priorityName)
                        .font(Typography.bodyLarge)
                        .fontWeight(isActive ? .semibold : .medium)
                        .foregroundColor(isPast ? .textMuted : .textPrimary)

                    if isActive {
                        Circle()
                            .fill(Color.accentSuccess)
                            .frame(width: 8, height: 8)
                    }

                    // Conflict indicator
                    if hasConflict && !isPast {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .medium))
                            Text("Overlap")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.accentError)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.accentError.opacity(0.15))
                        )
                        .scaleEffect(conflictPulse ? 1.03 : 1.0)
                    }

                    Spacer()

                    Text(block.formattedDuration)
                        .font(Typography.labelSmall)
                        .foregroundColor(isActive ? block.priorityColor : .textMuted)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isActive ? block.priorityColor.opacity(0.12) : Color.surfaceSecondary)
                        )
                }

                // Time range
                HStack(spacing: Spacing.sm) {
                    Text(block.formattedTimeRange)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.textMuted)

                    if isActive {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(block.priorityColor.opacity(0.2))
                                Capsule().fill(block.priorityColor)
                                    .frame(width: geo.size.width * progress)
                            }
                        }
                        .frame(width: 60, height: 4)
                    } else if isPast {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentSuccess)
                    }
                }

                // Tasks
                if !linkedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(linkedTasks) { task in
                            HStack(spacing: Spacing.sm) {
                                Circle()
                                    .stroke(Color.textMuted, lineWidth: 1)
                                    .frame(width: 14, height: 14)

                                Text(task.name)
                                    .font(Typography.bodySmall)
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.top, 4)
                }

                // Add task button
                if !isPast {
                    Button {
                        onAddTask?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10))
                            Text("Add task")
                                .font(Typography.labelSmall)
                        }
                        .foregroundColor(.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(hasConflict && !isPast ? Color.accentError.opacity(0.04) : (isActive ? block.priorityColor.opacity(0.04) : Color.surfacePrimary))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(
                            hasConflict && !isPast ? Color.accentError.opacity(0.3) : (isActive ? block.priorityColor.opacity(0.2) : Color.surfaceBorder),
                            lineWidth: (hasConflict || isActive) ? 1.5 : 1
                        )
                )
                .shadow(color: hasConflict && !isPast ? Color.accentError.opacity(0.12) : (isActive ? block.priorityColor.opacity(0.15) : Color.accentPrimary.opacity(0.08)), radius: isActive ? 12 : 8, x: 0, y: 4)
        )
        .opacity(isPast ? 0.6 : 1)
        .onAppear {
            startTimerIfNeeded()
            startConflictPulseIfNeeded()
        }
        .onDisappear {
            stopTimer()
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

    private func startTimerIfNeeded() {
        currentTime = Date()
        if needsTimerUpdates {
            scheduleTimer()
        }
    }

    private func startConflictPulseIfNeeded() {
        guard hasConflict && !isPast else { conflictPulse = false; return }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            conflictPulse = true
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

// MARK: - Delete Block Confirmation Overlay
struct DeleteBlockConfirmationOverlay: View {
    let block: TimeBlock?
    let onCancel: () -> Void
    let onDelete: (Bool) -> Void
    var onDeleteAllFuture: (() -> Void)? = nil

    @State private var deleteTasks = false

    private var isRecurring: Bool {
        block?.isRecurring ?? false
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: Spacing.lg) {
                Image(systemName: "trash")
                    .font(.system(size: 32))
                    .foregroundColor(.accentError)

                Text("Delete Block?")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                if let block = block {
                    VStack(spacing: 4) {
                        Text("\(block.priorityName) • \(block.formattedTimeRange)")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textSecondary)

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

                if isRecurring {
                    // Recurring block: show two delete options
                    VStack(spacing: Spacing.sm) {
                        Button {
                            Haptics.impact(.medium)
                            onDelete(deleteTasks)
                        } label: {
                            Text("This One Only")
                                .font(Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .fill(Color.accentError)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            Haptics.impact(.medium)
                            onDeleteAllFuture?()
                        } label: {
                            Text("All Future")
                                .font(Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.accentError)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(Color.accentError, lineWidth: 1.5)
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
                } else {
                    // Non-recurring block: original buttons
                    HStack(spacing: Spacing.md) {
                        Button("Cancel") {
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
                            onDelete(deleteTasks)
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
    TodayView(
        taskStore: TaskStore(),
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore(),
        resetToToday: .constant(false),
        externalTargetDate: .constant(nil)
    )
    .frame(width: 900, height: 600)
}
