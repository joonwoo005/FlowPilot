import SwiftUI

// MARK: - Priority Model
struct Priority: Identifiable, Equatable {
    let id: UUID
    var name: String
    var color: Color
    var hoursPerWeek: Double

    static let defaultPriorities: [Priority] = [
        Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 40),
        Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 7),
        Priority(id: UUID(), name: "Learning", color: .priorityPurple, hoursPerWeek: 5),
        Priority(id: UUID(), name: "Relationships", color: .priorityPink, hoursPerWeek: 10),
    ]

    static let availableColors: [Color] = [
        .priorityBlue,
        .priorityPurple,
        .priorityGreen,
        .priorityOrange,
        .priorityPink,
        .priorityCyan
    ]
}

// MARK: - Sleep Schedule
struct SleepSchedule {
    var wakeTime: Date
    var sleepTime: Date

    var availableHoursPerDay: Double {
        let calendar = Calendar.current
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let sleepComponents = calendar.dateComponents([.hour, .minute], from: sleepTime)

        let wakeMinutes = (wakeComponents.hour ?? 7) * 60 + (wakeComponents.minute ?? 0)
        let sleepMinutes = (sleepComponents.hour ?? 23) * 60 + (sleepComponents.minute ?? 0)

        let totalMinutes = sleepMinutes - wakeMinutes
        return max(0, Double(totalMinutes) / 60.0)
    }

    var availableHoursPerWeek: Double {
        availableHoursPerDay * 7
    }

    static let `default`: SleepSchedule = {
        let calendar = Calendar.current
        var wakeComponents = DateComponents()
        wakeComponents.hour = 7
        wakeComponents.minute = 0

        var sleepComponents = DateComponents()
        sleepComponents.hour = 23
        sleepComponents.minute = 0

        return SleepSchedule(
            wakeTime: calendar.date(from: wakeComponents) ?? Date(),
            sleepTime: calendar.date(from: sleepComponents) ?? Date()
        )
    }()
}

// MARK: - Onboarding State
class OnboardingState: ObservableObject {
    @Published var userName: String = ""
    @Published var priorities: [Priority] = Priority.defaultPriorities
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
