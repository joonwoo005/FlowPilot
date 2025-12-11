import SwiftUI

// MARK: - Menu Bar View
struct MenuBarView: View {
    @ObservedObject var timeBlockStore: TimeBlockStore
    @ObservedObject var priorityStore: OnboardingState
    @Binding var showAddTask: Bool
    @Binding var showAddBlock: Bool

    @State private var currentTime = Date()
    @State private var isHoveringTask = false
    @State private var isHoveringBlock = false
    @State private var isHoveringOpen = false
    @State private var isHoveringQuit = false

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var currentBlock: TimeBlock? {
        timeBlockStore.blocks(for: Date()).first { block in
            currentTime >= block.startTime && currentTime < block.endTime
        }
    }

    private var nextBlock: TimeBlock? {
        timeBlockStore.blocks(for: Date())
            .filter { $0.startTime > currentTime }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status Section
            statusSection

            // Divider
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
                .padding(.horizontal, Spacing.md)

            // Quick Actions
            quickActionsSection

            // Divider
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
                .padding(.horizontal, Spacing.md)

            // Footer Actions
            footerSection
        }
        .frame(width: 280)
        .background(Color.backgroundPrimary)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    // MARK: - Status Section
    private var statusSection: some View {
        VStack(spacing: Spacing.sm) {
            if let block = currentBlock {
                // Active Block
                ActiveBlockCard(block: block, currentTime: currentTime)
            } else if let block = nextBlock {
                // Upcoming Block
                UpcomingBlockCard(block: block, currentTime: currentTime)
            } else {
                // No Blocks
                NoBlocksCard()
            }
        }
        .padding(Spacing.md)
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(spacing: 2) {
            MenuBarActionRow(
                icon: "plus.circle.fill",
                title: "New Task",
                shortcut: "⌘T",
                accentColor: .accentPrimary,
                isHovered: $isHoveringTask
            ) {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
                showAddTask = true
                NSApp.keyWindow?.close()
            }

            MenuBarActionRow(
                icon: "calendar.badge.plus",
                title: "New Time Block",
                shortcut: "⌘B",
                accentColor: .priorityPurple,
                isHovered: $isHoveringBlock
            ) {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
                showAddBlock = true
                NSApp.keyWindow?.close()
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 2) {
            MenuBarActionRow(
                icon: "macwindow",
                title: "Open FlowPilot",
                shortcut: nil,
                accentColor: .textSecondary,
                isHovered: $isHoveringOpen
            ) {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            MenuBarActionRow(
                icon: "power",
                title: "Quit FlowPilot",
                shortcut: "⌘Q",
                accentColor: .accentError,
                isHovered: $isHoveringQuit
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }
}

// MARK: - Active Block Card
struct ActiveBlockCard: View {
    let block: TimeBlock
    let currentTime: Date

    private var progress: Double {
        let total = block.endTime.timeIntervalSince(block.startTime)
        let elapsed = currentTime.timeIntervalSince(block.startTime)
        return min(max(elapsed / total, 0), 1)
    }

    private var remainingMinutes: Int {
        max(0, Int(block.endTime.timeIntervalSince(currentTime) / 60))
    }

    private var blockColor: Color {
        Color(hex: block.priorityColorHex)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.accentSuccess)
                    .frame(width: 6, height: 6)

                Text("NOW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.accentSuccess)
                    .tracking(1)

                Spacer()

                Text("\(remainingMinutes)m left")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.textMuted)
            }

            // Block Info
            HStack(spacing: Spacing.sm) {
                // Color indicator with glow
                ZStack {
                    Circle()
                        .fill(blockColor.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .blur(radius: 8)

                    Circle()
                        .fill(blockColor)
                        .frame(width: 10, height: 10)
                        .shadow(color: blockColor.opacity(0.8), radius: 4, x: 0, y: 0)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.priorityName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(timeRange)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textMuted)
                }

                Spacer()
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.surfaceSecondary)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [blockColor, blockColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                        .shadow(color: blockColor.opacity(0.5), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 4)
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(
                            LinearGradient(
                                colors: [blockColor.opacity(0.4), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: block.startTime)) – \(formatter.string(from: block.endTime))"
    }
}

// MARK: - Upcoming Block Card
struct UpcomingBlockCard: View {
    let block: TimeBlock
    let currentTime: Date

    private var minutesUntil: Int {
        max(0, Int(block.startTime.timeIntervalSince(currentTime) / 60))
    }

    private var blockColor: Color {
        Color(hex: block.priorityColorHex)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Header
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentWarm)

                Text("NEXT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.accentWarm)
                    .tracking(1)

                Spacer()

                Text(timeUntilText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.textMuted)
            }

            // Block Info
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(blockColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .blur(radius: 6)

                    Circle()
                        .fill(blockColor)
                        .frame(width: 10, height: 10)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.priorityName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)

                    Text(startTimeText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textMuted)
                }

                Spacer()
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }

    private var timeUntilText: String {
        if minutesUntil >= 60 {
            let hours = minutesUntil / 60
            let mins = minutesUntil % 60
            return mins > 0 ? "in \(hours)h \(mins)m" : "in \(hours)h"
        }
        return "in \(minutesUntil)m"
    }

    private var startTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Starts at \(formatter.string(from: block.startTime))"
    }
}

// MARK: - No Blocks Card
struct NoBlocksCard: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.textMuted.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 18))
                    .foregroundColor(.textMuted)
            }

            Text("No blocks scheduled")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)

            Text("Create a time block to get started")
                .font(.system(size: 11))
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                        .foregroundColor(Color.surfaceBorder)
                )
        )
    }
}

// MARK: - Menu Bar Action Row
struct MenuBarActionRow: View {
    let icon: String
    let title: String
    let shortcut: String?
    let accentColor: Color
    @Binding var isHovered: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isHovered ? accentColor : .textSecondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovered ? .textPrimary : .textSecondary)

            Spacer()

            if let shortcut = shortcut {
                Text(shortcut)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.textMuted)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(isHovered ? Color.surfaceSecondary : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            Haptics.impact(.light)
            action()
        }
    }
}

// MARK: - Menu Bar Label (Icon in menu bar)
struct MenuBarLabel: View {
    @ObservedObject var timeBlockStore: TimeBlockStore

    private var hasActiveBlock: Bool {
        let now = Date()
        return timeBlockStore.blocks(for: now).contains { block in
            now >= block.startTime && now < block.endTime
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: hasActiveBlock ? "clock.badge.fill" : "clock")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(hasActiveBlock ? .accentPrimary : .primary)
        }
    }
}
