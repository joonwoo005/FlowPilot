import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Task Store
class TaskStore: ObservableObject {
    @Published var tasks: [FlowTask] = []
    @Published var activityLog: [ActivityLog] = []
    @Published var pendingCompletions: [UUID: Date] = [:] // taskId: completionTime

    private let undoDelay: TimeInterval = 1.5
    private var cancellables = Set<AnyCancellable>()

    // Firestore integration
    private var userId: String?
    private var taskListener: ListenerRegistration?
    private var activityListener: ListenerRegistration?

    // MARK: - Firestore Sync

    func startListening(userId: String) {
        self.userId = userId
        stopListening()

        // Listen to tasks
        taskListener = TaskRepository.shared.listenToTasks(userId: userId) { [weak self] tasks in
            DispatchQueue.main.async {
                self?.tasks = tasks
            }
        }

        // Listen to activity logs
        activityListener = ActivityLogRepository.shared.listenToActivityLogs(userId: userId) { [weak self] logs in
            DispatchQueue.main.async {
                self?.activityLog = logs
            }
        }
    }

    func stopListening() {
        taskListener?.remove()
        taskListener = nil
        activityListener?.remove()
        activityListener = nil
    }

    deinit {
        stopListening()
    }

    // MARK: - Computed Properties

    var activeTasks: [FlowTask] {
        tasks.filter { !$0.isCompleted }
    }

    var activeTaskCount: Int {
        activeTasks.count
    }

    var overdueTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .overdue }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
    }

    var todayTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .today }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
    }

    var thisWeekTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .thisWeek }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
    }

    var nextWeekTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .nextWeek }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
    }

    var laterTasks: [FlowTask] {
        activeTasks.filter { $0.dueStatus == .later }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
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
    /// Order: Overdue -> Not set (undated) -> Today -> Future days
    /// NOTE: Only shows tasks NOT assigned to a project (Inbox tasks)
    var tasksByDay: [DaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Filter to only inbox tasks (no project assignment)
        let inboxTasks = tasksWithoutProject

        var result: [DaySection] = []

        // Add overdue section first (all overdue tasks grouped together)
        let inboxOverdue = inboxTasks.filter { $0.dueStatus == .overdue }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
        if !inboxOverdue.isEmpty {
            result.append(DaySection(date: nil, title: "Overdue", color: .dueDateOverdue, tasks: inboxOverdue))
        }

        // Add undated tasks right after overdue
        let inboxUndated = inboxTasks.filter { $0.dueStatus == .noDueDate }
            .sorted { $0.createdAt > $1.createdAt }
        if !inboxUndated.isEmpty {
            result.append(DaySection(date: nil, title: "Not set", color: .textMuted, tasks: inboxUndated))
        }

        // Group non-overdue dated tasks by day
        let futureDated = inboxTasks.filter { $0.dueDate != nil && $0.dueStatus != .overdue }
        let grouped = Dictionary(grouping: futureDated) { task -> Date in
            calendar.startOfDay(for: task.dueDate!)
        }

        let sortedDates = grouped.keys.sorted()
        result += sortedDates.map { date in
            let tasks = grouped[date]!.sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
            let title = dayTitle(for: date)
            let color = dayColor(for: date, relativeTo: today)
            return DaySection(date: date, title: title, color: color, tasks: tasks)
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
            // Use title for sections without dates (Overdue, No Due Date)
            return title
        }
    }

    /// Get display title for a day (e.g., "Today", "Tomorrow", "Sunday", "Next Monday")
    private func dayTitle(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: date)

            // Check if date is in "next week" range (7-13 days from today)
            if let weekFromNow = calendar.date(byAdding: .day, value: 7, to: today),
               let twoWeeksFromNow = calendar.date(byAdding: .day, value: 14, to: today),
               startOfDate >= weekFromNow && startOfDate < twoWeeksFromNow {
                return "Next \(dayName)"
            }

            return dayName
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

    func addTask(name: String, dueDate: Date? = nil, dueTime: DueTime? = nil, priority: Priority? = nil, timeBlockId: UUID? = nil) {
        let task = FlowTask(
            name: name,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority,
            timeBlockId: timeBlockId
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks.append(task)
        }

        logActivity(taskId: task.id, taskName: task.name, action: .created)

        // Schedule notification for tasks with due time but not assigned to a block
        if let dueDateTime = task.dueDateWithTime, dueTime != nil, timeBlockId == nil {
            NotificationService.shared.scheduleTaskNotification(
                taskId: task.id,
                taskName: task.name,
                dueDate: dueDateTime
            )
        }

        // Save to Firestore
        if let userId = userId {
            Task {
                try? await TaskRepository.shared.createTask(task, userId: userId)
            }
        }
    }

    // MARK: - Tasks by Time Block

    func tasks(for blockId: UUID) -> [FlowTask] {
        tasks.filter { $0.timeBlockId == blockId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func incompleteTasks(for blockId: UUID) -> [FlowTask] {
        tasks.filter { $0.timeBlockId == blockId && !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Tasks by Project

    /// Tasks that are NOT assigned to any project (for Browse priority sections)
    var tasksWithoutProject: [FlowTask] {
        activeTasks.filter { $0.projectId == nil }
    }

    /// Active tasks for a specific project
    func tasksForProject(_ projectId: UUID) -> [FlowTask] {
        activeTasks.filter { $0.projectId == projectId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Active tasks for a specific priority (without project assignment)
    func tasksForPriority(_ priorityId: UUID) -> [FlowTask] {
        tasksWithoutProject.filter { $0.priority?.id == priorityId }
            .sorted { ($0.dueDateWithTime ?? .distantFuture) < ($1.dueDateWithTime ?? .distantFuture) }
    }

    // MARK: - Search

    /// Search tasks by name (case-insensitive)
    func searchTasks(query: String) -> [FlowTask] {
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        return tasks.filter { $0.name.lowercased().contains(lowercasedQuery) }
            .sorted { !$0.isCompleted && $1.isCompleted }
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

            // Reschedule notification if task has due date with time and no time block
            if let dueDateTime = task.dueDateWithTime, task.dueTime != nil, task.timeBlockId == nil {
                NotificationService.shared.scheduleTaskNotification(
                    taskId: task.id,
                    taskName: task.name,
                    dueDate: dueDateTime
                )
            }

            // Update in Firestore
            if let userId = userId {
                Task {
                    try? await TaskRepository.shared.updateTask(tasks[index], userId: userId)
                }
            }
        } else {
            // Cancel notification when completing
            NotificationService.shared.cancelTaskNotification(taskId: task.id)

            // Mark as completing (with undo window)
            let completionTime = Date()
            pendingCompletions[task.id] = completionTime

            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                tasks[index].isCompleted = true
                tasks[index].completedAt = completionTime
            }

            let updatedTask = tasks[index]

            // After delay, finalize completion
            DispatchQueue.main.asyncAfter(deadline: .now() + undoDelay) { [weak self] in
                guard let self = self else { return }
                // Only log if still completed (wasn't undone)
                if self.pendingCompletions[task.id] != nil {
                    self.pendingCompletions.removeValue(forKey: task.id)
                    self.logActivity(taskId: task.id, taskName: task.name, action: .completed)

                    // Update in Firestore
                    if let userId = self.userId {
                        Task {
                            try? await TaskRepository.shared.updateTask(updatedTask, userId: userId)
                        }
                    }
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

    func completeTask(_ task: FlowTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        // Cancel any scheduled notification
        NotificationService.shared.cancelTaskNotification(taskId: task.id)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks[index].isCompleted = true
            tasks[index].completedAt = Date()
        }
        logActivity(taskId: task.id, taskName: task.name, action: .completed)
    }

    func uncompleteTask(_ task: FlowTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks[index].isCompleted = false
            tasks[index].completedAt = nil
        }

        // Reschedule notification if task has due date with time and no time block
        if let dueDateTime = task.dueDateWithTime, task.dueTime != nil, task.timeBlockId == nil {
            NotificationService.shared.scheduleTaskNotification(
                taskId: task.id,
                taskName: task.name,
                dueDate: dueDateTime
            )
        }
    }

    func deleteTask(_ task: FlowTask) {
        logActivity(taskId: task.id, taskName: task.name, action: .deleted)

        // Cancel any scheduled notification
        NotificationService.shared.cancelTaskNotification(taskId: task.id)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks.removeAll { $0.id == task.id }
        }
        pendingCompletions.removeValue(forKey: task.id)

        // Delete from Firestore
        if let userId = userId {
            Task {
                try? await TaskRepository.shared.deleteTask(taskId: task.id, userId: userId)
            }
        }
    }

    func deleteAllTasks() {
        // Cancel all scheduled notifications
        for task in tasks {
            NotificationService.shared.cancelTaskNotification(taskId: task.id)
        }

        // Delete all from Firestore
        if let userId = userId {
            Task {
                for task in tasks {
                    try? await TaskRepository.shared.deleteTask(taskId: task.id, userId: userId)
                }
            }
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            tasks.removeAll()
        }
        pendingCompletions.removeAll()
        activityLog.removeAll()
    }

    func updateTask(_ task: FlowTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }

        // Update notification: cancel existing, schedule new if applicable
        NotificationService.shared.cancelTaskNotification(taskId: task.id)
        if let dueDateTime = task.dueDateWithTime, task.dueTime != nil, task.timeBlockId == nil, !task.isCompleted {
            NotificationService.shared.scheduleTaskNotification(
                taskId: task.id,
                taskName: task.name,
                dueDate: dueDateTime
            )
        }

        // Update in Firestore
        if let userId = userId {
            Task {
                try? await TaskRepository.shared.updateTask(task, userId: userId)
            }
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

        // Save to Firestore
        if let userId = userId {
            Task {
                try? await ActivityLogRepository.shared.createActivityLog(log, userId: userId)
            }
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

        // Collect tasks to delete for Firestore
        var tasksToDelete: [FlowTask] = []

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch timeframe {
            case .today:
                // Clear today's activity logs
                activityLog.removeAll { log in
                    calendar.isDateInToday(log.timestamp)
                }
                // Clear completed tasks from today
                tasksToDelete = tasks.filter { task in
                    task.isCompleted && task.completedAt != nil && calendar.isDateInToday(task.completedAt!)
                }
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
                tasksToDelete = tasks.filter { task in
                    task.isCompleted && task.completedAt != nil && task.completedAt! >= startOfWeek
                }
                tasks.removeAll { task in
                    task.isCompleted && task.completedAt != nil && task.completedAt! >= startOfWeek
                }

            case .all:
                // Clear all activity logs
                activityLog.removeAll()
                // Clear all completed tasks
                tasksToDelete = tasks.filter { $0.isCompleted }
                tasks.removeAll { $0.isCompleted }
            }
        }

        // Delete from Firestore
        if let userId = userId {
            Task {
                // Delete completed tasks
                for task in tasksToDelete {
                    try? await TaskRepository.shared.deleteTask(taskId: task.id, userId: userId)
                }

                // Delete activity logs based on timeframe
                switch timeframe {
                case .today:
                    let startOfToday = calendar.startOfDay(for: now)
                    try? await ActivityLogRepository.shared.deleteActivityLogs(userId: userId, olderThan: startOfToday)
                case .thisWeek:
                    let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                    try? await ActivityLogRepository.shared.deleteActivityLogs(userId: userId, olderThan: startOfWeek)
                case .all:
                    try? await ActivityLogRepository.shared.deleteAllActivityLogs(userId: userId)
                }
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
