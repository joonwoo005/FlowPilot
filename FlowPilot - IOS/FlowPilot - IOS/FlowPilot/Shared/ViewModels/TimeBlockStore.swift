import SwiftUI
import Combine

// MARK: - Time Block Store
class TimeBlockStore: ObservableObject {
    @Published var timeBlocks: [TimeBlock] = []

    private let userDefaultsKey = "savedTimeBlocks"

    init() {
        loadFromUserDefaults()
    }

    // MARK: - Computed Properties

    var todayBlocks: [TimeBlock] {
        timeBlocks
            .filter { $0.isToday }
            .sorted { $0.startTime < $1.startTime }
    }

    var upcomingBlocks: [TimeBlock] {
        let now = Date()
        return todayBlocks.filter { $0.endTime > now }
    }

    var activeBlock: TimeBlock? {
        todayBlocks.first { $0.isActive }
    }

    var totalPlannedHoursToday: Double {
        todayBlocks.reduce(0) { $0 + $1.durationInHours }
    }

    // MARK: - Actions

    func addBlock(_ block: TimeBlock) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            timeBlocks.append(block)
        }
        saveToUserDefaults()
    }

    func addBlock(
        priority: Priority,
        startTime: Date,
        endTime: Date,
        earlyReminders: [Int] = []
    ) {
        let block = TimeBlock(
            priorityId: priority.id,
            priorityName: priority.name,
            priorityColor: priority.color,
            startTime: startTime,
            endTime: endTime,
            earlyReminders: earlyReminders
        )
        addBlock(block)
    }

    func deleteBlock(_ block: TimeBlock) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            timeBlocks.removeAll { $0.id == block.id }
        }

        // Cancel any scheduled notifications for this block
        NotificationService.shared.cancelTimeBlockNotifications(blockId: block.id)

        saveToUserDefaults()
    }

    func updateBlock(_ block: TimeBlock) {
        if let index = timeBlocks.firstIndex(where: { $0.id == block.id }) {
            timeBlocks[index] = block
            saveToUserDefaults()
        }
    }

    // MARK: - Blocks for a specific date

    func blocks(for date: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        return timeBlocks
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Persistence (UserDefaults for now)

    private func saveToUserDefaults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(timeBlocks.map { CodableTimeBlock(from: $0) }) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([CodableTimeBlock].self, from: data) {
            timeBlocks = decoded.map { $0.toTimeBlock() }
        }
    }

    // MARK: - Clear old blocks

    func clearPastBlocks() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            timeBlocks.removeAll { $0.endTime < startOfToday }
        }
        saveToUserDefaults()
    }
}

// MARK: - Codable wrapper for persistence
private struct CodableTimeBlock: Codable {
    let id: UUID
    let priorityId: UUID
    let priorityName: String
    let priorityColorHex: String
    let startTime: Date
    let endTime: Date
    let earlyReminders: [Int]
    let createdAt: Date

    init(from block: TimeBlock) {
        self.id = block.id
        self.priorityId = block.priorityId
        self.priorityName = block.priorityName
        self.priorityColorHex = block.priorityColor.toHex() ?? "8B5CF6"
        self.startTime = block.startTime
        self.endTime = block.endTime
        self.earlyReminders = block.earlyReminders
        self.createdAt = block.createdAt
    }

    func toTimeBlock() -> TimeBlock {
        TimeBlock(
            id: id,
            priorityId: priorityId,
            priorityName: priorityName,
            priorityColor: Color(hex: priorityColorHex),
            startTime: startTime,
            endTime: endTime,
            earlyReminders: earlyReminders,
            createdAt: createdAt
        )
    }
}

// MARK: - Color Hex Extension
extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }

        let r = components[0]
        let g = components.count >= 3 ? components[1] : r
        let b = components.count >= 3 ? components[2] : r

        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
