//
//  FlowPilotMacWidget.swift
//  FlowPilotMacWidget
//
//  Created by junyu on 10/12/25.
//

import WidgetKit
import SwiftUI

// MARK: - App Group Configuration
enum MacAppGroupConfig {
    static let suiteName = "group.com.flowpilot.mac"
    static let widgetDataKey = "macWidgetTimeBlockData"
}

// MARK: - Widget Block Data
struct MacWidgetBlock: Codable, Identifiable {
    let id: UUID
    let priorityName: String
    let priorityColorHex: String
    let startTime: Date
    let endTime: Date

    var durationInMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) – \(formatter.string(from: endTime))"
    }

    var isActive: Bool {
        let now = Date()
        return now >= startTime && now < endTime
    }

    var isPast: Bool {
        Date() > endTime
    }

    var isUpcoming: Bool {
        Date() < startTime
    }
}

struct MacWidgetData: Codable {
    let blocks: [MacWidgetBlock]
    let lastUpdated: Date
}

// MARK: - Timeline Entry
struct MacWidgetEntry: TimelineEntry {
    let date: Date
    let blocks: [MacWidgetBlock]

    var activeBlock: MacWidgetBlock? {
        blocks.first { $0.isActive }
    }

    var nextBlock: MacWidgetBlock? {
        blocks.filter { $0.isUpcoming }.sorted { $0.startTime < $1.startTime }.first
    }

    var upcomingBlocks: [MacWidgetBlock] {
        blocks.filter { !$0.isPast }.sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Timeline Provider
struct MacWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacWidgetEntry {
        MacWidgetEntry(date: Date(), blocks: sampleBlocks)
    }

    func getSnapshot(in context: Context, completion: @escaping (MacWidgetEntry) -> Void) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacWidgetEntry>) -> Void) {
        let currentDate = Date()
        var entries: [MacWidgetEntry] = []

        // Generate entries every 15 minutes for the next 2 hours
        for minuteOffset in stride(from: 0, to: 120, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = createEntry(for: entryDate)
            entries.append(entry)
        }

        // Refresh in 15 minutes
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> MacWidgetEntry {
        let blocks = loadWidgetData()
        return MacWidgetEntry(date: date, blocks: blocks)
    }

    private func loadWidgetData() -> [MacWidgetBlock] {
        guard let sharedDefaults = UserDefaults(suiteName: MacAppGroupConfig.suiteName),
              let data = sharedDefaults.data(forKey: MacAppGroupConfig.widgetDataKey),
              let widgetData = try? JSONDecoder().decode(MacWidgetData.self, from: data) else {
            return []
        }
        return widgetData.blocks
    }

    // Sample data for previews
    private var sampleBlocks: [MacWidgetBlock] {
        let now = Date()
        let calendar = Calendar.current
        return [
            MacWidgetBlock(
                id: UUID(),
                priorityName: "Deep Work",
                priorityColorHex: "3B82F6",
                startTime: calendar.date(byAdding: .hour, value: -1, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: 1, to: now)!
            ),
            MacWidgetBlock(
                id: UUID(),
                priorityName: "Exercise",
                priorityColorHex: "10B981",
                startTime: calendar.date(byAdding: .hour, value: 2, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: 3, to: now)!
            ),
            MacWidgetBlock(
                id: UUID(),
                priorityName: "Learning",
                priorityColorHex: "8B5CF6",
                startTime: calendar.date(byAdding: .hour, value: 4, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: 5, to: now)!
            )
        ]
    }
}

// MARK: - Widget Configuration
struct FlowPilotMacWidget: Widget {
    let kind: String = "FlowPilotMacWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacWidgetProvider()) { entry in
            if #available(macOS 14.0, *) {
                MacWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                MacWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Today's Blocks")
        .description("View your scheduled time blocks for today")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    FlowPilotMacWidget()
} timeline: {
    let now = Date()
    let calendar = Calendar.current
    MacWidgetEntry(date: now, blocks: [
        MacWidgetBlock(
            id: UUID(),
            priorityName: "Deep Work",
            priorityColorHex: "3B82F6",
            startTime: calendar.date(byAdding: .hour, value: -1, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: 1, to: now)!
        ),
        MacWidgetBlock(
            id: UUID(),
            priorityName: "Exercise",
            priorityColorHex: "10B981",
            startTime: calendar.date(byAdding: .hour, value: 2, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: 3, to: now)!
        )
    ])
}
