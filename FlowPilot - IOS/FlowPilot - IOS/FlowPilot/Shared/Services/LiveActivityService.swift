//
//  LiveActivityService.swift
//  FlowPilot - IOS
//
//  Created by Claude on 12/12/25.
//

import ActivityKit
import Combine
import Foundation
import SwiftUI

@MainActor
class LiveActivityService: ObservableObject {
    static let shared = LiveActivityService()

    @Published private(set) var currentActivity: Activity<TimeBlockActivityAttributes>?

    private var blockEndTimer: Timer?
    private var completedDismissTimer: Timer?
    private var blockStartTimers: [UUID: Timer] = [:]

    private init() {}

    // MARK: - Check Availability

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start Live Activity

    func startActivity(for block: TimeBlock) {
        guard areActivitiesEnabled else {
            print("[LiveActivityService] Live Activities not enabled")
            return
        }

        // End any existing activity first
        Task {
            await endCurrentActivity()

            let attributes = TimeBlockActivityAttributes(
                blockId: block.id,
                priorityName: block.priorityName,
                priorityColorHex: block.priorityColor.toHex() ?? "FF6B5B",
                startTime: block.startTime
            )

            let initialState = TimeBlockActivityAttributes.ContentState(
                endTime: block.endTime,
                state: .active
            )

            let content = ActivityContent(state: initialState, staleDate: block.endTime)

            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                currentActivity = activity

                // Schedule end-of-block handling
                scheduleBlockEndHandler(endTime: block.endTime)

                print("[LiveActivityService] Started activity for block: \(block.priorityName)")
            } catch {
                print("[LiveActivityService] Failed to start activity: \(error)")
            }
        }
    }

    // MARK: - Update Live Activity

    /// Update the Live Activity if the given block matches the currently tracked block
    func updateActivityIfNeeded(for block: TimeBlock) async {
        guard let activity = currentActivity,
              activity.attributes.blockId == block.id else {
            return
        }

        let updatedState = TimeBlockActivityAttributes.ContentState(
            endTime: block.endTime,
            state: .active
        )

        let content = ActivityContent(state: updatedState, staleDate: block.endTime)

        await activity.update(content)

        // Reschedule end handler with new end time
        blockEndTimer?.invalidate()
        scheduleBlockEndHandler(endTime: block.endTime)

        print("[LiveActivityService] Updated activity for block: \(block.priorityName)")
    }

    func extendActivity(by minutes: Int = 15) async {
        guard let activity = currentActivity else { return }

        let newEndTime = activity.content.state.endTime.addingTimeInterval(TimeInterval(minutes * 60))

        let updatedState = TimeBlockActivityAttributes.ContentState(
            endTime: newEndTime,
            state: .extended
        )

        let content = ActivityContent(state: updatedState, staleDate: newEndTime)

        await activity.update(content)

        // Reschedule end handler
        blockEndTimer?.invalidate()
        scheduleBlockEndHandler(endTime: newEndTime)

        print("[LiveActivityService] Extended activity by \(minutes) minutes")
    }

    // MARK: - End Activity Early

    func endActivityEarly() async {
        guard let activity = currentActivity else { return }

        // Show "Ended Early" state briefly
        let completedState = TimeBlockActivityAttributes.ContentState(
            endTime: Date(),
            state: .endedEarly
        )

        let content = ActivityContent(state: completedState, staleDate: nil)
        await activity.update(content)

        // Dismiss after 30 seconds
        scheduleDismissal(after: 30)
    }

    // MARK: - Handle Block Completion

    private func handleBlockEnd() async {
        guard let activity = currentActivity else { return }

        // Update to completed state
        let completedState = TimeBlockActivityAttributes.ContentState(
            endTime: activity.content.state.endTime,
            state: .completed
        )

        let content = ActivityContent(state: completedState, staleDate: nil)
        await activity.update(content)

        // Dismiss after 30 seconds
        scheduleDismissal(after: 30)
    }

    // MARK: - Dismiss Activity

    func endCurrentActivity() async {
        guard let activity = currentActivity else { return }

        blockEndTimer?.invalidate()
        completedDismissTimer?.invalidate()

        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil

        print("[LiveActivityService] Ended current activity")
    }

    // MARK: - Private Helpers

    private func scheduleBlockEndHandler(endTime: Date) {
        blockEndTimer?.invalidate()

        let timeUntilEnd = endTime.timeIntervalSince(Date())
        guard timeUntilEnd > 0 else {
            Task { await handleBlockEnd() }
            return
        }

        blockEndTimer = Timer.scheduledTimer(withTimeInterval: timeUntilEnd, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleBlockEnd()
            }
        }
    }

    private func scheduleDismissal(after seconds: TimeInterval) {
        completedDismissTimer?.invalidate()

        completedDismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.endCurrentActivity()
            }
        }
    }

    // MARK: - Check and Resume Active Activity

    func checkForActiveBlock(in timeBlocks: [TimeBlock]) {
        let now = Date()
        let calendar = Calendar.current

        // Find the currently active block
        if let activeBlock = timeBlocks.first(where: { block in
            guard calendar.isDate(block.startTime, inSameDayAs: now) else {
                return false
            }
            return block.startTime <= now && now <= block.endTime
        }) {
            // Check if we already have an activity for this block
            let existingActivities = Activity<TimeBlockActivityAttributes>.activities
            let hasExisting = existingActivities.contains { $0.attributes.blockId == activeBlock.id }

            if !hasExisting {
                startActivity(for: activeBlock)
            }
        }

        // Schedule upcoming blocks to auto-start
        scheduleUpcomingBlocks(timeBlocks)
    }

    // MARK: - Schedule Upcoming Blocks

    /// Schedule Live Activities to start automatically when blocks begin
    func scheduleUpcomingBlocks(_ timeBlocks: [TimeBlock]) {
        let now = Date()
        let calendar = Calendar.current

        // Cancel all existing start timers
        for timer in blockStartTimers.values {
            timer.invalidate()
        }
        blockStartTimers.removeAll()

        // Find today's upcoming blocks (not yet started)
        let upcomingBlocks = timeBlocks.filter { block in
            guard calendar.isDate(block.startTime, inSameDayAs: now) else {
                return false
            }
            return block.startTime > now
        }

        // Schedule a timer for each upcoming block
        for block in upcomingBlocks {
            let timeUntilStart = block.startTime.timeIntervalSince(now)
            guard timeUntilStart > 0 else { continue }

            // Capture block data to avoid Swift 6 concurrency issues
            let capturedBlock = block
            let blockId = block.id

            let timer = Timer.scheduledTimer(withTimeInterval: timeUntilStart, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.startActivity(for: capturedBlock)
                    self?.blockStartTimers.removeValue(forKey: blockId)
                }
            }
            blockStartTimers[block.id] = timer

            print("[LiveActivityService] Scheduled activity start for '\(block.priorityName)' in \(Int(timeUntilStart))s")
        }
    }

    /// Cancel a scheduled block start (e.g., when block is deleted)
    func cancelScheduledStart(for blockId: UUID) {
        blockStartTimers[blockId]?.invalidate()
        blockStartTimers.removeValue(forKey: blockId)
    }
}

