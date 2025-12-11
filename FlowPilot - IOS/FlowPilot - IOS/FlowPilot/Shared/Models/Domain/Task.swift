import SwiftUI

// MARK: - Due Time Model
struct DueTime: Codable, Equatable {
    let hour: Int    // 0-23
    let minute: Int  // 0-59

    var asDateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(from dateComponents: DateComponents) {
        self.hour = dateComponents.hour ?? 0
        self.minute = dateComponents.minute ?? 0
    }

    var formatted: String {
        let displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let ampm = hour >= 12 ? "pm" : "am"
        return minute > 0 ? "\(displayHour):\(String(format: "%02d", minute))\(ampm)" : "\(displayHour)\(ampm)"
    }
}

// MARK: - Task Model
struct FlowTask: Identifiable, Equatable {
    let id: UUID
    var name: String
    var dueDate: Date?      // Date only (stored at midnight)
    var dueTime: DueTime?   // Time only (optional)
    var priority: Priority?
    var timeBlockId: UUID?
    var projectId: UUID?
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        dueDate: Date? = nil,
        dueTime: DueTime? = nil,
        priority: Priority? = nil,
        timeBlockId: UUID? = nil,
        projectId: UUID? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dueDate = dueDate
        self.dueTime = dueTime
        self.priority = priority
        self.timeBlockId = timeBlockId
        self.projectId = projectId
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
    }

    // Combined date + time for notifications and sorting
    var dueDateWithTime: Date? {
        guard let date = dueDate else { return nil }
        guard let time = dueTime else { return date }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    // MARK: - Due Date Status
    enum DueStatus {
        case overdue
        case today
        case thisWeek
        case nextWeek
        case later
        case noDueDate

        var color: Color {
            switch self {
            case .overdue: return .dueDateOverdue
            case .today: return .dueDateToday
            case .thisWeek: return .dueDateThisWeek
            case .nextWeek: return .dueDateNextWeek
            case .later, .noDueDate: return .dueDateLater
            }
        }

        var label: String {
            switch self {
            case .overdue: return "Overdue"
            case .today: return "Today"
            case .thisWeek: return "This Week"
            case .nextWeek: return "Next Week"
            case .later: return "Later"
            case .noDueDate: return "No Due Date"
            }
        }
    }

    var dueStatus: DueStatus {
        guard let dueDate = dueDate else { return .noDueDate }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDueDate = calendar.startOfDay(for: dueDate)

        // Overdue: before today
        if startOfDueDate < startOfToday {
            return .overdue
        }

        // Today
        if calendar.isDateInToday(dueDate) {
            return .today
        }

        // This week (remaining days)
        if let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday),
           startOfDueDate < endOfWeek {
            return .thisWeek
        }

        // Next week
        if let endOfNextWeek = calendar.date(byAdding: .day, value: 14, to: startOfToday),
           startOfDueDate < endOfNextWeek {
            return .nextWeek
        }

        return .later
    }

    // MARK: - Formatted Date Strings
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: dueDate)
    }

    var dayOfWeek: String? {
        guard let dueDate = dueDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: dueDate)
    }

    var relativeDayLabel: String? {
        guard let dueDate = dueDate else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        }
        return nil
    }

    /// Returns just the time portion if explicitly set
    var formattedTime: String? {
        guard let time = dueTime else { return nil }
        return time.formatted
    }

    /// Smart display label - shows time only if explicitly set
    var displayDueLabel: String? {
        return formattedTime
    }
}

// MARK: - Activity Log
struct ActivityLog: Identifiable, Equatable {
    let id: UUID
    let taskId: UUID
    let taskName: String
    let action: Action
    let timestamp: Date

    enum Action: String {
        case created = "Created"
        case completed = "Completed"
        case deleted = "Deleted"

        var icon: String {
            switch self {
            case .created: return "plus.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .deleted: return "trash.fill"
            }
        }

        var color: Color {
            switch self {
            case .created: return .accentPrimary
            case .completed: return .accentSuccess
            case .deleted: return .accentError
            }
        }
    }
}

// MARK: - Due Date Colors Extension
extension Color {
    static let dueDateOverdue = Color(hex: "EF4444")   // Red
    static let dueDateToday = Color(hex: "10B981")     // Green
    static let dueDateThisWeek = Color(hex: "F59E0B")  // Orange
    static let dueDateNextWeek = Color(hex: "3B82F6")  // Blue
    static let dueDateLater = Color(hex: "71717A")     // Gray
}
