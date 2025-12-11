//
//  FlowPilotWidget.swift
//  FlowPilotWidget
//
//  Created by junyu on 6/12/25.
//

import WidgetKit
import SwiftUI

// MARK: - Color Extension for Widget
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Widget Entry
struct FlowPilotEntry: TimelineEntry {
    let date: Date
    let state: WidgetState

    enum WidgetState {
        case activeBlock(name: String, colorHex: String, endTime: Date)
        case upcomingBlock(name: String, colorHex: String, startTime: Date)
        case noBlocks

        var priorityName: String? {
            switch self {
            case .activeBlock(let name, _, _), .upcomingBlock(let name, _, _):
                return name
            case .noBlocks:
                return nil
            }
        }

        var colorHex: String {
            switch self {
            case .activeBlock(_, let hex, _), .upcomingBlock(_, let hex, _):
                return hex
            case .noBlocks:
                return "71717A"
            }
        }
    }
}

// MARK: - Timeline Provider
struct FlowPilotTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlowPilotEntry {
        FlowPilotEntry(date: Date(), state: .activeBlock(name: "Work", colorHex: "3B82F6", endTime: Date().addingTimeInterval(3600)))
    }

    func getSnapshot(in context: Context, completion: @escaping (FlowPilotEntry) -> Void) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlowPilotEntry>) -> Void) {
        let currentDate = Date()
        var entries: [FlowPilotEntry] = []
        var importantDates: Set<Date> = [currentDate]

        // Load widget data to find important transition times
        if let widgetData = loadWidgetData() {
            // Add block start time (when upcoming -> active)
            if widgetData.startTime > currentDate {
                importantDates.insert(widgetData.startTime)
                // Also add 1 second after to ensure state change
                importantDates.insert(widgetData.startTime.addingTimeInterval(1))
            }
            // Add block end time (when active -> no blocks)
            if widgetData.endTime > currentDate {
                importantDates.insert(widgetData.endTime)
                importantDates.insert(widgetData.endTime.addingTimeInterval(1))
            }
        }

        // Add regular interval entries
        for minuteOffset in stride(from: 0, to: 120, by: 5) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            importantDates.insert(entryDate)
        }

        // Create entries for all dates, sorted
        for date in importantDates.sorted() {
            let entry = createEntry(for: date)
            entries.append(entry)
        }

        // Refresh sooner if there's an upcoming block start or end
        var refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        if let widgetData = loadWidgetData() {
            // Refresh right after block starts
            if widgetData.startTime > currentDate {
                let blockStartRefresh = widgetData.startTime.addingTimeInterval(2)
                if blockStartRefresh < refreshDate {
                    refreshDate = blockStartRefresh
                }
            }
            // Refresh right after block ends
            if widgetData.endTime > currentDate {
                let blockEndRefresh = widgetData.endTime.addingTimeInterval(2)
                if blockEndRefresh < refreshDate {
                    refreshDate = blockEndRefresh
                }
            }
        }

        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> FlowPilotEntry {
        guard let widgetData = loadWidgetData() else {
            return FlowPilotEntry(date: date, state: .noBlocks)
        }

        if widgetData.isActive {
            if date < widgetData.endTime {
                return FlowPilotEntry(
                    date: date,
                    state: .activeBlock(
                        name: widgetData.priorityName,
                        colorHex: widgetData.priorityColorHex,
                        endTime: widgetData.endTime
                    )
                )
            } else {
                return FlowPilotEntry(date: date, state: .noBlocks)
            }
        } else {
            if date < widgetData.startTime {
                return FlowPilotEntry(
                    date: date,
                    state: .upcomingBlock(
                        name: widgetData.priorityName,
                        colorHex: widgetData.priorityColorHex,
                        startTime: widgetData.startTime
                    )
                )
            } else if date < widgetData.endTime {
                return FlowPilotEntry(
                    date: date,
                    state: .activeBlock(
                        name: widgetData.priorityName,
                        colorHex: widgetData.priorityColorHex,
                        endTime: widgetData.endTime
                    )
                )
            } else {
                return FlowPilotEntry(date: date, state: .noBlocks)
            }
        }
    }

    private func loadWidgetData() -> WidgetBlockData? {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.flowpilot.ios"),
              let data = sharedDefaults.data(forKey: "widgetTimeBlockData") else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetBlockData.self, from: data)
    }
}

// MARK: - Widget Block Data
struct WidgetBlockData: Codable {
    let priorityName: String
    let priorityColorHex: String
    let startTime: Date
    let endTime: Date
    let isActive: Bool
}

// MARK: - Home Screen Widget
struct FlowPilotWidget: Widget {
    let kind: String = "FlowPilotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowPilotTimelineProvider()) { entry in
            FlowPilotWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(hex: "0D0D0F")
                }
        }
        .configurationDisplayName("Time Block")
        .description("Shows your current or next time block.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen Widget
struct FlowPilotLockScreenWidget: Widget {
    let kind: String = "FlowPilotLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlowPilotTimelineProvider()) { entry in
            FlowPilotLockScreenView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Time Block")
        .description("Shows your current or next time block.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

#Preview(as: .systemSmall) {
    FlowPilotWidget()
} timeline: {
    FlowPilotEntry(date: .now, state: .activeBlock(name: "Deep Work", colorHex: "3B82F6", endTime: Date().addingTimeInterval(3600)))
    FlowPilotEntry(date: .now, state: .noBlocks)
}
