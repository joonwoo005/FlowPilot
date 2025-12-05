import Foundation

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
