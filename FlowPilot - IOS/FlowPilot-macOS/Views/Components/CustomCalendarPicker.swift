import SwiftUI

// MARK: - Custom Calendar Picker (macOS)
/// A visual calendar grid for date selection with dark theme styling

struct CustomCalendarPicker: View {
    @Binding var selectedDate: Date
    var accentColor: Color = .accentPrimary
    var minDate: Date? = nil
    var maxDate: Date? = nil
    var highlightedDates: Set<Date>? = nil
    var onDateSelected: ((Date) -> Void)? = nil

    @State private var currentMonth: Date = Date()
    @State private var isHoveredDate: Date? = nil

    private let calendar = Calendar.current
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Date?] {
        generateDaysInMonth()
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Month navigation header
            monthHeader

            // Weekday labels
            weekdayHeader

            // Calendar grid
            calendarGrid
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
        .onAppear {
            currentMonth = calendar.startOfMonth(for: selectedDate)
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            // Previous month
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.surfaceSecondary))
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                }

            Spacer()

            // Month/Year text
            Text(monthYearText)
                .font(Typography.headlineSmall)
                .foregroundColor(.textPrimary)

            Spacer()

            // Next month
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.surfaceSecondary))
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                }
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
    }

    // MARK: - Day Cell

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isHovered = isHoveredDate != nil && calendar.isDate(date, inSameDayAs: isHoveredDate!)
        let isDisabled = isDateDisabled(date)
        let isHighlighted = highlightedDates?.contains { calendar.isDate($0, inSameDayAs: date) } ?? false

        return Text("\(calendar.component(.day, from: date))")
            .font(.system(size: 14, weight: isSelected || isToday ? .semibold : .regular))
            .foregroundColor(dayTextColor(isSelected: isSelected, isCurrentMonth: isCurrentMonth, isDisabled: isDisabled))
            .frame(width: 36, height: 36)
            .background(
                ZStack {
                    // Selected background
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
                    }
                    // Today ring (when not selected)
                    else if isToday {
                        Circle()
                            .stroke(accentColor, lineWidth: 2)
                    }
                    // Hover background
                    else if isHovered && !isDisabled {
                        Circle()
                            .fill(Color.surfaceSecondary)
                    }
                }
            )
            .overlay(
                // Highlighted indicator (for dates with events)
                Group {
                    if isHighlighted && !isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 5, height: 5)
                            .offset(y: 12)
                    }
                }
            )
            .opacity(isDisabled ? 0.4 : 1.0)
            .contentShape(Circle())
            .onHover { hovering in
                isHoveredDate = hovering ? date : nil
            }
            .onTapGesture {
                guard !isDisabled else { return }
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.25)) {
                    selectedDate = date
                }
                onDateSelected?(date)
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .animation(.spring(response: 0.25), value: isSelected)
    }

    private func dayTextColor(isSelected: Bool, isCurrentMonth: Bool, isDisabled: Bool) -> Color {
        if isSelected {
            return .white
        } else if isDisabled {
            return .textMuted
        } else if isCurrentMonth {
            return .textPrimary
        } else {
            return .textMuted
        }
    }

    private func isDateDisabled(_ date: Date) -> Bool {
        if let min = minDate, date < calendar.startOfDay(for: min) {
            return true
        }
        if let max = maxDate, date > calendar.startOfDay(for: max) {
            return true
        }
        return false
    }

    // MARK: - Generate Days

    private func generateDaysInMonth() -> [Date?] {
        var days: [Date?] = []

        let startOfMonth = calendar.startOfMonth(for: currentMonth)
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!

        // Get the weekday of the first day (0 = Sunday)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1

        // Add empty cells for days before the first of the month
        for _ in 0..<firstWeekday {
            days.append(nil)
        }

        // Add days of the month
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }

        // Pad to complete 6 weeks (42 cells) for consistent height
        while days.count < 42 {
            days.append(nil)
        }

        return days
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Inline Calendar (for TodayView sidebar)

struct InlineCalendar: View {
    @Binding var selectedDate: Date
    var accentColor: Color = .accentPrimary
    var highlightedDates: Set<Date>? = nil
    var onDateSelected: ((Date) -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            CustomCalendarPicker(
                selectedDate: $selectedDate,
                accentColor: accentColor,
                highlightedDates: highlightedDates,
                onDateSelected: onDateSelected
            )

            // Quick navigation buttons
            HStack(spacing: Spacing.md) {
                QuickNavButton(title: "Today", isActive: Calendar.current.isDateInToday(selectedDate)) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = Date()
                    }
                    onDateSelected?(Date())
                }

                QuickNavButton(title: "Tomorrow", isActive: Calendar.current.isDateInTomorrow(selectedDate)) {
                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = tomorrow
                    }
                    onDateSelected?(tomorrow)
                }
            }
        }
    }
}

// MARK: - Quick Nav Button

private struct QuickNavButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Text(title)
            .font(Typography.labelMedium)
            .foregroundColor(isActive ? .accentPrimary : .textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(isActive ? Color.accentPrimary.opacity(0.15) : Color.surfaceSecondary)
            )
            .onTapGesture {
                Haptics.impact(.light)
                action()
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: Spacing.xxl) {
            CustomCalendarPicker(
                selectedDate: .constant(Date()),
                accentColor: .accentPrimary
            )
            .frame(width: 280)

            InlineCalendar(
                selectedDate: .constant(Date()),
                highlightedDates: [
                    Date(),
                    Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
                    Calendar.current.date(byAdding: .day, value: 5, to: Date())!
                ]
            )
            .frame(width: 280)
        }
        .padding(Spacing.xl)
    }
}
