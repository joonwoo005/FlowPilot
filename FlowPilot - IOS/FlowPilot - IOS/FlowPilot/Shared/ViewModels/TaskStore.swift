import SwiftUI
import Combine

// MARK: - Task Store
class TaskStore: ObservableObject {
    @Published var tasks: [FlowTask] = []
    @Published var activityLog: [ActivityLog] = []
    @Published var pendingCompletions: [UUID: Date] = [:] // taskId: completionTime

    private let undoDelay: TimeInterval = 1.5
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var activeTasks: [FlowTask] {
        tasks.filter { !$0.isCompleted }
    }

    var activeTaskCount: Int {
        activeTasks.count
    }

    var overdueTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .overdue }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var todayTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .today }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var thisWeekTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .thisWeek }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var nextWeekTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .nextWeek }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var laterTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .later }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    var undatedTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .noDueDate }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var completedTasks: [FlowTask] {
        tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Tasks grouped by individual days for display (sorted by date)
    /// Overdue tasks are grouped together, then individual days, then undated
    var tasksByDay: [DaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var result: [DaySection] = []

        // Add overdue section first (all overdue tasks grouped together)
        if !overdueTasks.isEmpty {
            result.append(DaySection(date: nil, title: "Overdue", color: .dueDateOverdue, tasks: overdueTasks))
        }

        // Group non-overdue dated tasks by day
        let futureDated = activeTasks.filter { $0.dueDate != nil && $0.dueStatus != .overdue }
        let grouped = Dictionary(grouping: futureDated) { task -> Date in
            calendar.startOfDay(for: task.dueDate!)
        }

        let sortedDates = grouped.keys.sorted()
        result += sortedDates.map { date in
            let tasks = grouped[date]!.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            let title = dayTitle(for: date)
            let color = dayColor(for: date, relativeTo: today)
            return DaySection(date: date, title: title, color: color, tasks: tasks)
        }

        // Add undated at the end if any
        if !undatedTasks.isEmpty {
            result.append(DaySection(date: nil, title: "No Due Date", color: .textMuted, tasks: undatedTasks))
        }

        return result
    }

    /// Helper struct for day sections
    struct DaySection: Identifiable {
        let date: Date?
        let title: String
        let color: Color
        let tasks: [FlowTask]

        var id: String {
            if let date = date {
                return date.timeIntervalSince1970.description
            }
            return "undated"
        }
    }

    /// Get display title for a day (e.g., "Today", "Tomorrow", "Sunday")
    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }

    /// Get color for a day based on its relation to today
    private func dayColor(for date: Date, relativeTo today: Date) -> Color {
        let calendar = Calendar.current

        if date < today {
            return .dueDateOverdue
        } else if calendar.isDateInToday(date) {
            return .dueDateToday
        } else if let weekFromNow = calendar.date(byAdding: .day, value: 7, to: today),
                  date < weekFromNow {
            return .dueDateThisWeek
        } else if let twoWeeksFromNow = calendar.date(byAdding: .day, value: 14, to: today),
                  date < twoWeeksFromNow {
            return .dueDateNextWeek
        } else {
            return .dueDateLater
        }
    }

    // MARK: - Activity Log Filters

    func filteredActivityLog(_ filter: ActivityFilter) -> [ActivityLog] {
        switch filter {
        case .all:
            return activityLog.sorted { $0.timestamp > $1.timestamp }
        case .created:
            return activityLog.filter { $0.action == .created }.sorted { $0.timestamp > $1.timestamp }
        case .completed:
            return activityLog.filter { $0.action == .completed }.sorted { $0.timestamp > $1.timestamp }
        case .deleted:
            return activityLog.filter { $0.action == .deleted }.sorted { $0.timestamp > $1.timestamp }
        }
    }

    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case created = "Created"
        case completed = "Completed"
        case deleted = "Deleted"
    }

    // MARK: - Task Actions

    func addTask(name: String, dueDate: Date? = nil, priority: Priority? = nil) {
        let task = FlowTask(
            name: name,
            dueDate: dueDate,
            priority: priority
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks.append(task)
        }

        logActivity(taskId: task.id, taskName: task.name, action: .created)
    }

    func toggleComplete(_ task: FlowTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        if task.isCompleted {
            // Uncomplete immediately
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tasks[index].isCompleted = false
                tasks[index].completedAt = nil
            }
            pendingCompletions.removeValue(forKey: task.id)
        } else {
            // Mark as completing (with undo window)
            let completionTime = Date()
            pendingCompletions[task.id] = completionTime

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tasks[index].isCompleted = true
                tasks[index].completedAt = completionTime
            }

            // After delay, finalize completion
            DispatchQueue.main.asyncAfter(deadline: .now() + undoDelay) { [weak self] in
                guard let self = self else { return }
                // Only log if still completed (wasn't undone)
                if self.pendingCompletions[task.id] != nil {
                    self.pendingCompletions.removeValue(forKey: task.id)
                    self.logActivity(taskId: task.id, taskName: task.name, action: .completed)
                }
            }
        }
    }

    func undoComplete(_ task: FlowTask) {
        guard pendingCompletions[task.id] != nil else { return }

        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tasks[index].isCompleted = false
                tasks[index].completedAt = nil
            }
            pendingCompletions.removeValue(forKey: task.id)
        }
    }

    func deleteTask(_ task: FlowTask) {
        logActivity(taskId: task.id, taskName: task.name, action: .deleted)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks.removeAll { $0.id == task.id }
        }
        pendingCompletions.removeValue(forKey: task.id)
    }

    func updateTask(_ task: FlowTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }

    // MARK: - Activity Logging

    private func logActivity(taskId: UUID, taskName: String, action: ActivityLog.Action) {
        let log = ActivityLog(
            id: UUID(),
            taskId: taskId,
            taskName: taskName,
            action: action,
            timestamp: Date()
        )
        activityLog.insert(log, at: 0)

        // Keep only last 100 activities
        if activityLog.count > 100 {
            activityLog = Array(activityLog.prefix(100))
        }
    }

    // MARK: - Clear Activity & Completed Tasks

    enum ClearTimeframe: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case all = "All"
    }

    func clearActivityAndCompletedTasks(timeframe: ClearTimeframe) {
        let calendar = Calendar.current
        let now = Date()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch timeframe {
            case .today:
                // Clear today's activity logs
                activityLog.removeAll { log in
                    calendar.isDateInToday(log.timestamp)
                }
                // Clear completed tasks from today
                tasks.removeAll { task in
                    task.isCompleted && task.completedAt != nil && calendar.isDateInToday(task.completedAt!)
                }

            case .thisWeek:
                // Clear this week's activity logs
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                activityLog.removeAll { log in
                    log.timestamp >= startOfWeek
                }
                // Clear completed tasks from this week
                tasks.removeAll { task in
                    task.isCompleted && task.completedAt != nil && task.completedAt! >= startOfWeek
                }

            case .all:
                // Clear all activity logs
                activityLog.removeAll()
                // Clear all completed tasks
                tasks.removeAll { $0.isCompleted }
            }
        }
    }

    // MARK: - Demo Data
    func loadDemoData() {
        let calendar = Calendar.current
        let now = Date()

        // Overdue tasks
        if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) {
            addTask(name: "Review quarterly report", dueDate: twoDaysAgo)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
            addTask(name: "Send invoice to client", dueDate: yesterday)
        }

        // Today's tasks
        addTask(name: "Team standup meeting", dueDate: now)
        addTask(name: "Finish design mockups", dueDate: now)
        addTask(name: "Call with marketing", dueDate: now)

        // This week
        if let inTwoDays = calendar.date(byAdding: .day, value: 2, to: now) {
            addTask(name: "Prepare presentation", dueDate: inTwoDays)
        }
        if let inFourDays = calendar.date(byAdding: .day, value: 4, to: now) {
            addTask(name: "Submit expense report", dueDate: inFourDays)
        }

        // Next week
        if let nextWeek = calendar.date(byAdding: .day, value: 8, to: now) {
            addTask(name: "Product roadmap review", dueDate: nextWeek)
        }

        // Undated
        addTask(name: "Research new tools")
        addTask(name: "Update documentation")
    }
}
