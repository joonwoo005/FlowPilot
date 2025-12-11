import EventKit
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIColor = NSColor
#endif

class CalendarService: ObservableObject {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()
    @Published var hasCalendarAccess: Bool = false
    @Published var isLoading: Bool = false

    private let calendarNamePrefix = "FlowPilot"

    init() {
        // Don't check authorization on init - defer to first access
        // This prevents crashes when CalendarService.shared is accessed during SwiftUI view initialization
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = status == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                hasCalendarAccess = granted
            }
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    // MARK: - Calendar Management

    func getOrCreateCalendar(for priorityName: String, color: CGColor) throws -> EKCalendar {
        let calendarTitle = "\(calendarNamePrefix) - \(priorityName)"

        // Check if calendar already exists
        let existingCalendars = eventStore.calendars(for: .event)
        if let existing = existingCalendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }

        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.cgColor = color

        // Find a suitable source (prefer iCloud, then local)
        if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = iCloudSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else if let defaultSource = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = defaultSource
        }

        try eventStore.saveCalendar(calendar, commit: true)
        return calendar
    }

    func getOrCreateNoPriorityCalendar() throws -> EKCalendar {
        return try getOrCreateCalendar(for: "Tasks", color: UIColor.systemGray.cgColor)
    }

    // MARK: - Event Creation

    func createEvent(for timeBlock: TimeBlock, in calendar: EKCalendar) throws -> String {
        let event = EKEvent(eventStore: eventStore)
        event.title = timeBlock.priorityName
        event.startDate = timeBlock.startTime
        event.endDate = timeBlock.endTime
        event.calendar = calendar
        event.notes = "Created by FlowPilot"

        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func createEvent(for task: FlowTask, in calendar: EKCalendar) throws -> String {
        guard let dueDate = task.dueDate else {
            throw CalendarError.missingDueDate
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = task.name
        event.startDate = dueDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        event.calendar = calendar
        event.notes = "Created by FlowPilot"
        event.isAllDay = false

        // Add an alarm 15 minutes before
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.addAlarm(alarm)

        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    // MARK: - Event Management

    func updateEvent(eventId: String, title: String, startDate: Date, endDate: Date) throws {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            throw CalendarError.eventNotFound
        }

        event.title = title
        event.startDate = startDate
        event.endDate = endDate

        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    func deleteEvent(eventId: String) throws {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            return // Event already deleted or doesn't exist
        }

        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    func deleteAllEvents(in calendarTitle: String) throws {
        let calendars = eventStore.calendars(for: .event)
        guard let calendar = calendars.first(where: { $0.title == calendarTitle }) else {
            return
        }

        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

        let predicate = eventStore.predicateForEvents(withStart: oneYearAgo, end: oneYearFromNow, calendars: [calendar])
        let events = eventStore.events(matching: predicate)

        for event in events {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }

        try eventStore.commit()
    }

    // MARK: - Sync Operations

    func syncTimeBlocks(_ blocks: [TimeBlock], for priority: Priority) async throws {
        guard hasCalendarAccess else {
            throw CalendarError.noAccess
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let calendar = try getOrCreateCalendar(for: priority.name, color: priority.color.cgColor ?? UIColor.systemBlue.cgColor)

        // Get existing events to avoid duplicates
        let calendarTitle = "\(calendarNamePrefix) - \(priority.name)"
        try deleteAllEvents(in: calendarTitle)

        // Create new events for each block
        for block in blocks where block.priorityId == priority.id {
            _ = try createEvent(for: block, in: calendar)
        }
    }

    func syncTasks(_ tasks: [FlowTask], for priority: Priority?) async throws {
        guard hasCalendarAccess else {
            throw CalendarError.noAccess
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let calendar: EKCalendar
        let calendarTitle: String

        if let priority = priority {
            calendar = try getOrCreateCalendar(for: priority.name, color: priority.color.cgColor ?? UIColor.systemBlue.cgColor)
            calendarTitle = "\(calendarNamePrefix) - \(priority.name)"
        } else {
            calendar = try getOrCreateNoPriorityCalendar()
            calendarTitle = "\(calendarNamePrefix) - Tasks"
        }

        // Clear existing task events
        try deleteAllEvents(in: calendarTitle)

        // Create new events for tasks with due dates
        let tasksWithDueDates = tasks.filter { task in
            task.dueDate != nil &&
            !task.isCompleted &&
            (priority == nil ? task.priority == nil : task.priority?.id == priority?.id)
        }

        for task in tasksWithDueDates {
            _ = try createEvent(for: task, in: calendar)
        }
    }

    func removeSync(for priorityName: String) throws {
        let calendarTitle = "\(calendarNamePrefix) - \(priorityName)"
        try deleteAllEvents(in: calendarTitle)
    }

    // MARK: - Simple Sync (All Time Blocks)

    func syncAllTimeBlocks(_ blocks: [TimeBlock]) async throws {
        guard hasCalendarAccess else {
            throw CalendarError.noAccess
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        let calendar = try getOrCreateCalendar(for: "Time Blocks", color: UIColor.systemBlue.cgColor)
        let calendarTitle = "\(calendarNamePrefix) - Time Blocks"

        // Clear existing events
        try deleteAllEvents(in: calendarTitle)

        // Create new events for each block
        for block in blocks {
            _ = try createEvent(for: block, in: calendar)
        }
    }

    func removeAllSynced() throws {
        let calendars = eventStore.calendars(for: .event)
        let flowPilotCalendars = calendars.filter { $0.title.hasPrefix(calendarNamePrefix) }

        for calendar in flowPilotCalendars {
            try eventStore.removeCalendar(calendar, commit: false)
        }

        try eventStore.commit()
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case noAccess
    case eventNotFound
    case missingDueDate
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "Calendar access is required to sync events"
        case .eventNotFound:
            return "Event not found in calendar"
        case .missingDueDate:
            return "Task must have a due date to sync"
        case .saveFailed:
            return "Failed to save event to calendar"
        }
    }
}

// MARK: - Color Extension

extension Color {
    var cgColor: CGColor? {
        UIColor(self).cgColor
    }
}
