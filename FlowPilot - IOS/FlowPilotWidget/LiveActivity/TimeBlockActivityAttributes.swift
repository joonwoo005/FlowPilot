//
//  TimeBlockActivityAttributes.swift
//  FlowPilotWidget
//
//  Created by Claude on 12/12/25.
//

import ActivityKit
import Foundation

struct TimeBlockActivityAttributes: ActivityAttributes {
    // MARK: - Static Content (doesn't change during the activity)
    var blockId: UUID
    var priorityName: String
    var priorityColorHex: String
    var startTime: Date

    // MARK: - Dynamic Content State (can be updated)
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var state: ActivityState

        enum ActivityState: String, Codable, Hashable {
            case active       // Block is currently in progress
            case completed    // Block just ended (show "Completed" state)
            case extended     // Block was extended
            case endedEarly   // Block was ended early
        }

        var isCompleted: Bool {
            state == .completed || state == .endedEarly
        }
    }
}
