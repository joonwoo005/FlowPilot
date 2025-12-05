import Foundation
import FirebaseFirestore

// MARK: - Priority Repository
class PriorityRepository {
    static let shared = PriorityRepository()

    private let firebase = FirebaseConfig.shared

    private init() {}

    // MARK: - Create Priority
    func createPriority(_ priority: Priority, userId: String) async throws {
        let data = priorityToDocument(priority)
        try await firebase.prioritiesCollection(userId: userId).document(priority.id.uuidString).setData(data)
    }

    // MARK: - Update Priority
    func updatePriority(_ priority: Priority, userId: String) async throws {
        var data = priorityToDocument(priority)
        data["updatedAt"] = FieldValue.serverTimestamp()
        try await firebase.prioritiesCollection(userId: userId).document(priority.id.uuidString).updateData(data)
    }

    // MARK: - Delete Priority
    func deletePriority(priorityId: UUID, userId: String) async throws {
        try await firebase.prioritiesCollection(userId: userId).document(priorityId.uuidString).delete()
    }

    // MARK: - Get All Priorities
    func getAllPriorities(userId: String) async throws -> [Priority] {
        let snapshot = try await firebase.prioritiesCollection(userId: userId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { documentToPriority($0) }
    }

    // MARK: - Listen to Priorities
    func listenToPriorities(userId: String, onChange: @escaping ([Priority]) -> Void) -> ListenerRegistration {
        return firebase.prioritiesCollection(userId: userId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("[PriorityRepository] Error listening to priorities: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                let priorities = documents.compactMap { self.documentToPriority($0) }
                onChange(priorities)
            }
    }

    // MARK: - Batch Save Priorities
    func batchSavePriorities(_ priorities: [Priority], userId: String) async throws {
        let batch = firebase.db.batch()

        for priority in priorities {
            let ref = firebase.prioritiesCollection(userId: userId).document(priority.id.uuidString)
            let data = priorityToDocument(priority)
            batch.setData(data, forDocument: ref, merge: true)
        }

        try await batch.commit()
    }

    // MARK: - Helpers
    private func priorityToDocument(_ priority: Priority) -> [String: Any] {
        return [
            "id": priority.id.uuidString,
            "name": priority.name,
            "colorHex": priority.colorHex,
            "hoursPerWeek": priority.hoursPerWeek,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }

    private func documentToPriority(_ document: DocumentSnapshot) -> Priority? {
        guard let data = document.data(),
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let colorHex = data["colorHex"] as? String else {
            return nil
        }

        let hoursPerWeek = data["hoursPerWeek"] as? Double ?? 0

        return Priority(id: id, name: name, colorHex: colorHex, hoursPerWeek: hoursPerWeek)
    }
}
