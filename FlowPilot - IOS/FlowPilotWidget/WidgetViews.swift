import SwiftUI
import WidgetKit

// MARK: - Design Constants
private enum WidgetColors {
    static let backgroundPrimary = Color(hex: "0D0D0F")
    static let backgroundSecondary = Color(hex: "141416")
    static let surfacePrimary = Color(hex: "252528")
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "71717A")
    static let accentPrimary = Color(hex: "FF6B5B")
}

// MARK: - Main Widget Entry View (Small & Medium)
struct FlowPilotWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: FlowPilotEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let entry: FlowPilotEntry

    private var priorityColor: Color {
        Color(hex: entry.state.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with status
            HStack(spacing: 6) {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: priorityColor.opacity(0.6), radius: 4)

                Text(statusLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WidgetColors.textMuted)

                Spacer()
            }

            Spacer()

            // Priority name or empty state
            switch entry.state {
            case .activeBlock(let name, _, _), .upcomingBlock(let name, _, _):
                Text(name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(WidgetColors.textPrimary)
                    .lineLimit(2)

            case .noBlocks:
                Text("No blocks")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(WidgetColors.textMuted)

                Text("planned")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(WidgetColors.textMuted)
            }

            // Time info
            Text(timeText)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(priorityColor)
                .shadow(color: priorityColor.opacity(0.4), radius: 6)
        }
        .padding(14)
    }

    private var statusLabel: String {
        switch entry.state {
        case .activeBlock: return "NOW"
        case .upcomingBlock: return "NEXT"
        case .noBlocks: return "TODAY"
        }
    }

    private var timeText: String {
        switch entry.state {
        case .activeBlock(_, _, let endTime):
            return formatTimeRemaining(until: endTime)
        case .upcomingBlock(_, _, let startTime):
            return "in " + formatTimeRemaining(until: startTime)
        case .noBlocks:
            return "--:--"
        }
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(entry.date))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let entry: FlowPilotEntry

    private var priorityColor: Color {
        Color(hex: entry.state.colorHex)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Time indicator
            VStack {
                ZStack {
                    Circle()
                        .stroke(WidgetColors.surfacePrimary, lineWidth: 6)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: progressValue)
                        .stroke(priorityColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: priorityColor.opacity(0.5), radius: 8)

                    VStack(spacing: 0) {
                        Text(timeValueText)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(WidgetColors.textPrimary)

                        Text(timeUnitText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetColors.textMuted)
                    }
                }
            }

            // Right: Details
            VStack(alignment: .leading, spacing: 6) {
                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: priorityColor.opacity(0.6), radius: 3)

                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(priorityColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(priorityColor.opacity(0.15))
                )

                Spacer()

                // Priority name
                switch entry.state {
                case .activeBlock(let name, _, _), .upcomingBlock(let name, _, _):
                    Text(name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(WidgetColors.textPrimary)
                        .lineLimit(1)

                    Text(detailText)
                        .font(.system(size: 13))
                        .foregroundColor(WidgetColors.textSecondary)

                case .noBlocks:
                    Text("No blocks planned")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(WidgetColors.textMuted)

                    Text("Enjoy your free time")
                        .font(.system(size: 13))
                        .foregroundColor(WidgetColors.textMuted)
                }

                Spacer()
            }

            Spacer()
        }
        .padding(16)
    }

    private var statusLabel: String {
        switch entry.state {
        case .activeBlock: return "IN PROGRESS"
        case .upcomingBlock: return "UP NEXT"
        case .noBlocks: return "FREE"
        }
    }

    private var detailText: String {
        switch entry.state {
        case .activeBlock(_, _, let endTime):
            return "Ends at \(formatTime(endTime))"
        case .upcomingBlock(_, _, let startTime):
            return "Starts at \(formatTime(startTime))"
        case .noBlocks:
            return ""
        }
    }

    private var progressValue: Double {
        switch entry.state {
        case .activeBlock(_, _, let endTime):
            // Assume 1 hour block if we don't have start time
            let totalDuration: TimeInterval = 3600
            let remaining = endTime.timeIntervalSince(entry.date)
            return max(0, min(1, 1 - (remaining / totalDuration)))
        case .upcomingBlock:
            return 0
        case .noBlocks:
            return 0
        }
    }

    private var timeValueText: String {
        switch entry.state {
        case .activeBlock(_, _, let endTime):
            let remaining = max(0, endTime.timeIntervalSince(entry.date))
            let minutes = Int(remaining) / 60
            if minutes >= 60 {
                return "\(minutes / 60)"
            }
            return "\(minutes)"

        case .upcomingBlock(_, _, let startTime):
            let remaining = max(0, startTime.timeIntervalSince(entry.date))
            let minutes = Int(remaining) / 60
            if minutes >= 60 {
                return "\(minutes / 60)"
            }
            return "\(minutes)"

        case .noBlocks:
            return "--"
        }
    }

    private var timeUnitText: String {
        switch entry.state {
        case .activeBlock(_, _, let endTime):
            let remaining = max(0, endTime.timeIntervalSince(entry.date))
            let minutes = Int(remaining) / 60
            return minutes >= 60 ? "hr left" : "min left"

        case .upcomingBlock(_, _, let startTime):
            let remaining = max(0, startTime.timeIntervalSince(entry.date))
            let minutes = Int(remaining) / 60
            return minutes >= 60 ? "hr" : "min"

        case .noBlocks:
            return ""
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Lock Screen Widget View
struct FlowPilotLockScreenView: View {
    @Environment(\.widgetFamily) var family
    var entry: FlowPilotEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        default:
            CircularLockScreenView(entry: entry)
        }
    }
}

// MARK: - Circular Lock Screen
struct CircularLockScreenView: View {
    let entry: FlowPilotEntry

    var body: some View {
        ZStack {
            // Progress ring
            AccessoryWidgetBackground()

            switch entry.state {
            case .activeBlock(_, _, let endTime):
                let remaining = max(0, endTime.timeIntervalSince(entry.date))
                let minutes = Int(remaining) / 60

                VStack(spacing: 0) {
                    Text("\(minutes)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))

                    Text("min")
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.7)
                }

            case .upcomingBlock(_, _, let startTime):
                let remaining = max(0, startTime.timeIntervalSince(entry.date))
                let minutes = Int(remaining) / 60

                VStack(spacing: 0) {
                    Text("\(minutes)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))

                    Text("min")
                        .font(.system(size: 9, weight: .medium))
                        .opacity(0.7)
                }

            case .noBlocks:
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24, weight: .medium))
            }
        }
    }
}

// MARK: - Inline Lock Screen
struct InlineLockScreenView: View {
    let entry: FlowPilotEntry

    var body: some View {
        switch entry.state {
        case .activeBlock(let name, _, let endTime):
            let remaining = formatTimeRemaining(until: endTime)
            Text("\(name) \u{00B7} \(remaining) left")

        case .upcomingBlock(let name, _, let startTime):
            let remaining = formatTimeRemaining(until: startTime)
            Text("Next: \(name) in \(remaining)")

        case .noBlocks:
            Text("No blocks planned")
        }
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(entry.date))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Rectangular Lock Screen
struct RectangularLockScreenView: View {
    let entry: FlowPilotEntry

    var body: some View {
        switch entry.state {
        case .activeBlock(let name, _, let endTime):
            VStack(alignment: .leading, spacing: 2) {
                Text("NOW")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)

                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text("\(formatTimeRemaining(until: endTime)) remaining")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .upcomingBlock(let name, _, let startTime):
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)

                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text("in \(formatTimeRemaining(until: startTime))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .noBlocks:
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)

                Text("No blocks planned")
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formatTimeRemaining(until date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(entry.date))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
