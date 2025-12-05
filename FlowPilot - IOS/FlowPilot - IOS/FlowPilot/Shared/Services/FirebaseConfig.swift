import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// MARK: - Firebase Configuration
class FirebaseConfig {
    static let shared = FirebaseConfig()

    private(set) var isConfigured = false

    private init() {}

    func configure() {
        guard !isConfigured else { return }
        FirebaseApp.configure()
        isConfigured = true

        #if DEBUG
        print("[Firebase] Configured successfully")
        #endif
    }

    // MARK: - Firestore Reference
    var db: Firestore {
        Firestore.firestore()
    }

    // MARK: - Auth Reference
    var auth: Auth {
        Auth.auth()
    }

    // MARK: - Current User ID
    var currentUserId: String? {
        auth.currentUser?.uid
    }

    // MARK: - Collection References
    func userDocument(userId: String) -> DocumentReference {
        db.collection("users").document(userId)
    }

    func tasksCollection(userId: String) -> CollectionReference {
        userDocument(userId: userId).collection("tasks")
    }

    func prioritiesCollection(userId: String) -> CollectionReference {
        userDocument(userId: userId).collection("priorities")
    }

    func activityLogsCollection(userId: String) -> CollectionReference {
        userDocument(userId: userId).collection("activityLogs")
    }

    func timeBlocksCollection(userId: String) -> CollectionReference {
        userDocument(userId: userId).collection("timeBlocks")
    }

    func projectsCollection(userId: String) -> CollectionReference {
        userDocument(userId: userId).collection("projects")
    }
}
