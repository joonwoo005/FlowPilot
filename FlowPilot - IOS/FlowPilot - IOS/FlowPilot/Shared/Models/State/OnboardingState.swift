import SwiftUI
import Combine

// MARK: - Onboarding State
class OnboardingState: ObservableObject {
    @Published var userName: String = ""
    @Published var priorities: [Priority] = []
    @Published var sleepSchedule: SleepSchedule = .default

    private var priorityListener: Any?

    static let maxPriorities = 10

    var isNameValid: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canAddPriority: Bool {
        priorities.count < Self.maxPriorities
    }

    var totalAllocatedHours: Double {
        priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    var remainingHours: Double {
        sleepSchedule.availableHoursPerWeek - totalAllocatedHours
    }

    // MARK: - Priority CRUD Operations

    func addPriority(_ priority: Priority) {
        guard canAddPriority else { return }
        priorities.append(priority)
        Task {
            await persistPriority(priority)
        }
    }

    func updatePriority(_ priority: Priority) {
        if let index = priorities.firstIndex(where: { $0.id == priority.id }) {
            priorities[index] = priority
            Task {
                await persistPriority(priority)
            }
        }
    }

    func deletePriority(_ priorityId: UUID) {
        priorities.removeAll { $0.id == priorityId }
        Task {
            await removePriority(priorityId)
        }
    }

    func reorderPriorities(from source: IndexSet, to destination: Int) {
        priorities.move(fromOffsets: source, toOffset: destination)
        Task {
            await persistAllPriorities()
        }
    }

    // MARK: - Firebase Persistence

    private func persistPriority(_ priority: Priority) async {
        guard let userId = FirebaseConfig.shared.currentUserId else { return }
        do {
            try await PriorityRepository.shared.updatePriority(priority, userId: userId)
        } catch {
            // If update fails (document doesn't exist), try create
            do {
                try await PriorityRepository.shared.createPriority(priority, userId: userId)
            } catch {
                print("[OnboardingState] Failed to persist priority: \(error)")
            }
        }
    }

    private func removePriority(_ priorityId: UUID) async {
        guard let userId = FirebaseConfig.shared.currentUserId else { return }
        do {
            try await PriorityRepository.shared.deletePriority(priorityId: priorityId, userId: userId)
        } catch {
            print("[OnboardingState] Failed to delete priority: \(error)")
        }
    }

    private func persistAllPriorities() async {
        guard let userId = FirebaseConfig.shared.currentUserId else { return }
        do {
            try await PriorityRepository.shared.batchSavePriorities(priorities, userId: userId)
        } catch {
            print("[OnboardingState] Failed to batch save priorities: \(error)")
        }
    }

    // MARK: - Sleep Schedule Persistence

    func saveSleepSchedule() {
        // Persist to UserDefaults for now
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(sleepSchedule) {
            UserDefaults.standard.set(data, forKey: "sleepSchedule")
        }
    }

    func loadSleepSchedule() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "sleepSchedule"),
           let schedule = try? decoder.decode(SleepSchedule.self, from: data) {
            sleepSchedule = schedule
        }
    }
}
