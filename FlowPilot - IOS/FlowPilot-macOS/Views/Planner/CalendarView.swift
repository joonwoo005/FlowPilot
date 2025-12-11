import SwiftUI

// MARK: - Calendar View (macOS)
struct CalendarView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var selectedTab: MainSplitView.Tab
    @Binding var todayViewTargetDate: Date?
    @Binding var resetToThisWeek: Bool

    @State private var currentWeekOffset: Int = 0
    @State private var showAddBlock = false
    @State private var dateForNewBlock: Date = Date()
    @State private var blockToEdit: TimeBlock? = nil
    @State private var expandedDays: Set<String> = []

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

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ContentOrbitalBackground()

            VStack(spacing: 0) {
                // Week header
                weekHeader

                Divider()

                // Progress bar
                weekProgressBar
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)

                Divider()

                // Days list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(daysInCurrentWeek, id: \.self) { day in
                            CalendarDaySection(
                                date: day,
                                blocks: timeBlockStore.blocks(for: day),
                                taskStore: taskStore,
                                timeBlockStore: timeBlockStore,
                                isExpanded: expandedDays.contains(dateKey(for: day)),
                                onToggleExpand: {
                                    let key = dateKey(for: day)
                                    withAnimation {
                                        if expandedDays.contains(key) {
                                            expandedDays.remove(key)
                                        } else {
                                            expandedDays.insert(key)
                                        }
                                    }
                                },
                                onAddBlock: {
                                    dateForNewBlock = day
                                    showAddBlock = true
                                },
                                onEditBlock: { block in
                                    blockToEdit = block
                                }
                            )

                            Divider()
                                .padding(.horizontal, Spacing.xl)
                        }
                    }
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xxxl)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            expandedDays.insert(dateKey(for: Date()))
        }
        .onChange(of: resetToThisWeek) { _, _ in
            withAnimation { currentWeekOffset = 0 }
        }
        .sheet(isPresented: $showAddBlock) {
            AddTimeBlockSheet(
                priorityStore: priorityStore,
                timeBlockStore: timeBlockStore,
                targetDate: dateForNewBlock
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
    }

    // MARK: - Week Header
    private var weekHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(monthYearText)
                    .font(Typography.displayMedium)
                    .foregroundColor(.white)

                Text(weekRangeText)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            HStack(spacing: Spacing.lg) {
                Button {
                    withAnimation { currentWeekOffset -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.textSecondary)

                Button {
                    withAnimation { currentWeekOffset = 0 }
                } label: {
                    Circle()
                        .fill(Color.accentPrimary)
                        .frame(width: 10, height: 10)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { currentWeekOffset += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
    }

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentWeekDate)
    }

    private var weekRangeText: String {
        _ = Calendar.current
        guard let weekStart = daysInCurrentWeek.first,
              let weekEnd = daysInCurrentWeek.last else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    // MARK: - Week Progress Bar
    private var weekProgressBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("\(Int(weeklyPlannedHours)) hours / \(Int(weeklyAllocatedHours)) hours allocated")
                    .font(Typography.bodySmall)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("\(progressPercentage)%")
                    .font(Typography.bodySmall)
                    .foregroundColor(.accentPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.surfaceSecondary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentPrimary)
                        .frame(width: geometry.size.width * CGFloat(min(progressPercentage, 100)) / 100, height: 6)
                        .shadow(color: Color.accentPrimary.opacity(0.4), radius: 4, x: 0, y: 0)
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
    let onEditBlock: (TimeBlock) -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isPast: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
    }

    private var relativeDay: String? {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Day header
            HStack {
                HStack(spacing: Spacing.xs) {
                    Text(formattedDate)
                        .foregroundColor(isToday ? .accentWarm : .accentPrimary)

                    if let relative = relativeDay {
                        Text("•")
                            .foregroundColor(.textMuted)
                        Text(relative)
                            .foregroundColor(isToday ? .accentWarm : .textPrimary)
                    }

                    Text("•")
                        .foregroundColor(.textMuted)
                    Text(dayOfWeek)
                        .foregroundColor(.textSecondary)

                    if !isExpanded && !blocks.isEmpty {
                        Text("• \(blocks.count) block\(blocks.count == 1 ? "" : "s")")
                            .foregroundColor(.textMuted)
                    }
                }
                .font(Typography.bodyMedium)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }

            if isExpanded {
                if blocks.isEmpty {
                    Text("No blocks planned")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textMuted)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                } else {
                    VStack(spacing: Spacing.sm) {
                        ForEach(blocks) { block in
                            TimeBlockRow(block: block, taskStore: taskStore, timeBlockStore: timeBlockStore)
                                .onTapGesture { onEditBlock(block) }
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                }

                if !isPast {
                    Button {
                        onAddBlock()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "plus")
                            Text("Add block")
                        }
                        .font(Typography.bodySmall)
                        .foregroundColor(.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.sm)
                }
            }
        }
        .padding(.bottom, Spacing.md)
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
    .frame(width: 800, height: 600)
}
