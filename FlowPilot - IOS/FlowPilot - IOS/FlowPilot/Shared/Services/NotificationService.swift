import Foundation
import UserNotifications

// MARK: - Notification Service
class NotificationService {
    static let shared = NotificationService()

    private init() {}

    // MARK: - Request Permission
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("[NotificationService] Permission error: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }

    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Schedule Time Block Notifications
    /// Schedules notifications for a time block
    /// - Parameters:
    ///   - blockId: Unique identifier for the time block
    ///   - title: The name/title of the time block (e.g., priority name)
    ///   - startTime: When the block starts
    ///   - endTime: When the block ends
    ///   - earlyReminderMinutes: Array of minutes before start to send reminders (e.g., [5, 15, 30])
    func scheduleTimeBlockNotifications(
        blockId: UUID,
        title: String,
        startTime: Date,
        endTime: Date,
        earlyReminderMinutes: [Int]
    ) {
        // Always schedule notification at start time
        scheduleNotification(
            id: "\(blockId.uuidString)-start",
            title: "Time for \(title)",
            body: "",
            date: startTime
        )

        // Schedule early reminders
        for minutes in earlyReminderMinutes {
            let reminderDate = startTime.addingTimeInterval(-Double(minutes * 60))

            // Only schedule if the reminder time is in the future
            guard reminderDate > Date() else { continue }

            let reminderText = formatReminderText(minutes: minutes)

            scheduleNotification(
                id: "\(blockId.uuidString)-\(minutes)min",
                title: "Upcoming: \(title)",
                body: "Starting in \(reminderText)",
                date: reminderDate
            )
        }

        // Schedule completion notification
        scheduleNotification(
            id: "\(blockId.uuidString)-complete",
            title: "\(title) completed",
            body: "",
            date: endTime
        )
    }

    // MARK: - Schedule Single Notification
    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        // Don't schedule notifications in the past
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("[NotificationService] Scheduled notification: \(id) for \(date)")
            }
        }
    }

    // MARK: - Schedule Task Notification
    /// Schedules a notification for a task with a due time that is not assigned to a time block
    /// - Parameters:
    ///   - taskId: Unique identifier for the task
    ///   - taskName: The name of the task
    ///   - dueDate: When the task is due (includes time)
    func scheduleTaskNotification(taskId: UUID, taskName: String, dueDate: Date) {
        // Don't schedule if in the past
        guard dueDate > Date() else { return }

        scheduleNotification(
            id: "task-\(taskId.uuidString)",
            title: "Task Due",
            body: taskName,
            date: dueDate
        )
    }

    // MARK: - Cancel Notifications
    func cancelTaskNotification(taskId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["task-\(taskId.uuidString)"]
        )
        print("[NotificationService] Cancelled notification for task \(taskId)")
    }

    func cancelTimeBlockNotifications(blockId: UUID) {
        let center = UNUserNotificationCenter.current()

        // Get all pending notifications and remove those matching the block ID
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests
                .filter { $0.identifier.hasPrefix(blockId.uuidString) }
                .map { $0.identifier }

            center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            print("[NotificationService] Cancelled \(idsToRemove.count) notifications for block \(blockId)")
        }
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Helpers
    private func formatReminderText(minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            }
        } else {
            return "\(minutes) minute\(minutes > 1 ? "s" : "")"
        }
    }
}
