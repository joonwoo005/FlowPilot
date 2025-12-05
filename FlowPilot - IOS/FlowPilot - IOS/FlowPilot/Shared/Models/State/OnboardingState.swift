import SwiftUI
import Combine

// MARK: - Onboarding State
class OnboardingState: ObservableObject {
    @Published var userName: String = ""
    @Published var priorities: [Priority] = []
    @Published var sleepSchedule: SleepSchedule = .default

    var isNameValid: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var totalAllocatedHours: Double {
        priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    var remainingHours: Double {
        sleepSchedule.availableHoursPerWeek - totalAllocatedHours
    }
}
