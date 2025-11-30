import WidgetKit
import SwiftUI

// MARK: - Widget Data Model

struct WidgetData: Codable {
    let currentBlock: String?
    let timeRemaining: String?
    let blockEndTime: String?
    let lastUpdated: Double
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    let appGroupIdentifier = "group.com.junyutoh.weekfill"

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), currentBlock: "Focus Time", timeRemaining: "45m")
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = getWidgetEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {
        let entry = getWidgetEntry()

        // Update every minute to keep time remaining accurate
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getWidgetEntry() -> WidgetEntry {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let jsonString = userDefaults.string(forKey: "widgetData"),
              let jsonData = jsonString.data(using: .utf8) else {
            return WidgetEntry(date: Date(), currentBlock: nil, timeRemaining: nil)
        }

        do {
            let widgetData = try JSONDecoder().decode(WidgetData.self, from: jsonData)

            // Recalculate time remaining based on end time
            var timeRemaining = widgetData.timeRemaining
            if let endTimeStr = widgetData.blockEndTime, widgetData.currentBlock != nil {
                timeRemaining = calculateTimeRemaining(endTime: endTimeStr)
            }

            return WidgetEntry(
                date: Date(),
                currentBlock: widgetData.currentBlock,
                timeRemaining: timeRemaining
            )
        } catch {
            return WidgetEntry(date: Date(), currentBlock: nil, timeRemaining: nil)
        }
    }

    private func calculateTimeRemaining(endTime: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        guard let endDate = formatter.date(from: endTime) else { return nil }

        let calendar = Calendar.current
        let now = Date()

        // Create end date for today
        var endComponents = calendar.dateComponents([.hour, .minute], from: endDate)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.year = nowComponents.year
        endComponents.month = nowComponents.month
        endComponents.day = nowComponents.day

        guard let todayEndDate = calendar.date(from: endComponents) else { return nil }

        let diff = calendar.dateComponents([.hour, .minute], from: now, to: todayEndDate)
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0

        if hours <= 0 && minutes <= 0 {
            return "0m"
        } else if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let currentBlock: String?
    let timeRemaining: String?
}

// MARK: - Home Screen Widget View (systemSmall)

struct HomeScreenWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let block = entry.currentBlock {
                Text("Current block:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(block)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer().frame(height: 4)

                Text("Time remaining:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.timeRemaining ?? "0m")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current block:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("No active block")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Spacer().frame(height: 4)

                    Text("Time remaining:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("--")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Lock Screen Widget View (accessoryRectangular)

struct LockScreenWidgetView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let block = entry.currentBlock {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("Current: \(block)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("Remaining: \(entry.timeRemaining ?? "0m")")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("No active block")
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text("--")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget Configuration

struct WeekFillWidget: Widget {
    let kind: String = "WeekFillWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                WidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("WeekFill")
        .description("Shows your current time block and remaining time.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

// MARK: - Entry View Router

struct WidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenWidgetView(entry: entry)
        default:
            HomeScreenWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle Export

@main
struct ExportWidgets: WidgetBundle {
    var body: some Widget {
        WeekFillWidget()
    }
}
