import SwiftUI
import WidgetKit

// MARK: - Color Extension for Hex
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
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Widget Colors
enum WidgetColors {
    static let backgroundPrimary = Color(hex: "0D0D0F")
    static let backgroundSecondary = Color(hex: "141416")
    static let surfacePrimary = Color(hex: "252528")
    static let surfaceBorder = Color(hex: "333338")
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "71717A")
    static let accentPrimary = Color(hex: "FF6B5B")
    static let accentSuccess = Color(hex: "10B981")
    static let accentWarm = Color(hex: "F59E0B")
}

// MARK: - Main Entry View
struct MacWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MacWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let entry: MacWidgetEntry

    var body: some View {
        ZStack {
            WidgetColors.backgroundPrimary

            if let activeBlock = entry.activeBlock {
                // Active block view
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(WidgetColors.accentSuccess)
                            .frame(width: 6, height: 6)
                        Text("NOW")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.accentSuccess)
                            .tracking(0.5)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: activeBlock.priorityColorHex))
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(activeBlock.priorityName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(2)

                            Text(remainingTime(for: activeBlock))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(WidgetColors.textMuted)
                        }
                    }
                }
                .padding(12)
            } else if let nextBlock = entry.nextBlock {
                // Next block view
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(WidgetColors.accentWarm)
                        Text("NEXT")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.accentWarm)
                            .tracking(0.5)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: nextBlock.priorityColorHex))
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextBlock.priorityName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(WidgetColors.textPrimary)
                                .lineLimit(2)

                            Text(timeUntil(nextBlock))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(WidgetColors.textMuted)
                        }
                    }
                }
                .padding(12)
            } else {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(WidgetColors.textMuted)

                    Text("No blocks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)
                }
            }
        }
    }

    private func remainingTime(for block: MacWidgetBlock) -> String {
        let remaining = Int(block.endTime.timeIntervalSince(entry.date) / 60)
        return "\(max(0, remaining))m left"
    }

    private func timeUntil(_ block: MacWidgetBlock) -> String {
        let minutes = Int(block.startTime.timeIntervalSince(entry.date) / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "in \(hours)h \(mins)m" : "in \(hours)h"
        }
        return "in \(minutes)m"
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let entry: MacWidgetEntry

    var body: some View {
        ZStack {
            WidgetColors.backgroundPrimary

            if entry.upcomingBlocks.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundColor(WidgetColors.textMuted)

                    Text("No blocks scheduled")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.textMuted)
                            .tracking(1)

                        Spacer()

                        Text("\(entry.upcomingBlocks.count) blocks")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(WidgetColors.textMuted)
                    }

                    // Block list (max 3)
                    ForEach(entry.upcomingBlocks.prefix(3)) { block in
                        MediumBlockRow(block: block, currentDate: entry.date)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
            }
        }
    }
}

struct MediumBlockRow: View {
    let block: MacWidgetBlock
    let currentDate: Date

    var body: some View {
        HStack(spacing: 10) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: block.priorityColorHex))
                .frame(width: 4, height: 32)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(block.priorityName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(WidgetColors.textPrimary)
                        .lineLimit(1)

                    if block.isActive {
                        Text("NOW")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.accentSuccess)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(WidgetColors.accentSuccess.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(block.formattedTimeRange)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(WidgetColors.textMuted)
            }

            Spacer()

            // Duration
            Text("\(block.durationInMinutes)m")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(WidgetColors.textSecondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(WidgetColors.surfacePrimary.opacity(block.isActive ? 1 : 0.5))
        )
    }
}

// MARK: - Large Widget
struct LargeWidgetView: View {
    let entry: MacWidgetEntry

    var body: some View {
        ZStack {
            WidgetColors.backgroundPrimary

            if entry.upcomingBlocks.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundColor(WidgetColors.textMuted)

                    Text("No blocks scheduled")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)

                    Text("Create time blocks in FlowPilot")
                        .font(.system(size: 12))
                        .foregroundColor(WidgetColors.textMuted)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TODAY'S SCHEDULE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(WidgetColors.textMuted)
                                .tracking(1)

                            Text(formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(WidgetColors.textSecondary)
                        }

                        Spacer()

                        Text("\(entry.upcomingBlocks.count) blocks")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WidgetColors.accentPrimary)
                    }

                    Divider()
                        .background(WidgetColors.surfaceBorder)

                    // Block list (all blocks)
                    ForEach(entry.upcomingBlocks) { block in
                        LargeBlockRow(block: block, currentDate: entry.date)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: entry.date)
    }
}

struct LargeBlockRow: View {
    let block: MacWidgetBlock
    let currentDate: Date

    private var progress: Double {
        guard block.isActive else { return 0 }
        let total = block.endTime.timeIntervalSince(block.startTime)
        let elapsed = currentDate.timeIntervalSince(block.startTime)
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator with glow for active
            ZStack {
                if block.isActive {
                    Circle()
                        .fill(Color(hex: block.priorityColorHex).opacity(0.3))
                        .frame(width: 20, height: 20)
                        .blur(radius: 4)
                }

                Circle()
                    .fill(Color(hex: block.priorityColorHex))
                    .frame(width: 10, height: 10)
            }
            .frame(width: 20, height: 20)

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(block.priorityName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(block.isPast ? WidgetColors.textMuted : WidgetColors.textPrimary)
                        .lineLimit(1)

                    if block.isActive {
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.accentSuccess)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(WidgetColors.accentSuccess.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text(block.formattedTimeRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(WidgetColors.textMuted)

                    Text("•")
                        .foregroundColor(WidgetColors.textMuted)

                    Text("\(block.durationInMinutes)m")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(WidgetColors.textSecondary)
                }

                // Progress bar for active block
                if block.isActive {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(WidgetColors.surfacePrimary)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: block.priorityColorHex))
                                .frame(width: geometry.size.width * progress)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(block.isActive ? WidgetColors.surfacePrimary : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(block.isActive ? Color(hex: block.priorityColorHex).opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}
