import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Project Repository
class ProjectRepository {
    static let shared = ProjectRepository()

    private let firebase = FirebaseConfig.shared

    private init() {}

    // MARK: - Create Project
    func createProject(_ project: Project, userId: String) async throws {
        let data = projectToDocument(project)
        try await firebase.projectsCollection(userId: userId).document(project.id.uuidString).setData(data)
    }

    // MARK: - Update Project
    func updateProject(_ project: Project, userId: String) async throws {
        var data = projectToDocument(project)
        data["updatedAt"] = FieldValue.serverTimestamp()
        try await firebase.projectsCollection(userId: userId).document(project.id.uuidString).updateData(data)
    }

    // MARK: - Delete Project
    func deleteProject(projectId: UUID, userId: String) async throws {
        try await firebase.projectsCollection(userId: userId).document(projectId.uuidString).delete()
    }

    // MARK: - Get All Projects
    func getAllProjects(userId: String) async throws -> [Project] {
        let snapshot = try await firebase.projectsCollection(userId: userId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { documentToProject($0) }
    }

    // MARK: - Listen to Projects
    func listenToProjects(userId: String, onChange: @escaping ([Project]) -> Void) -> ListenerRegistration {
        return firebase.projectsCollection(userId: userId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("[ProjectRepository] Error listening to projects: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                let projects = documents.compactMap { self.documentToProject($0) }
                onChange(projects)
            }
    }

    // MARK: - Helpers
    private func projectToDocument(_ project: Project) -> [String: Any] {
        return [
            "id": project.id.uuidString,
            "name": project.name,
            "colorHex": project.color.toHexString(),
            "icon": project.icon,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }

    private func documentToProject(_ document: DocumentSnapshot) -> Project? {
        guard let data = document.data(),
              let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let colorHex = data["colorHex"] as? String else {
            return nil
        }

        let icon = data["icon"] as? String ?? "folder.fill"
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return Project(id: id, name: name, color: Color.fromHex(colorHex), icon: icon, createdAt: createdAt)
    }
}
