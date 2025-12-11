import Foundation

extension Date {
    /// Returns the start of the week (Monday at 00:00:00) for this date.
    /// Uses explicit weekday calculation to ensure consistent behavior across all locales.
    func startOfWeek() -> Date {
        let calendar = Calendar.current

        // Get the weekday: Sunday = 1, Monday = 2, ..., Saturday = 7
        let weekday = calendar.component(.weekday, from: self)

        // Calculate days to subtract to reach Monday
        // Formula: (weekday - 2 + 7) % 7
        // Sunday (1) -> 6 days back, Monday (2) -> 0 days, Tuesday (3) -> 1 day, etc.
        let daysToSubtract = (weekday - 2 + 7) % 7

        // Get the Monday date
        guard let monday = calendar.date(byAdding: .day, value: -daysToSubtract, to: self) else {
            return self
        }

        // Return start of that day (midnight)
        return calendar.startOfDay(for: monday)
    }

    /// Returns the end of the week (following Monday at 00:00:00) for this date.
    /// This marks the exclusive end boundary for the week.
    func endOfWeek() -> Date {
        let weekStart = self.startOfWeek()
        return Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? self
    }
}
