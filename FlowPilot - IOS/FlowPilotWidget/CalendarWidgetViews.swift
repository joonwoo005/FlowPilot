//
//  CalendarWidgetViews.swift
//  FlowPilotWidget
//

import SwiftUI
import WidgetKit

// MARK: - Design Constants (matching main app)
private enum CalendarWidgetColors {
    static let backgroundPrimary = Color(hex: "0D0D0F")
    static let backgroundSecondary = Color(hex: "141416")
    static let surfacePrimary = Color(hex: "252528")
    static let surfaceBorder = Color(hex: "2A2A2D")
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "71717A")
    static let accentPrimary = Color(hex: "FF6B5B")
    static let accentWarm = Color(hex: "FF8A65")
    static let accentSuccess = Color(hex: "4ADE80")
}

// MARK: - Calendar Widget Block Data (must match TimeBlockStore's CalendarWidgetBlock)
struct CalendarWidgetBlock: Codable, Identifiable {
    let id: UUID
    let priorityName: String
    let priorityColorHex: String
    let startTime: Date
    let endTime: Date

    var durationInMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var formattedDuration: String {
        let hours = durationInMinutes / 60
        let minutes = durationInMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        formatter.dateFormat = "a"
        let period = formatter.string(from: endTime).lowercased()
        return "\(start) – \(end) \(period)"
    }

    var isActive: Bool {
        let now = Date()
        return startTime <= now && now <= endTime
    }

    var isPast: Bool {
        endTime < Date()
    }

    var priorityColor: Color {
        Color(hex: priorityColorHex)
    }
}

// Must match TimeBlockStore's CalendarWidgetData
struct CalendarWidgetData: Codable {
    let todayBlocks: [CalendarWidgetBlock]
    let weekBlocks: [CalendarWidgetBlock]
    let weekStartDate: Date

    func blocks(for date: Date) -> [CalendarWidgetBlock] {
        let calendar = Calendar.current
        return weekBlocks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }

    func blockCount(for date: Date) -> Int {
        blocks(for: date).count
    }

    func totalHours(for date: Date) -> Double {
        Double(blocks(for: date).reduce(0) { $0 + $1.durationInMinutes }) / 60.0
    }
}

// MARK: - Calendar Widget Entry
struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: CalendarWidgetConfigurationIntent
    let calendarData: CalendarWidgetData?
}

// MARK: - Calendar Timeline Provider
struct CalendarWidgetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        CalendarWidgetEntry(
            date: Date(),
            configuration: CalendarWidgetConfigurationIntent(),
            calendarData: nil
        )
    }

    func snapshot(for configuration: CalendarWidgetConfigurationIntent, in context: Context) async -> CalendarWidgetEntry {
        CalendarWidgetEntry(
            date: Date(),
            configuration: configuration,
            calendarData: loadCalendarData()
        )
    }

    func timeline(for configuration: CalendarWidgetConfigurationIntent, in context: Context) async -> Timeline<CalendarWidgetEntry> {
        let currentDate = Date()
        var entries: [CalendarWidgetEntry] = []
        var importantDates: Set<Date> = [currentDate]
        let calendarData = loadCalendarData()

        // Add block start/end times for immediate transitions
        if let data = calendarData {
            for block in data.todayBlocks {
                if block.startTime > currentDate {
                    importantDates.insert(block.startTime)
                    importantDates.insert(block.startTime.addingTimeInterval(1))
                }
                if block.endTime > currentDate {
                    importantDates.insert(block.endTime)
                    importantDates.insert(block.endTime.addingTimeInterval(1))
                }
            }
        }

        // Add regular interval entries
        for minuteOffset in stride(from: 0, to: 120, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            importantDates.insert(entryDate)
        }

        // Create entries for all dates, sorted
        for date in importantDates.sorted() {
            let entry = CalendarWidgetEntry(
                date: date,
                configuration: configuration,
                calendarData: calendarData
            )
            entries.append(entry)
        }

        // Refresh sooner if there's an upcoming block start or end
        var refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        if let data = calendarData {
            for block in data.todayBlocks {
                // Refresh right after block starts
                if block.startTime > currentDate {
                    let blockStartRefresh = block.startTime.addingTimeInterval(2)
                    if blockStartRefresh < refreshDate {
                        refreshDate = blockStartRefresh
                    }
                }
                // Refresh right after block ends
                if block.endTime > currentDate {
                    let blockEndRefresh = block.endTime.addingTimeInterval(2)
                    if blockEndRefresh < refreshDate {
                        refreshDate = blockEndRefresh
                    }
                }
            }
        }

        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    private func loadCalendarData() -> CalendarWidgetData? {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.flowpilot.ios"),
              let data = sharedDefaults.data(forKey: "calendarWidgetData") else {
            return nil
        }
        return try? JSONDecoder().decode(CalendarWidgetData.self, from: data)
    }
}

// MARK: - Main Calendar Widget View
struct CalendarWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: CalendarWidgetEntry

    var body: some View {
        switch entry.configuration.viewMode {
        case .today:
            TodayModeView(entry: entry, family: family)
        case .week:
            WeekModeView(entry: entry, family: family)
        }
    }
}

// MARK: - Today Mode View
struct TodayModeView: View {
    let entry: CalendarWidgetEntry
    let family: WidgetFamily

    private var blocks: [CalendarWidgetBlock] {
        entry.calendarData?.todayBlocks ?? []
    }

    private var upcomingBlocks: [CalendarWidgetBlock] {
        blocks.filter { !$0.isPast }
    }

    private var isLarge: Bool {
        family == .systemLarge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("TODAY")
                    .font(.system(size: isLarge ? 12 : 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CalendarWidgetColors.accentWarm)
                    .tracking(1)

                if isLarge {
                    Text("·")
                        .foregroundColor(CalendarWidgetColors.textMuted)
                    Text(dayOfWeek)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textSecondary)
                }

                Spacer()

                Text(formattedDate)
                    .font(.system(size: isLarge ? 12 : 10, weight: .medium))
                    .foregroundColor(CalendarWidgetColors.textMuted)
            }
            .padding(.bottom, isLarge ? 12 : 8)

            if isLarge {
                Rectangle()
                    .fill(CalendarWidgetColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.bottom, 12)
            }

            if blocks.isEmpty {
                Spacer()
                VStack(spacing: 4) {
                    Text("No blocks")
                        .font(.system(size: isLarge ? 18 : 15, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textMuted)
                    Text("planned for today")
                        .font(.system(size: isLarge ? 15 : 13))
                        .foregroundColor(CalendarWidgetColors.textMuted.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                // Block list
                VStack(alignment: .leading, spacing: isLarge ? 10 : (family == .systemSmall ? 6 : 8)) {
                    ForEach(Array(displayBlocks.enumerated()), id: \.element.id) { index, block in
                        if isLarge {
                            LargeBlockRow(block: block)
                        } else {
                            CompactBlockRow(block: block, isSmall: family == .systemSmall)
                        }

                        if index < displayBlocks.count - 1 {
                            Rectangle()
                                .fill(CalendarWidgetColors.surfaceBorder.opacity(0.5))
                                .frame(height: 0.5)
                        }
                    }

                    // Show more indicator
                    if hiddenCount > 0 {
                        Text("+\(hiddenCount) more")
                            .font(.system(size: isLarge ? 12 : 10, weight: .medium))
                            .foregroundColor(CalendarWidgetColors.textMuted)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }

            // Summary footer for large
            if isLarge && !blocks.isEmpty {
                Rectangle()
                    .fill(CalendarWidgetColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.vertical, 8)

                HStack {
                    let totalMinutes = blocks.reduce(0) { $0 + $1.durationInMinutes }
                    let completedMinutes = blocks.filter { $0.isPast }.reduce(0) { $0 + $1.durationInMinutes }

                    Text("\(blocks.count) blocks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textSecondary)

                    Text("·")
                        .foregroundColor(CalendarWidgetColors.textMuted)

                    Text(formatMinutes(totalMinutes))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textSecondary)

                    Spacer()

                    if completedMinutes > 0 {
                        Text("\(formatMinutes(completedMinutes)) done")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(CalendarWidgetColors.accentSuccess)
                    }
                }
            }
        }
        .padding(isLarge ? 16 : (family == .systemSmall ? 12 : 14))
    }

    private var pastBlocks: [CalendarWidgetBlock] {
        blocks.filter { $0.isPast }.sorted { $0.startTime < $1.startTime }
    }

    private var displayBlocks: [CalendarWidgetBlock] {
        // Show up to maxBlocks tasks, filling with completed if fewer upcoming
        let maxBlocks: Int
        switch family {
        case .systemSmall: maxBlocks = 2
        case .systemMedium: maxBlocks = 4
        case .systemLarge: maxBlocks = 4
        default: maxBlocks = 4
        }

        // If we have enough upcoming blocks, just show those
        if upcomingBlocks.count >= maxBlocks {
            return Array(upcomingBlocks.prefix(maxBlocks))
        }

        // Otherwise, backfill with most recent completed blocks
        let slotsForPast = maxBlocks - upcomingBlocks.count
        let recentPastBlocks = Array(pastBlocks.suffix(slotsForPast))

        // Return past blocks first (chronologically), then upcoming
        return recentPastBlocks + upcomingBlocks
    }

    private var hiddenCount: Int {
        // Hidden count is total blocks minus what we're displaying
        return max(0, blocks.count - displayBlocks.count)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: entry.date)
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: entry.date)
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Large Block Row (for large widget)
struct LargeBlockRow: View {
    let block: CalendarWidgetBlock

    var body: some View {
        HStack(spacing: 10) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(block.priorityColor)
                .frame(width: 3)
                .shadow(color: block.isActive ? block.priorityColor.opacity(0.5) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(block.priorityName)
                        .font(.system(size: 15, weight: block.isActive ? .semibold : .medium))
                        .foregroundColor(block.isPast ? CalendarWidgetColors.textMuted : CalendarWidgetColors.textPrimary)
                        .lineLimit(1)

                    if block.isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(CalendarWidgetColors.accentSuccess)
                                .frame(width: 6, height: 6)
                            Text("NOW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(CalendarWidgetColors.accentSuccess)
                        }
                    } else if block.isPast {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(CalendarWidgetColors.accentSuccess)
                    }

                    Spacer()

                    Text(block.formattedDuration)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(block.isActive ? block.priorityColor : CalendarWidgetColors.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(block.isActive ? block.priorityColor.opacity(0.15) : CalendarWidgetColors.surfacePrimary.opacity(0.6))
                        )
                }

                Text(block.formattedTimeRange)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(CalendarWidgetColors.textMuted)
            }
        }
        .opacity(block.isPast ? 0.5 : 1)
    }
}

// MARK: - Compact Block Row
struct CompactBlockRow: View {
    let block: CalendarWidgetBlock
    var isSmall: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            // Color accent bar
            RoundedRectangle(cornerRadius: 1)
                .fill(block.priorityColor)
                .frame(width: 2.5)
                .shadow(color: block.isActive ? block.priorityColor.opacity(0.5) : .clear, radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(block.priorityName)
                        .font(.system(size: isSmall ? 12 : 13, weight: block.isActive ? .semibold : .medium))
                        .foregroundColor(block.isPast ? CalendarWidgetColors.textMuted : CalendarWidgetColors.textPrimary)
                        .lineLimit(1)

                    if block.isActive {
                        Circle()
                            .fill(CalendarWidgetColors.accentSuccess)
                            .frame(width: 5, height: 5)
                    }

                    Spacer()

                    Text(block.formattedDuration)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(block.isActive ? block.priorityColor : CalendarWidgetColors.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(block.isActive ? block.priorityColor.opacity(0.15) : CalendarWidgetColors.surfacePrimary.opacity(0.6))
                        )
                }

                Text(block.formattedTimeRange)
                    .font(.system(size: isSmall ? 9 : 10, weight: .regular, design: .monospaced))
                    .foregroundColor(CalendarWidgetColors.textMuted)
            }
        }
        .opacity(block.isPast ? 0.5 : 1)
    }
}

// MARK: - Week Mode View
struct WeekModeView: View {
    let entry: CalendarWidgetEntry
    let family: WidgetFamily

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var isLarge: Bool {
        family == .systemLarge
    }

    private var weekDates: [Date] {
        guard let weekStart = entry.calendarData?.weekStartDate else {
            // Fallback to current week
            let calendar = Calendar.current
            let today = Date()
            let weekday = calendar.component(.weekday, from: today)
            let daysToSubtract = (weekday - 2 + 7) % 7
            guard let monday = calendar.date(byAdding: .day, value: -daysToSubtract, to: today) else {
                return []
            }
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
        }
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("WEEK")
                    .font(.system(size: isLarge ? 12 : 10, weight: .bold, design: .monospaced))
                    .foregroundColor(CalendarWidgetColors.accentPrimary)
                    .tracking(1)

                Spacer()

                Text(weekRangeText)
                    .font(.system(size: isLarge ? 12 : 10, weight: .medium))
                    .foregroundColor(CalendarWidgetColors.textMuted)
            }
            .padding(.bottom, isLarge ? 12 : (family == .systemSmall ? 8 : 10))

            if isLarge {
                Rectangle()
                    .fill(CalendarWidgetColors.surfaceBorder)
                    .frame(height: 0.5)
                    .padding(.bottom, 12)

                // Large: Show week with block details
                LargeWeekGrid(
                    weekDates: weekDates,
                    dayNames: dayNames,
                    calendarData: entry.calendarData
                )
            } else {
                // Small/Medium: Compact week grid
                HStack(spacing: 0) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                        WeekDayCell(
                            date: date,
                            dayLetter: dayLetters[index],
                            blockCount: entry.calendarData?.blockCount(for: date) ?? 0,
                            totalHours: entry.calendarData?.totalHours(for: date) ?? 0,
                            isSmall: family == .systemSmall
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Spacer(minLength: 0)

            // Summary footer
            if family != .systemSmall {
                if isLarge {
                    Rectangle()
                        .fill(CalendarWidgetColors.surfaceBorder)
                        .frame(height: 0.5)
                        .padding(.vertical, 8)
                }

                HStack {
                    let totalBlocks = entry.calendarData?.weekBlocks.count ?? 0
                    let totalHours = entry.calendarData?.weekBlocks.reduce(0) { $0 + $1.durationInMinutes } ?? 0

                    Text("\(totalBlocks) blocks")
                        .font(.system(size: isLarge ? 11 : 10, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textSecondary)

                    Text("·")
                        .foregroundColor(CalendarWidgetColors.textMuted)

                    Text(formatHours(Double(totalHours) / 60.0))
                        .font(.system(size: isLarge ? 11 : 10, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textSecondary)

                    Spacer()

                    if isLarge {
                        let todayBlocks = entry.calendarData?.todayBlocks.count ?? 0
                        Text("\(todayBlocks) today")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(CalendarWidgetColors.accentWarm)
                    }
                }
                .padding(.top, isLarge ? 0 : 8)
            }
        }
        .padding(isLarge ? 16 : (family == .systemSmall ? 12 : 14))
    }

    private var weekRangeText: String {
        guard let first = weekDates.first, let last = weekDates.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: first)
        formatter.dateFormat = "d MMM"
        let endDay = formatter.string(from: last)
        return "\(startDay) - \(endDay)"
    }

    private func formatHours(_ hours: Double) -> String {
        if hours == 0 { return "0h" }
        if hours == floor(hours) { return "\(Int(hours))h" }
        return String(format: "%.1fh", hours)
    }
}

// MARK: - Large Week Grid (for large widget)
struct LargeWeekGrid: View {
    let weekDates: [Date]
    let dayNames: [String]
    let calendarData: CalendarWidgetData?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                LargeWeekDayColumn(
                    date: date,
                    dayName: dayNames[index],
                    blocks: calendarData?.blocks(for: date) ?? []
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Large Week Day Column
struct LargeWeekDayColumn: View {
    let date: Date
    let dayName: String
    let blocks: [CalendarWidgetBlock]

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isPast: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    var body: some View {
        VStack(spacing: 6) {
            // Day header
            VStack(spacing: 2) {
                Text(dayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(CalendarWidgetColors.textMuted)

                ZStack {
                    if isToday {
                        Circle()
                            .fill(CalendarWidgetColors.accentWarm)
                            .frame(width: 22, height: 22)
                    }

                    Text(dayNumber)
                        .font(.system(size: 12, weight: isToday ? .semibold : .regular))
                        .foregroundColor(isToday ? .white : (isPast ? CalendarWidgetColors.textMuted : CalendarWidgetColors.textPrimary))
                }
            }

            // Block indicators
            VStack(spacing: 3) {
                ForEach(Array(blocks.prefix(4).enumerated()), id: \.element.id) { _, block in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: block.priorityColorHex))
                        .frame(height: 16)
                        .opacity(block.isPast ? 0.4 : 0.8)
                }

                if blocks.count > 4 {
                    Text("+\(blocks.count - 4)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(CalendarWidgetColors.textMuted)
                }
            }

            Spacer(minLength: 0)
        }
        .opacity(isPast ? 0.6 : 1)
    }
}

// MARK: - Week Day Cell
struct WeekDayCell: View {
    let date: Date
    let dayLetter: String
    let blockCount: Int
    let totalHours: Double
    var isSmall: Bool = false

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isPast: Bool {
        Calendar.current.compare(date, to: Date(), toGranularity: .day) == .orderedAscending
    }

    private var dayNumber: String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }

    var body: some View {
        VStack(spacing: isSmall ? 3 : 4) {
            // Day letter
            Text(dayLetter)
                .font(.system(size: isSmall ? 8 : 9, weight: .medium))
                .foregroundColor(CalendarWidgetColors.textMuted)

            // Day number with today highlight
            ZStack {
                if isToday {
                    Circle()
                        .fill(CalendarWidgetColors.accentWarm)
                        .frame(width: isSmall ? 20 : 24, height: isSmall ? 20 : 24)
                }

                Text(dayNumber)
                    .font(.system(size: isSmall ? 11 : 13, weight: isToday ? .semibold : .regular))
                    .foregroundColor(isToday ? .white : (isPast ? CalendarWidgetColors.textMuted : CalendarWidgetColors.textPrimary))
            }
            .frame(height: isSmall ? 20 : 24)

            // Block indicators (dots)
            if !isSmall {
                HStack(spacing: 2) {
                    ForEach(0..<min(blockCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isPast ? CalendarWidgetColors.textMuted.opacity(0.5) : CalendarWidgetColors.accentPrimary)
                            .frame(width: 4, height: 4)
                    }
                    if blockCount > 3 {
                        Text("+")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(CalendarWidgetColors.textMuted)
                    }
                }
                .frame(height: 6)
            } else {
                // For small widget, just show a count or dot
                if blockCount > 0 {
                    Text("\(blockCount)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(isPast ? CalendarWidgetColors.textMuted : CalendarWidgetColors.accentPrimary)
                }
            }
        }
        .opacity(isPast ? 0.6 : 1)
    }
}

// MARK: - Calendar Widget
struct FlowPilotCalendarWidget: Widget {
    let kind: String = "FlowPilotCalendarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CalendarWidgetConfigurationIntent.self,
            provider: CalendarWidgetTimelineProvider()
        ) { entry in
            CalendarWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    CalendarWidgetColors.backgroundPrimary
                }
        }
        .configurationDisplayName("Calendar")
        .description("View today's blocks or week overview.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    FlowPilotCalendarWidget()
} timeline: {
    CalendarWidgetEntry(
        date: .now,
        configuration: CalendarWidgetConfigurationIntent(viewMode: .today),
        calendarData: nil
    )
}
