import Foundation
import FirebaseFirestore

// MARK: - User Data Model
struct UserData: Codable {
    var uid: String
    var email: String
    var displayName: String
    var photoURL: String?
    var isAnonymous: Bool
    var wakeTime: Date?
    var sleepTime: Date?
    var hasCompletedOnboarding: Bool
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case uid, email, displayName, photoURL, isAnonymous
        case wakeTime, sleepTime, hasCompletedOnboarding
        case createdAt, updatedAt
    }
}

// MARK: - User Repository
class UserRepository {
    static let shared = UserRepository()

    private let firebase = FirebaseConfig.shared

    private init() {}

    // MARK: - Get User
    func getUser(userId: String) async throws -> UserData? {
        let document = try await firebase.userDocument(userId: userId).getDocument()

        guard document.exists, let data = document.data() else {
            return nil
        }

        return try parseUserData(from: data, uid: userId)
    }

    // MARK: - Update User Profile
    func updateUserProfile(userId: String, displayName: String) async throws {
        let data: [String: Any] = [
            "displayName": displayName,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await firebase.userDocument(userId: userId).updateData(data)
    }

    // MARK: - Update Sleep Schedule
    func updateSleepSchedule(userId: String, wakeTime: Date, sleepTime: Date) async throws {
        let data: [String: Any] = [
            "wakeTime": Timestamp(date: wakeTime),
            "sleepTime": Timestamp(date: sleepTime),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await firebase.userDocument(userId: userId).updateData(data)
    }

    // MARK: - Mark Onboarding Complete
    func markOnboardingComplete(userId: String) async throws {
        let data: [String: Any] = [
            "hasCompletedOnboarding": true,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await firebase.userDocument(userId: userId).updateData(data)
    }

    // MARK: - Parse User Data
    private func parseUserData(from data: [String: Any], uid: String) throws -> UserData {
        UserData(
            uid: uid,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String ?? "",
            photoURL: data["photoURL"] as? String,
            isAnonymous: data["isAnonymous"] as? Bool ?? false,
            wakeTime: (data["wakeTime"] as? Timestamp)?.dateValue(),
            sleepTime: (data["sleepTime"] as? Timestamp)?.dateValue(),
            hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
