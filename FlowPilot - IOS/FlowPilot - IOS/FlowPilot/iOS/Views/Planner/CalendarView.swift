import SwiftUI

// MARK: - Calendar View (Week-based view)
struct CalendarView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var selectedTab: MainTabView.Tab
    @Binding var todayViewTargetDate: Date?
    @Binding var resetToThisWeek: Bool

    @State private var currentWeekOffset: Int = 0
    @State private var showAddBlock = false
    @State private var dateForNewBlock: Date = Date()
    @State private var blockToDelete: TimeBlock? = nil
    @State private var blockForNewTask: TimeBlock? = nil
    @State private var blockToEdit: TimeBlock? = nil
    @State private var expandedDays: Set<String> = []  // Track expanded days by date string

    private var currentWeekDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: currentWeekOffset, to: Date()) ?? Date()
    }

    private var daysInCurrentWeek: [Date] {
        timeBlockStore.datesInWeek(for: currentWeekDate)
    }

    private var weeklyPlannedHours: Double {
        timeBlockStore.totalHoursForWeek(containing: currentWeekDate)
    }

    private var weeklyAllocatedHours: Double {
        priorityStore.priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    private var progressPercentage: Int {
        guard weeklyAllocatedHours > 0 else { return 0 }
        return Int((weeklyPlannedHours / weeklyAllocatedHours) * 100)
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func isExpanded(_ date: Date) -> Bool {
        expandedDays.contains(dateKey(for: date))
    }

    private func toggleExpanded(_ date: Date) {
        let key = dateKey(for: date)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if expandedDays.contains(key) {
                expandedDays.remove(key)
            } else {
                expandedDays.insert(key)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with orbital glow
                Color.backgroundPrimary
                    .ignoresSafeArea()
                OrbitalBackgroundView()

                VStack(spacing: 0) {
                    // Week Strip Header
                    WeekStripView(
                        currentWeekDate: currentWeekDate,
                        onPreviousWeek: {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentWeekOffset -= 1
                            }
                        },
                        onNextWeek: {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentWeekOffset += 1
                            }
                        },
                        onGoToToday: {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentWeekOffset = 0
                            }
                        }
                    )

                    // Progress Bar
                    WeekProgressBar(
                        plannedHours: weeklyPlannedHours,
                        allocatedHours: weeklyAllocatedHours,
                        percentage: progressPercentage
                    )
                    .padding(.horizontal, Spacing.base)
                    .padding(.top, Spacing.md)

                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(height: 1)
                        .padding(.top, Spacing.md)

                    // Day Sections (scrollable)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(daysInCurrentWeek, id: \.self) { day in
                                CalendarDaySection(
                                    date: day,
                                    blocks: timeBlockStore.blocks(for: day),
                                    taskStore: taskStore,
                                    timeBlockStore: timeBlockStore,
                                    isExpanded: isExpanded(day),
                                    onToggleExpand: {
                                        Haptics.impact(.light)
                                        toggleExpanded(day)
                                    },
                                    onAddBlock: {
                                        dateForNewBlock = day
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

                                Rectangle()
                                    .fill(Color.surfaceBorder)
                                    .frame(height: 1)
                                    .padding(.horizontal, Spacing.base)
                            }
                        }
                        .padding(.top, Spacing.md)
                        .padding(.bottom, Spacing.xxxl)
                    }
                }
            }
            .navigationBarHidden(true)
            .scrollContentBackground(.hidden)
            .onAppear {
                // Expand today by default
                expandedDays.insert(dateKey(for: Date()))
            }
            .onChange(of: resetToThisWeek) { _, _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    currentWeekOffset = 0
                }
            }
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
        }
    }
}

// MARK: - Week Strip View
struct WeekStripView: View {
    let currentWeekDate: Date
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    let onGoToToday: () -> Void

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentWeekDate)
        // Monday = 2, so (weekday - 2 + 7) % 7 days back to get Monday
        let daysToSubtract = (weekday - 2 + 7) % 7
        guard let weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: currentWeekDate) else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentWeekDate)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Month/Year header with navigation
            HStack {
                Text(monthYearText)
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Navigation controls in pill
                HStack(spacing: 0) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onPreviousWeek()
                        }

                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(width: 1, height: 16)

                    Text("Today")
                        .font(Typography.labelMedium)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal, Spacing.md)
                        .frame(height: 32)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onGoToToday()
                        }

                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(width: 1, height: 16)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onNextWeek()
                        }
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, Spacing.base)

            // Day number row (simplified)
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    WeekDayCell(date: date)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .padding(.top, Spacing.base)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        onNextWeek()
                    } else if value.translation.width > 50 {
                        onPreviousWeek()
                    }
                }
        )
    }
}

// MARK: - Week Day Cell
struct WeekDayCell: View {
    let date: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    var body: some View {
        ZStack {
            if isToday {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color.accentWarm)
                    .frame(width: 36, height: 36)
            }

            Text(dayNumber)
                .font(.system(size: 17, weight: isToday ? .semibold : .regular))
                .foregroundColor(isToday ? .white : (isCurrentMonth ? .textPrimary : .textMuted))
        }
        .frame(height: 40)
    }
}

// MARK: - Week Progress Bar
struct WeekProgressBar: View {
    let plannedHours: Double
    let allocatedHours: Double
    let percentage: Int

    private var plannedText: String {
        if plannedHours == 0 {
            return "0"
        } else if plannedHours == floor(plannedHours) {
            return "\(Int(plannedHours))"
        } else {
            return String(format: "%.1f", plannedHours)
        }
    }

    private var allocatedText: String {
        if allocatedHours == floor(allocatedHours) {
            return "\(Int(allocatedHours))"
        } else {
            return String(format: "%.1f", allocatedHours)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("\(plannedText) hours / \(allocatedText) hours allocated")
                    .font(Typography.bodySmall)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(percentage)%")
                    .font(Typography.bodySmall)
                    .foregroundColor(.accentPrimary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(Color.surfaceSecondary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(Color.accentPrimary)
                        .frame(width: geometry.size.width * CGFloat(min(percentage, 100)) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Calendar Day Section
struct CalendarDaySection: View {
    let date: Date
    let blocks: [TimeBlock]
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var timeBlockStore: TimeBlockStore
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onAddBlock: () -> Void
    let onDeleteBlock: (TimeBlock) -> Void
    let onAddTaskToBlock: (TimeBlock) -> Void
    let onEditBlock: (TimeBlock) -> Void

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

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private var relativeDay: String? {
        if isToday { return "Today" }
        if isYesterday { return "Yesterday" }
        if isTomorrow { return "Tomorrow" }
        return nil
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var blockCount: Int {
        blocks.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Day header (tappable to expand/collapse)
            HStack(spacing: Spacing.xs) {
                Text(formattedDate)
                    .foregroundColor(isToday ? .accentWarm : .accentPrimary)

                if let relative = relativeDay {
                    Text("·")
                        .foregroundColor(.textMuted)
                    Text(relative)
                        .foregroundColor(isToday ? .accentWarm : .textPrimary)
                }

                Text("·")
                    .foregroundColor(.textMuted)
                Text(dayOfWeek)
                    .foregroundColor(.textSecondary)

                // Show block count when collapsed
                if !isExpanded && blockCount > 0 {
                    Text("·")
                        .foregroundColor(.textMuted)
                    Text("\(blockCount) block\(blockCount == 1 ? "" : "s")")
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .font(Typography.bodyMedium)
            .padding(.horizontal, Spacing.base)
            .padding(.top, Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }

            // Expandable content
            if isExpanded {
                // Blocks or empty state
                if blocks.isEmpty {
                    HStack {
                        Text("No blocks planned")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textMuted)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.base)
                    .padding(.vertical, Spacing.sm)
                } else {
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
                    }
                    .padding(.horizontal, Spacing.base)
                }

                // Add block button (only for non-past dates)
                if !isPast {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                        Text("Add block")
                            .font(Typography.bodySmall)
                    }
                    .foregroundColor(.textMuted)
                    .padding(.horizontal, Spacing.base)
                    .padding(.vertical, Spacing.sm)
                    .onTapGesture {
                        Haptics.impact(.light)
                        onAddBlock()
                    }
                }
            }
        }
        .padding(.bottom, Spacing.md)
    }
}

#Preview {
    CalendarView(
        taskStore: TaskStore(),
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore(),
        selectedTab: .constant(.calendar),
        todayViewTargetDate: .constant(nil),
        resetToThisWeek: .constant(false)
    )
}
