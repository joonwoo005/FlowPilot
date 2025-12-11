import SwiftUI
import Combine
import FirebaseFirestore

// MARK: - Project Store
class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []

    private var userId: String?
    private var projectListener: ListenerRegistration?

    // MARK: - Firestore Sync

    func startListening(userId: String) {
        self.userId = userId
        stopListening()

        projectListener = ProjectRepository.shared.listenToProjects(userId: userId) { [weak self] projects in
            DispatchQueue.main.async {
                self?.projects = projects
            }
        }
    }

    func stopListening() {
        projectListener?.remove()
        projectListener = nil
    }

    deinit {
        stopListening()
    }

    // MARK: - Project Actions

    func addProject(name: String, color: Color, icon: String) {
        let project = Project(
            name: name,
            color: color,
            icon: icon
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            projects.append(project)
        }

        if let userId = userId {
            Task {
                try? await ProjectRepository.shared.createProject(project, userId: userId)
            }
        }
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                projects[index] = project
            }
        }

        if let userId = userId {
            Task {
                try? await ProjectRepository.shared.updateProject(project, userId: userId)
            }
        }
    }

    func deleteProject(_ project: Project) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            projects.removeAll { $0.id == project.id }
        }

        if let userId = userId {
            Task {
                try? await ProjectRepository.shared.deleteProject(projectId: project.id, userId: userId)
            }
        }
    }

    func project(for id: UUID) -> Project? {
        projects.first { $0.id == id }
    }
}
