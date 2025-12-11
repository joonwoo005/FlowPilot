//
//  LiveActivityViews.swift
//  FlowPilotWidget
//
//  Created by Claude on 12/12/25.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Design Constants

private enum LiveActivityColors {
    static let backgroundPrimary = Color(hex: "0D0D0F")
    static let backgroundSecondary = Color(hex: "141416")
    static let surfacePrimary = Color(hex: "252528")
    static let surfaceSecondary = Color(hex: "1A1A1C")
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "71717A")
    static let accentSuccess = Color(hex: "10B981")
    static let accentPrimary = Color(hex: "FF6B5B")
}

// MARK: - Lock Screen Expanded View

struct TimeBlockLiveActivityExpandedView: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var priorityColor: Color {
        Color(hex: context.attributes.priorityColorHex)
    }

    private var progress: Double {
        let totalDuration = context.attributes.startTime.distance(to: context.state.endTime)
        let elapsed = context.attributes.startTime.distance(to: Date())
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, elapsed / totalDuration))
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left: Circular progress ring with countdown
            ZStack {
                // Background ring
                Circle()
                    .stroke(LiveActivityColors.surfacePrimary, lineWidth: 5)
                    .frame(width: 56, height: 56)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(priorityColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: priorityColor.opacity(0.5), radius: 6)

                // Countdown timer (auto-updating)
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(LiveActivityColors.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Middle: Priority info
            VStack(alignment: .leading, spacing: 4) {
                // Status badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: priorityColor.opacity(0.6), radius: 2)

                    Text("NOW")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(priorityColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(priorityColor.opacity(0.15))
                )

                // Priority name
                Text(context.attributes.priorityName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LiveActivityColors.textPrimary)
                    .lineLimit(1)

                // End time
                Text("Ends at \(formattedEndTime)")
                    .font(.system(size: 11))
                    .foregroundColor(LiveActivityColors.textSecondary)
            }

            Spacer()

            // Right: Action buttons
            VStack(spacing: 5) {
                // End Early button
                Link(destination: URL(string: "flowpilot://action/endEarly/\(context.attributes.blockId)")!) {
                    Text("End")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(LiveActivityColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(LiveActivityColors.surfacePrimary)
                        )
                }

                // Extend button
                Link(destination: URL(string: "flowpilot://action/extend/\(context.attributes.blockId)")!) {
                    Text("+15m")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(priorityColor.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(priorityColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: context.state.endTime)
    }
}

// MARK: - Completed View

struct TimeBlockCompletedView: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var isEndedEarly: Bool {
        context.state.state == .endedEarly
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkmark icon
            ZStack {
                Circle()
                    .fill(LiveActivityColors.accentSuccess.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(LiveActivityColors.accentSuccess)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isEndedEarly ? "Ended Early" : "Completed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(LiveActivityColors.textPrimary)

                Text(context.attributes.priorityName)
                    .font(.system(size: 12))
                    .foregroundColor(LiveActivityColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island Compact Leading

struct TimeBlockDynamicIslandCompactLeading: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var priorityColor: Color {
        Color(hex: context.attributes.priorityColorHex)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .shadow(color: priorityColor.opacity(0.6), radius: 2)

            Text(abbreviatedName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }

    private var abbreviatedName: String {
        let name = context.attributes.priorityName
        if name.count <= 6 {
            return name
        }
        return String(name.prefix(5)) + "..."
    }
}

// MARK: - Dynamic Island Compact Trailing

struct TimeBlockDynamicIslandCompactTrailing: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    var body: some View {
        Text(timerInterval: Date()...context.state.endTime, countsDown: true)
            .monospacedDigit()
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(minWidth: 44)
    }
}

// MARK: - Dynamic Island Expanded View

struct TimeBlockDynamicIslandExpandedLeading: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var priorityColor: Color {
        Color(hex: context.attributes.priorityColorHex)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(priorityColor.opacity(0.2))
                .frame(width: 44, height: 44)

            Circle()
                .fill(priorityColor)
                .frame(width: 12, height: 12)
                .shadow(color: priorityColor.opacity(0.6), radius: 4)
        }
    }
}

struct TimeBlockDynamicIslandExpandedTrailing: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var priorityColor: Color {
        Color(hex: context.attributes.priorityColorHex)
    }

    var body: some View {
        VStack(spacing: 4) {
            Link(destination: URL(string: "flowpilot://action/endEarly/\(context.attributes.blockId)")!) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10))
                    .foregroundColor(LiveActivityColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(LiveActivityColors.surfacePrimary)
                    )
            }

            Link(destination: URL(string: "flowpilot://action/extend/\(context.attributes.blockId)")!) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(priorityColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(priorityColor.opacity(0.2))
                    )
            }
        }
    }
}

struct TimeBlockDynamicIslandExpandedCenter: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    var body: some View {
        Text(context.attributes.priorityName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .lineLimit(1)
    }
}

struct TimeBlockDynamicIslandExpandedBottom: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var priorityColor: Color {
        Color(hex: context.attributes.priorityColorHex)
    }

    private var progress: Double {
        let totalDuration = context.attributes.startTime.distance(to: context.state.endTime)
        let elapsed = context.attributes.startTime.distance(to: Date())
        guard totalDuration > 0 else { return 0 }
        return min(1, max(0, elapsed / totalDuration))
    }

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LiveActivityColors.surfacePrimary)
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(priorityColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .shadow(color: priorityColor.opacity(0.5), radius: 3)
                }
            }
            .frame(height: 4)

            // Time info
            HStack {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text("remaining")
                    .font(.system(size: 11))
                    .foregroundColor(LiveActivityColors.textMuted)

                Spacer()

                Text("Ends \(formattedEndTime)")
                    .font(.system(size: 11))
                    .foregroundColor(LiveActivityColors.textSecondary)
            }
        }
    }

    private var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: context.state.endTime)
    }
}

// MARK: - Minimal View (when multiple Live Activities)

struct TimeBlockMinimalView: View {
    let context: ActivityViewContext<TimeBlockActivityAttributes>

    private var priorityColor: Color {
        Color(hex: context.attributes.priorityColorHex)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(priorityColor.opacity(0.3))

            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)
                .shadow(color: priorityColor.opacity(0.6), radius: 2)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
