import Foundation
import FirebaseFirestore

// MARK: - Activity Log Repository
class ActivityLogRepository {
    static let shared = ActivityLogRepository()

    private let firebase = FirebaseConfig.shared

    private init() {}

    // MARK: - Create Activity Log
    func createActivityLog(_ log: ActivityLog, userId: String) async throws {
        let data = logToDocument(log)
        try await firebase.activityLogsCollection(userId: userId).document(log.id.uuidString).setData(data)
    }

    // MARK: - Get Activity Logs
    func getActivityLogs(userId: String, limit: Int = 100) async throws -> [ActivityLog] {
        let snapshot = try await firebase.activityLogsCollection(userId: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { documentToLog($0) }
    }

    // MARK: - Delete Activity Logs
    func deleteActivityLogs(userId: String, olderThan date: Date) async throws {
        let snapshot = try await firebase.activityLogsCollection(userId: userId)
            .whereField("timestamp", isLessThan: Timestamp(date: date))
            .getDocuments()

        let batch = firebase.db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    // MARK: - Delete All Activity Logs
    func deleteAllActivityLogs(userId: String) async throws {
        let snapshot = try await firebase.activityLogsCollection(userId: userId).getDocuments()

        let batch = firebase.db.batch()
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }
        try await batch.commit()
    }

    // MARK: - Listen to Activity Logs
    func listenToActivityLogs(userId: String, limit: Int = 100, onChange: @escaping ([ActivityLog]) -> Void) -> ListenerRegistration {
        return firebase.activityLogsCollection(userId: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("[ActivityLogRepository] Error: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                let logs = documents.compactMap { self.documentToLog($0) }
                onChange(logs)
            }
    }

    // MARK: - Helpers
    private func logToDocument(_ log: ActivityLog) -> [String: Any] {
        return [
            "id": log.id.uuidString,
            "taskId": log.taskId.uuidString,
            "taskName": log.taskName,
            "action": log.action.rawValue,
            "timestamp": Timestamp(date: log.timestamp)
        ]
    }

    private func documentToLog(_ document: DocumentSnapshot) -> ActivityLog? {
        guard let data = document.data(),
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let taskIdString = data["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString),
              let taskName = data["taskName"] as? String,
              let actionString = data["action"] as? String,
              let action = ActivityLog.Action(rawValue: actionString),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return ActivityLog(id: id, taskId: taskId, taskName: taskName, action: action, timestamp: timestamp)
    }
}
