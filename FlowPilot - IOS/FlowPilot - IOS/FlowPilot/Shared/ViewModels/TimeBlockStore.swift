import SwiftUI
import Combine
import WidgetKit
import FirebaseFirestore
#if os(iOS)
import ActivityKit
#endif

// MARK: - App Group Configuration
enum AppGroupConfig {
    static let suiteName = "group.com.flowpilot.ios"
    static let timeBlocksKey = "savedTimeBlocks"
    static let widgetDataKey = "widgetTimeBlockData"
    static let calendarWidgetDataKey = "calendarWidgetData"
}

// MARK: - Time Block Store
class TimeBlockStore: ObservableObject {
    @Published var timeBlocks: [TimeBlock] = []

    /// Trigger for forcing view refreshes when app returns to foreground
    @Published var refreshTrigger = UUID()

    private let userDefaultsKey = AppGroupConfig.timeBlocksKey

    // Firestore sync
    private var listener: ListenerRegistration?
    private var currentUserId: String?

    // Shared UserDefaults for widget access
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConfig.suiteName)
    }

    init() {
        loadFromUserDefaults()
        // Update widget data on launch
        updateWidgetData()
        updateCalendarWidgetData()
        refreshWidgets()
    }

    deinit {
        stopListening()
    }

    // MARK: - Firestore Sync

    /// Start listening to Firestore for real-time sync
    func startListening(userId: String) {
        // Don't restart if already listening for same user
        if currentUserId == userId && listener != nil { return }

        stopListening()
        currentUserId = userId

        listener = TimeBlockRepository.shared.listenToTimeBlocks(userId: userId) { [weak self] (blocks: [TimeBlock]) in
            DispatchQueue.main.async {
                self?.timeBlocks = blocks.sorted { $0.startTime < $1.startTime }
                self?.saveToUserDefaults() // Keep local cache for widgets
                self?.updateWidgetData()
                self?.updateCalendarWidgetData()
                self?.refreshWidgets()
            }
        }

        #if DEBUG
        print("[TimeBlockStore] Started listening for user: \(userId)")
        #endif
    }

    /// Stop listening to Firestore
    func stopListening() {
        listener?.remove()
        listener = nil
        currentUserId = nil

        #if DEBUG
        print("[TimeBlockStore] Stopped listening")
        #endif
    }

    /// Load initial data from Firestore
    func loadFromFirestore(userId: String) async {
        do {
            let blocks = try await TimeBlockRepository.shared.getAllTimeBlocks(userId: userId)
            await MainActor.run {
                self.timeBlocks = blocks.sorted { $0.startTime < $1.startTime }
                self.saveToUserDefaults()
                self.updateWidgetData()
                self.updateCalendarWidgetData()
                self.refreshWidgets()
            }
            #if DEBUG
            print("[TimeBlockStore] Loaded \(blocks.count) blocks from Firestore")
            #endif
        } catch {
            print("[TimeBlockStore] Error loading from Firestore: \(error.localizedDescription)")
        }
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

        // Sync to Firestore
        if let userId = currentUserId {
            Task {
                do {
                    try await TimeBlockRepository.shared.createTimeBlock(block, userId: userId)
                } catch {
                    print("[TimeBlockStore] Error saving block to Firestore: \(error.localizedDescription)")
                }
            }
        }

        // Schedule Live Activity for this block if it's upcoming today
        #if os(iOS)
        LiveActivityService.shared.scheduleUpcomingBlocks(timeBlocks)
        #endif
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

    /// Add recurring blocks for selected days of the week (next 12 weeks)
    func addRecurringBlock(
        priority: Priority,
        startTime: Date,
        endTime: Date,
        earlyReminders: [Int] = [],
        recurringDays: Set<Int> // 1=Sun, 2=Mon...7=Sat
    ) {
        guard !recurringDays.isEmpty else { return }

        let recurrenceId = UUID()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get time components from startTime and endTime
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        var blocksToAdd: [TimeBlock] = []

        // Generate blocks for the next 12 weeks
        for weekOffset in 0..<12 {
            for dayNumber in recurringDays {
                // Find the next occurrence of this weekday
                guard let targetDate = nextDate(for: dayNumber, from: today, weekOffset: weekOffset) else { continue }

                // Create start and end times for this date
                var blockStartComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                blockStartComponents.hour = startComponents.hour
                blockStartComponents.minute = startComponents.minute

                var blockEndComponents = calendar.dateComponents([.year, .month, .day], from: targetDate)
                blockEndComponents.hour = endComponents.hour
                blockEndComponents.minute = endComponents.minute

                guard let blockStart = calendar.date(from: blockStartComponents),
                      let blockEnd = calendar.date(from: blockEndComponents),
                      blockStart >= Date() else { continue }

                let block = TimeBlock(
                    priorityId: priority.id,
                    priorityName: priority.name,
                    priorityColor: priority.color,
                    startTime: blockStart,
                    endTime: blockEnd,
                    earlyReminders: earlyReminders,
                    recurrenceId: recurrenceId,
                    recurringDays: recurringDays
                )
                blocksToAdd.append(block)
            }
        }

        // Add all blocks
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            timeBlocks.append(contentsOf: blocksToAdd)
        }
        saveToUserDefaults()

        // Sync to Firestore
        if let userId = currentUserId {
            Task {
                do {
                    try await TimeBlockRepository.shared.batchSaveTimeBlocks(blocksToAdd, userId: userId)
                } catch {
                    print("[TimeBlockStore] Error saving recurring blocks to Firestore: \(error.localizedDescription)")
                }
            }
        }

        // Schedule notifications for all new blocks
        for block in blocksToAdd {
            NotificationService.shared.scheduleTimeBlockNotifications(
                blockId: block.id,
                title: block.priorityName,
                startTime: block.startTime,
                endTime: block.endTime,
                earlyReminderMinutes: earlyReminders
            )
        }
    }

    /// Helper to find the next occurrence of a weekday (1=Sun...7=Sat) with week offset
    private func nextDate(for weekday: Int, from date: Date, weekOffset: Int) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)

        var daysToAdd = weekday - currentWeekday
        if daysToAdd < 0 {
            daysToAdd += 7
        }
        daysToAdd += (weekOffset * 7)

        return calendar.date(byAdding: .day, value: daysToAdd, to: date)
    }

    func deleteBlock(_ block: TimeBlock) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            timeBlocks.removeAll { $0.id == block.id }
        }

        // Cancel any scheduled notifications for this block
        NotificationService.shared.cancelTimeBlockNotifications(blockId: block.id)

        // Cancel scheduled Live Activity start for this block
        #if os(iOS)
        LiveActivityService.shared.cancelScheduledStart(for: block.id)

        // End Live Activity if this block was being tracked
        Task { @MainActor in
            if let currentActivity = LiveActivityService.shared.currentActivity,
               currentActivity.attributes.blockId == block.id {
                await LiveActivityService.shared.endCurrentActivity()
            }
        }
        #endif

        saveToUserDefaults()

        // Sync to Firestore
        if let userId = currentUserId {
            Task {
                do {
                    try await TimeBlockRepository.shared.deleteTimeBlock(blockId: block.id, userId: userId)
                } catch {
                    print("[TimeBlockStore] Error deleting block from Firestore: \(error.localizedDescription)")
                }
            }
        }
    }

    func updateBlock(_ block: TimeBlock) {
        if let index = timeBlocks.firstIndex(where: { $0.id == block.id }) {
            timeBlocks[index] = block
            saveToUserDefaults()

            // Sync to Firestore
            if let userId = currentUserId {
                Task {
                    do {
                        try await TimeBlockRepository.shared.updateTimeBlock(block, userId: userId)
                    } catch {
                        print("[TimeBlockStore] Error updating block in Firestore: \(error.localizedDescription)")
                    }
                }
            }

            // Update Live Activity if this block is being tracked
            #if os(iOS)
            Task { @MainActor in
                await LiveActivityService.shared.updateActivityIfNeeded(for: block)
            }
            #endif
        }
    }

    // MARK: - Recurring Block Operations

    /// Delete all future blocks in the same recurring series (including the given block)
    func deleteFutureRecurringBlocks(from block: TimeBlock) {
        guard let recurrenceId = block.recurrenceId else {
            // Not a recurring block, just delete this one
            deleteBlock(block)
            return
        }

        // Find all blocks with the same recurrenceId that start on or after this block
        let blocksToDelete = timeBlocks.filter { existingBlock in
            existingBlock.recurrenceId == recurrenceId &&
            existingBlock.startTime >= block.startTime
        }

        // Cancel notifications and Live Activity for all blocks
        for blockToDelete in blocksToDelete {
            NotificationService.shared.cancelTimeBlockNotifications(blockId: blockToDelete.id)
            #if os(iOS)
            LiveActivityService.shared.cancelScheduledStart(for: blockToDelete.id)
            #endif
        }

        // End Live Activity if current block was being tracked
        #if os(iOS)
        Task { @MainActor in
            if let currentActivity = LiveActivityService.shared.currentActivity,
               blocksToDelete.contains(where: { $0.id == currentActivity.attributes.blockId }) {
                await LiveActivityService.shared.endCurrentActivity()
            }
        }
        #endif

        // Remove from local array
        let idsToDelete = Set(blocksToDelete.map { $0.id })
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            timeBlocks.removeAll { idsToDelete.contains($0.id) }
        }

        saveToUserDefaults()

        // Sync to Firestore
        if let userId = currentUserId {
            Task {
                do {
                    try await TimeBlockRepository.shared.batchDeleteTimeBlocks(Array(idsToDelete), userId: userId)
                } catch {
                    print("[TimeBlockStore] Error batch deleting recurring blocks from Firestore: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Update all future blocks in the same recurring series with new values
    func updateFutureRecurringBlocks(from block: TimeBlock, newPriorityId: UUID, newPriorityName: String, newPriorityColor: Color, newStartTime: Date, newEndTime: Date, newEarlyReminders: [Int]) {
        guard let recurrenceId = block.recurrenceId else {
            // Not a recurring block, just update this one
            var updatedBlock = block
            updatedBlock.priorityId = newPriorityId
            updatedBlock.priorityName = newPriorityName
            updatedBlock.priorityColor = newPriorityColor
            updatedBlock.startTime = newStartTime
            updatedBlock.endTime = newEndTime
            updatedBlock.earlyReminders = newEarlyReminders
            updateBlock(updatedBlock)
            return
        }

        let calendar = Calendar.current

        // Get the new time components to apply to future blocks
        let newStartComponents = calendar.dateComponents([.hour, .minute], from: newStartTime)
        let newEndComponents = calendar.dateComponents([.hour, .minute], from: newEndTime)

        // Find all blocks with the same recurrenceId that start on or after this block
        var blocksToUpdate: [TimeBlock] = []

        for i in 0..<timeBlocks.count {
            let existingBlock = timeBlocks[i]
            guard existingBlock.recurrenceId == recurrenceId,
                  existingBlock.startTime >= block.startTime else { continue }

            var updatedBlock = existingBlock

            // Update priority
            updatedBlock.priorityId = newPriorityId
            updatedBlock.priorityName = newPriorityName
            updatedBlock.priorityColor = newPriorityColor
            updatedBlock.earlyReminders = newEarlyReminders

            // Update times - preserve the date, change the time
            let blockDate = calendar.startOfDay(for: existingBlock.startTime)
            var newStartDateComponents = calendar.dateComponents([.year, .month, .day], from: blockDate)
            newStartDateComponents.hour = newStartComponents.hour
            newStartDateComponents.minute = newStartComponents.minute

            var newEndDateComponents = calendar.dateComponents([.year, .month, .day], from: blockDate)
            newEndDateComponents.hour = newEndComponents.hour
            newEndDateComponents.minute = newEndComponents.minute

            if let newStart = calendar.date(from: newStartDateComponents),
               let newEnd = calendar.date(from: newEndDateComponents) {
                updatedBlock.startTime = newStart
                updatedBlock.endTime = newEnd
            }

            timeBlocks[i] = updatedBlock
            blocksToUpdate.append(updatedBlock)

            // Reschedule notifications
            NotificationService.shared.cancelTimeBlockNotifications(blockId: updatedBlock.id)
            NotificationService.shared.scheduleTimeBlockNotifications(
                blockId: updatedBlock.id,
                title: updatedBlock.priorityName,
                startTime: updatedBlock.startTime,
                endTime: updatedBlock.endTime,
                earlyReminderMinutes: newEarlyReminders
            )
        }

        saveToUserDefaults()

        // Sync to Firestore
        if let userId = currentUserId {
            Task {
                do {
                    try await TimeBlockRepository.shared.batchUpdateTimeBlocks(blocksToUpdate, userId: userId)
                } catch {
                    print("[TimeBlockStore] Error batch updating recurring blocks in Firestore: \(error.localizedDescription)")
                }
            }
        }

        // Update Live Activity if needed
        #if os(iOS)
        if let activeBlock = blocksToUpdate.first(where: { $0.isActive }) {
            Task { @MainActor in
                await LiveActivityService.shared.updateActivityIfNeeded(for: activeBlock)
            }
        }
        #endif
    }

    // MARK: - Live Activity Actions (iOS only)

    /// End a time block early and update the Live Activity
    func endBlockEarly(_ block: TimeBlock) {
        var updatedBlock = block
        updatedBlock.endTime = Date()
        updateBlock(updatedBlock)

        #if os(iOS)
        Task { @MainActor in
            await LiveActivityService.shared.endActivityEarly()
        }
        #endif
    }

    /// Extend a time block by specified minutes and update the Live Activity
    func extendBlock(_ block: TimeBlock, byMinutes minutes: Int = 15) {
        var updatedBlock = block
        updatedBlock.endTime = block.endTime.addingTimeInterval(TimeInterval(minutes * 60))
        updateBlock(updatedBlock)

        #if os(iOS)
        Task { @MainActor in
            await LiveActivityService.shared.extendActivity(by: minutes)
        }
        #endif
    }

    /// Check and start Live Activity for currently active block, and schedule upcoming blocks
    func checkAndStartLiveActivity() {
        #if os(iOS)
        LiveActivityService.shared.checkForActiveBlock(in: timeBlocks)
        #endif
    }

    /// Force all dependent views to refresh their time-based calculations
    func triggerRefresh() {
        refreshTrigger = UUID()
    }

    // MARK: - Blocks for a specific date

    func blocks(for date: Date) -> [TimeBlock] {
        let calendar = Calendar.current
        return timeBlocks
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Conflict Detection

    /// Check if a block overlaps with any other block on the same day
    func hasConflict(_ block: TimeBlock) -> Bool {
        let dayBlocks = blocks(for: block.startTime)
        for other in dayBlocks {
            guard other.id != block.id else { continue }
            // Check for overlap: blocks overlap if one starts before the other ends
            if block.startTime < other.endTime && block.endTime > other.startTime {
                return true
            }
        }
        return false
    }

    /// Get all blocks that overlap with a given block
    func conflictingBlocks(for block: TimeBlock) -> [TimeBlock] {
        let dayBlocks = blocks(for: block.startTime)
        return dayBlocks.filter { other in
            guard other.id != block.id else { return false }
            return block.startTime < other.endTime && block.endTime > other.startTime
        }
    }

    /// Calculate overlap minutes between two blocks
    func overlapMinutes(block1: TimeBlock, block2: TimeBlock) -> Int {
        let overlapStart = max(block1.startTime, block2.startTime)
        let overlapEnd = min(block1.endTime, block2.endTime)
        if overlapStart < overlapEnd {
            return Int(overlapEnd.timeIntervalSince(overlapStart) / 60)
        }
        return 0
    }

    // MARK: - Persistence (Shared UserDefaults for widget access)

    private func saveToUserDefaults() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(timeBlocks.map { CodableTimeBlock(from: $0) }) {
            // Save to shared UserDefaults for widget access
            sharedDefaults?.set(encoded, forKey: userDefaultsKey)
            // Also save to standard defaults as fallback
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }

        // Update widget data and refresh widgets
        updateWidgetData()
        updateCalendarWidgetData()
        refreshWidgets()
    }

    private func loadFromUserDefaults() {
        // Try shared defaults first, then fall back to standard
        let data = sharedDefaults?.data(forKey: userDefaultsKey)
            ?? UserDefaults.standard.data(forKey: userDefaultsKey)

        guard let data = data else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([CodableTimeBlock].self, from: data) {
            timeBlocks = decoded.map { $0.toTimeBlock() }
        }
    }

    // MARK: - Widget Support

    /// Updates the simplified widget data in shared UserDefaults
    private func updateWidgetData() {
        let now = Date()
        let todayBlocks = timeBlocks
            .filter { $0.isToday }
            .sorted { $0.startTime < $1.startTime }

        // Find active or next upcoming block
        let activeBlock = todayBlocks.first { $0.isActive }
        let upcomingBlock = todayBlocks.first { $0.startTime > now }

        let widgetData: WidgetBlockData?

        if let active = activeBlock {
            widgetData = WidgetBlockData(
                priorityName: active.priorityName,
                priorityColorHex: active.priorityColor.toHex() ?? "FF6B5B",
                startTime: active.startTime,
                endTime: active.endTime,
                isActive: true
            )
        } else if let upcoming = upcomingBlock {
            widgetData = WidgetBlockData(
                priorityName: upcoming.priorityName,
                priorityColorHex: upcoming.priorityColor.toHex() ?? "FF6B5B",
                startTime: upcoming.startTime,
                endTime: upcoming.endTime,
                isActive: false
            )
        } else {
            widgetData = nil
        }

        let encoder = JSONEncoder()
        if let widgetData = widgetData,
           let encoded = try? encoder.encode(widgetData) {
            sharedDefaults?.set(encoded, forKey: AppGroupConfig.widgetDataKey)
        } else {
            sharedDefaults?.removeObject(forKey: AppGroupConfig.widgetDataKey)
        }
    }

    /// Triggers a refresh of all FlowPilot widgets
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Updates calendar widget data with all blocks for today and the week
    private func updateCalendarWidgetData() {
        let now = Date()
        let calendar = Calendar.current

        // Get blocks for today
        let todayBlocks = timeBlocks
            .filter { calendar.isDate($0.startTime, inSameDayAs: now) }
            .sorted { $0.startTime < $1.startTime }
            .map { CalendarWidgetBlock(from: $0) }

        // Get blocks for the current week
        let weekStart = startOfWeekMonday(for: now)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return }

        let weekBlocks = timeBlocks
            .filter { $0.startTime >= weekStart && $0.startTime < weekEnd }
            .sorted { $0.startTime < $1.startTime }
            .map { CalendarWidgetBlock(from: $0) }

        let calendarData = CalendarWidgetData(
            todayBlocks: todayBlocks,
            weekBlocks: weekBlocks,
            weekStartDate: weekStart
        )

        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(calendarData) {
            sharedDefaults?.set(encoded, forKey: AppGroupConfig.calendarWidgetDataKey)
        }

        // Also update macOS widget data
        #if os(macOS)
        updateMacWidgetData()
        #endif
    }

    #if os(macOS)
    /// Updates macOS widget data in shared UserDefaults
    private func updateMacWidgetData() {
        let now = Date()
        let calendar = Calendar.current

        // Get blocks for today
        let todayBlocks = timeBlocks
            .filter { calendar.isDate($0.startTime, inSameDayAs: now) }
            .sorted { $0.startTime < $1.startTime }
            .map { block -> [String: Any] in
                [
                    "id": block.id.uuidString,
                    "priorityName": block.priorityName,
                    "priorityColorHex": block.priorityColor.toHex() ?? "FF6B5B",
                    "startTime": block.startTime.timeIntervalSince1970,
                    "endTime": block.endTime.timeIntervalSince1970
                ]
            }

        // Create widget data structure
        struct MacWidgetBlock: Codable {
            let id: UUID
            let priorityName: String
            let priorityColorHex: String
            let startTime: Date
            let endTime: Date
        }

        struct MacWidgetData: Codable {
            let blocks: [MacWidgetBlock]
            let lastUpdated: Date
        }

        let macBlocks = timeBlocks
            .filter { calendar.isDate($0.startTime, inSameDayAs: now) }
            .sorted { $0.startTime < $1.startTime }
            .map { block in
                MacWidgetBlock(
                    id: block.id,
                    priorityName: block.priorityName,
                    priorityColorHex: block.priorityColor.toHex() ?? "FF6B5B",
                    startTime: block.startTime,
                    endTime: block.endTime
                )
            }

        let macWidgetData = MacWidgetData(blocks: macBlocks, lastUpdated: now)

        // Save to macOS app group
        if let macSharedDefaults = UserDefaults(suiteName: "group.com.flowpilot.mac") {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(macWidgetData) {
                macSharedDefaults.set(encoded, forKey: "macWidgetTimeBlockData")
            }
        }
    }
    #endif

    // MARK: - Week-based queries (Monday as first day for Calendar view)

    /// Get the start of the week (Monday at 00:00:00) for a given date
    func startOfWeekMonday(for date: Date) -> Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Sunday = 1, Monday = 2, ..., Saturday = 7
        // To get Monday: (weekday - 2 + 7) % 7 days back
        let daysToSubtract = (weekday - 2 + 7) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysToSubtract, to: date) else {
            return date
        }
        return calendar.startOfDay(for: monday)
    }

    /// Get all 7 dates in the week (Mon-Sun) containing the given date
    func datesInWeek(for date: Date) -> [Date] {
        let weekStart = startOfWeekMonday(for: date)
        return (0..<7).compactMap { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }

    /// Get all blocks for a specific week (Monday to Sunday)
    func blocksForWeek(containing date: Date) -> [TimeBlock] {
        let weekStart = startOfWeekMonday(for: date)
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else { return [] }

        return timeBlocks
            .filter { $0.startTime >= weekStart && $0.startTime < weekEnd }
            .sorted { $0.startTime < $1.startTime }
    }

    /// Total planned hours for a week
    func totalHoursForWeek(containing date: Date) -> Double {
        blocksForWeek(containing: date).reduce(0) { $0 + $1.durationInHours }
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
    let recurrenceId: UUID?
    let recurringDays: [Int]? // Stored as array for Codable

    init(from block: TimeBlock) {
        self.id = block.id
        self.priorityId = block.priorityId
        self.priorityName = block.priorityName
        self.priorityColorHex = block.priorityColor.toHex() ?? "8B5CF6"
        self.startTime = block.startTime
        self.endTime = block.endTime
        self.earlyReminders = block.earlyReminders
        self.createdAt = block.createdAt
        self.recurrenceId = block.recurrenceId
        self.recurringDays = block.recurringDays.map { Array($0) }
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
            createdAt: createdAt,
            recurrenceId: recurrenceId,
            recurringDays: recurringDays.map { Set($0) }
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

// MARK: - Widget Data Model (Shared with Widget Extension)
struct WidgetBlockData: Codable {
    let priorityName: String
    let priorityColorHex: String
    let startTime: Date
    let endTime: Date
    let isActive: Bool

    var priorityColor: Color {
        Color(hex: priorityColorHex)
    }

    var timeRemaining: TimeInterval {
        if isActive {
            return endTime.timeIntervalSince(Date())
        } else {
            return startTime.timeIntervalSince(Date())
        }
    }

    var formattedTimeRemaining: String {
        let remaining = max(0, timeRemaining)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Calendar Widget Data Models (Shared with Widget Extension)
struct CalendarWidgetBlock: Codable, Identifiable {
    let id: UUID
    let priorityName: String
    let priorityColorHex: String
    let startTime: Date
    let endTime: Date

    init(from block: TimeBlock) {
        self.id = block.id
        self.priorityName = block.priorityName
        self.priorityColorHex = block.priorityColor.toHex() ?? "FF6B5B"
        self.startTime = block.startTime
        self.endTime = block.endTime
    }

    var durationInMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var formattedDuration: String {
        let hours = durationInMinutes / 60
        let minutes = durationInMinutes % 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        formatter.dateFormat = "a"
        let period = formatter.string(from: endTime).lowercased()
        return "\(start) – \(end) \(period)"
    }

    var isActive: Bool {
        let now = Date()
        return startTime <= now && now <= endTime
    }

    var isPast: Bool {
        endTime < Date()
    }
}

struct CalendarWidgetData: Codable {
    let todayBlocks: [CalendarWidgetBlock]
    let weekBlocks: [CalendarWidgetBlock]
    let weekStartDate: Date

    func blocks(for date: Date) -> [CalendarWidgetBlock] {
        let calendar = Calendar.current
        return weekBlocks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
    }

    func blockCount(for date: Date) -> Int {
        blocks(for: date).count
    }

    func totalHours(for date: Date) -> Double {
        Double(blocks(for: date).reduce(0) { $0 + $1.durationInMinutes }) / 60.0
    }
}
