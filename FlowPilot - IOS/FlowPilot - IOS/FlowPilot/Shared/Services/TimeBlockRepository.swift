import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Time Block Repository
class TimeBlockRepository {
    static let shared = TimeBlockRepository()

    private let firebase = FirebaseConfig.shared

    private init() {}

    // MARK: - Create Time Block
    func createTimeBlock(_ block: TimeBlock, userId: String) async throws {
        let data = blockToDocument(block)
        try await firebase.timeBlocksCollection(userId: userId).document(block.id.uuidString).setData(data)
    }

    // MARK: - Update Time Block
    func updateTimeBlock(_ block: TimeBlock, userId: String) async throws {
        var data = blockToDocument(block)
        data["updatedAt"] = FieldValue.serverTimestamp()
        try await firebase.timeBlocksCollection(userId: userId).document(block.id.uuidString).updateData(data)
    }

    // MARK: - Delete Time Block
    func deleteTimeBlock(blockId: UUID, userId: String) async throws {
        try await firebase.timeBlocksCollection(userId: userId).document(blockId.uuidString).delete()
    }

    // MARK: - Get All Time Blocks
    func getAllTimeBlocks(userId: String) async throws -> [TimeBlock] {
        let snapshot = try await firebase.timeBlocksCollection(userId: userId).getDocuments()
        return snapshot.documents.compactMap { documentToBlock($0) }
    }

    // MARK: - Get Time Blocks for Date Range
    func getTimeBlocks(userId: String, from startDate: Date, to endDate: Date) async throws -> [TimeBlock] {
        let snapshot = try await firebase.timeBlocksCollection(userId: userId)
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        return snapshot.documents.compactMap { documentToBlock($0) }
    }

    // MARK: - Listen to Time Blocks
    func listenToTimeBlocks(userId: String, onChange: @escaping ([TimeBlock]) -> Void) -> ListenerRegistration {
        return firebase.timeBlocksCollection(userId: userId)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("[TimeBlockRepository] Error listening to blocks: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                let blocks = documents.compactMap { self.documentToBlock($0) }
                onChange(blocks)
            }
    }

    // MARK: - Batch Save Time Blocks
    func batchSaveTimeBlocks(_ blocks: [TimeBlock], userId: String) async throws {
        let batch = firebase.db.batch()

        for block in blocks {
            let ref = firebase.timeBlocksCollection(userId: userId).document(block.id.uuidString)
            let data = blockToDocument(block)
            batch.setData(data, forDocument: ref, merge: true)
        }

        try await batch.commit()
    }

    // MARK: - Batch Delete Time Blocks
    func batchDeleteTimeBlocks(_ blockIds: [UUID], userId: String) async throws {
        guard !blockIds.isEmpty else { return }

        let batch = firebase.db.batch()

        for blockId in blockIds {
            let ref = firebase.timeBlocksCollection(userId: userId).document(blockId.uuidString)
            batch.deleteDocument(ref)
        }

        try await batch.commit()
    }

    // MARK: - Batch Update Time Blocks
    func batchUpdateTimeBlocks(_ blocks: [TimeBlock], userId: String) async throws {
        guard !blocks.isEmpty else { return }

        let batch = firebase.db.batch()

        for block in blocks {
            let ref = firebase.timeBlocksCollection(userId: userId).document(block.id.uuidString)
            var data = blockToDocument(block)
            data["updatedAt"] = FieldValue.serverTimestamp()
            batch.updateData(data, forDocument: ref)
        }

        try await batch.commit()
    }

    // MARK: - Delete Past Time Blocks
    func deletePastTimeBlocks(userId: String, olderThan date: Date) async throws {
        let snapshot = try await firebase.timeBlocksCollection(userId: userId)
            .whereField("endTime", isLessThan: Timestamp(date: date))
            .getDocuments()

        let batch = firebase.db.batch()

        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await batch.commit()
    }

    // MARK: - Helpers
    private func blockToDocument(_ block: TimeBlock) -> [String: Any] {
        var data: [String: Any] = [
            "id": block.id.uuidString,
            "priorityId": block.priorityId.uuidString,
            "priorityName": block.priorityName,
            "priorityColorHex": block.priorityColor.toHex() ?? "8B5CF6",
            "startTime": Timestamp(date: block.startTime),
            "endTime": Timestamp(date: block.endTime),
            "earlyReminders": block.earlyReminders,
            "createdAt": Timestamp(date: block.createdAt)
        ]

        if let recurrenceId = block.recurrenceId {
            data["recurrenceId"] = recurrenceId.uuidString
        }

        if let recurringDays = block.recurringDays {
            data["recurringDays"] = Array(recurringDays)
        }

        return data
    }

    private func documentToBlock(_ document: DocumentSnapshot) -> TimeBlock? {
        guard let data = document.data(),
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let priorityIdString = data["priorityId"] as? String,
              let priorityId = UUID(uuidString: priorityIdString),
              let priorityName = data["priorityName"] as? String,
              let priorityColorHex = data["priorityColorHex"] as? String,
              let startTimestamp = data["startTime"] as? Timestamp,
              let endTimestamp = data["endTime"] as? Timestamp else {
            return nil
        }

        let earlyReminders = data["earlyReminders"] as? [Int] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        var recurrenceId: UUID?
        if let recurrenceIdString = data["recurrenceId"] as? String {
            recurrenceId = UUID(uuidString: recurrenceIdString)
        }

        var recurringDays: Set<Int>?
        if let days = data["recurringDays"] as? [Int] {
            recurringDays = Set(days)
        }

        return TimeBlock(
            id: id,
            priorityId: priorityId,
            priorityName: priorityName,
            priorityColor: Color(hex: priorityColorHex),
            startTime: startTimestamp.dateValue(),
            endTime: endTimestamp.dateValue(),
            earlyReminders: earlyReminders,
            createdAt: createdAt,
            recurrenceId: recurrenceId,
            recurringDays: recurringDays
        )
    }
}
