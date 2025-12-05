import SwiftUI

// MARK: - Time Block Model
struct TimeBlock: Identifiable, Equatable {
    let id: UUID
    var priorityId: UUID
    var priorityName: String
    var priorityColor: Color
    var startTime: Date
    var endTime: Date
    var earlyReminders: [Int] // minutes before start
    var createdAt: Date

    init(
        id: UUID = UUID(),
        priorityId: UUID,
        priorityName: String,
        priorityColor: Color,
        startTime: Date,
        endTime: Date,
        earlyReminders: [Int] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.priorityId = priorityId
        self.priorityName = priorityName
        self.priorityColor = priorityColor
        self.startTime = startTime
        self.endTime = endTime
        self.earlyReminders = earlyReminders
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationInMinutes: Int {
        Int(duration / 60)
    }

    var durationInHours: Double {
        duration / 3600
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }

    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: endTime)
    }

    var formattedTimeRange: String {
        "\(formattedStartTime) - \(formattedEndTime)"
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(startTime)
    }

    var isPast: Bool {
        let now = Date()
        let calendar = Calendar.current

        // If block is not today, check if the entire day is in the past
        if !calendar.isDate(endTime, inSameDayAs: now) {
            return endTime < calendar.startOfDay(for: now)
        }

        return endTime < now
    }

    var isActive: Bool {
        let now = Date()
        let calendar = Calendar.current

        // Only active if the block is for today and current time is within the block
        guard calendar.isDate(startTime, inSameDayAs: now) else {
            return false
        }

        return startTime <= now && now <= endTime
    }

    var isFuture: Bool {
        let now = Date()
        return startTime > now
    }
}
