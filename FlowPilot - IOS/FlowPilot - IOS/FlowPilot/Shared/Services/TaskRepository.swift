import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Task Repository
class TaskRepository {
    static let shared = TaskRepository()

    private let firebase = FirebaseConfig.shared

    private init() {}

    // MARK: - Create Task
    func createTask(_ task: FlowTask, userId: String) async throws {
        let data = taskToDocument(task)
        try await firebase.tasksCollection(userId: userId).document(task.id.uuidString).setData(data)
    }

    // MARK: - Update Task
    func updateTask(_ task: FlowTask, userId: String) async throws {
        var data = taskToDocument(task)
        data["updatedAt"] = FieldValue.serverTimestamp()
        try await firebase.tasksCollection(userId: userId).document(task.id.uuidString).updateData(data)
    }

    // MARK: - Delete Task
    func deleteTask(taskId: UUID, userId: String) async throws {
        try await firebase.tasksCollection(userId: userId).document(taskId.uuidString).delete()
    }

    // MARK: - Get All Tasks
    func getAllTasks(userId: String) async throws -> [FlowTask] {
        let snapshot = try await firebase.tasksCollection(userId: userId).getDocuments()
        return snapshot.documents.compactMap { documentToTask($0) }
    }

    // MARK: - Get Active Tasks
    func getActiveTasks(userId: String) async throws -> [FlowTask] {
        let snapshot = try await firebase.tasksCollection(userId: userId)
            .whereField("isCompleted", isEqualTo: false)
            .getDocuments()
        return snapshot.documents.compactMap { documentToTask($0) }
    }

    // MARK: - Get Tasks by Date Range
    func getTasks(userId: String, from startDate: Date, to endDate: Date) async throws -> [FlowTask] {
        let snapshot = try await firebase.tasksCollection(userId: userId)
            .whereField("dueDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("dueDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        return snapshot.documents.compactMap { documentToTask($0) }
    }

    // MARK: - Listen to Tasks
    func listenToTasks(userId: String, onChange: @escaping ([FlowTask]) -> Void) -> ListenerRegistration {
        return firebase.tasksCollection(userId: userId)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("[TaskRepository] Error listening to tasks: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                let tasks = documents.compactMap { self.documentToTask($0) }
                onChange(tasks)
            }
    }

    // MARK: - Batch Update Tasks
    func batchUpdateTasks(_ tasks: [FlowTask], userId: String) async throws {
        let batch = firebase.db.batch()

        for task in tasks {
            let ref = firebase.tasksCollection(userId: userId).document(task.id.uuidString)
            var data = taskToDocument(task)
            data["updatedAt"] = FieldValue.serverTimestamp()
            batch.setData(data, forDocument: ref, merge: true)
        }

        try await batch.commit()
    }

    // MARK: - Batch Delete Completed Tasks
    func deleteCompletedTasks(userId: String, olderThan date: Date? = nil) async throws {
        var query: Query = firebase.tasksCollection(userId: userId)
            .whereField("isCompleted", isEqualTo: true)

        if let date = date {
            query = query.whereField("completedAt", isLessThan: Timestamp(date: date))
        }

        let snapshot = try await query.getDocuments()
        let batch = firebase.db.batch()

        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()
    }

    // MARK: - Helpers
    private func taskToDocument(_ task: FlowTask) -> [String: Any] {
        var data: [String: Any] = [
            "id": task.id.uuidString,
            "name": task.name,
            "isCompleted": task.isCompleted,
            "createdAt": Timestamp(date: task.createdAt)
        ]

        if let dueDate = task.dueDate {
            // Store date at midnight (date-only)
            let calendar = Calendar.current
            let dateOnly = calendar.startOfDay(for: dueDate)
            data["dueDate"] = Timestamp(date: dateOnly)
        }

        if let dueTime = task.dueTime {
            data["dueTime"] = [
                "hour": dueTime.hour,
                "minute": dueTime.minute
            ]
        }

        if let completedAt = task.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        if let priority = task.priority {
            data["priority"] = [
                "id": priority.id.uuidString,
                "name": priority.name,
                "colorHex": priority.color.toHexString()
            ]
        }

        if let timeBlockId = task.timeBlockId {
            data["timeBlockId"] = timeBlockId.uuidString
        }

        if let projectId = task.projectId {
            data["projectId"] = projectId.uuidString
        }

        return data
    }

    private func documentToTask(_ document: DocumentSnapshot) -> FlowTask? {
        guard let data = document.data(),
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String else {
            return nil
        }

        let isCompleted = data["isCompleted"] as? Bool ?? false
        let completedAt = (data["completedAt"] as? Timestamp)?.dateValue()
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        // Handle dueDate and dueTime with migration
        var dueDate: Date? = nil
        var dueTime: DueTime? = nil

        if let timestamp = data["dueDate"] as? Timestamp {
            let fullDate = timestamp.dateValue()
            let calendar = Calendar.current

            // Check for new format (dueTime field exists)
            if let timeData = data["dueTime"] as? [String: Any],
               let hour = timeData["hour"] as? Int,
               let minute = timeData["minute"] as? Int {
                dueDate = calendar.startOfDay(for: fullDate)
                dueTime = DueTime(hour: hour, minute: minute)
            } else {
                // Migration: Check if old dueDate has time component
                let hour = calendar.component(.hour, from: fullDate)
                let minute = calendar.component(.minute, from: fullDate)

                dueDate = calendar.startOfDay(for: fullDate)

                // Only create dueTime if there was actually a time set (not midnight)
                if hour != 0 || minute != 0 {
                    dueTime = DueTime(hour: hour, minute: minute)
                }
            }
        }

        var priority: Priority?
        if let priorityData = data["priority"] as? [String: Any],
           let priorityIdString = priorityData["id"] as? String,
           let priorityId = UUID(uuidString: priorityIdString),
           let priorityName = priorityData["name"] as? String,
           let colorHex = priorityData["colorHex"] as? String {
            priority = Priority(id: priorityId, name: priorityName, color: Color.fromHex(colorHex), hoursPerWeek: 0)
        }

        var timeBlockId: UUID?
        if let timeBlockIdString = data["timeBlockId"] as? String {
            timeBlockId = UUID(uuidString: timeBlockIdString)
        }

        var projectId: UUID?
        if let projectIdString = data["projectId"] as? String {
            projectId = UUID(uuidString: projectIdString)
        }

        return FlowTask(
            id: id,
            name: name,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority,
            timeBlockId: timeBlockId,
            projectId: projectId,
            isCompleted: isCompleted,
            completedAt: completedAt,
            createdAt: createdAt
        )
    }
}
