import SwiftUI

// MARK: - Activity Log Sheet (macOS)
struct ActivityLogSheet: View {
    @ObservedObject var taskStore: TaskStore
    @Binding var filter: TaskStore.ActivityFilter
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmation = false

    private var filteredLogs: [ActivityLog] {
        taskStore.filteredActivityLog(filter)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    showClearConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Activity")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentPrimary)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.md)

            Divider()

            // Filter tabs
            filterTabs
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)

            // Activity list
            if filteredLogs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(filteredLogs) { log in
                            ActivityLogRow(log: log)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)
                }
            }
        }
        .background(Color.backgroundSecondary)
        .confirmationDialog("Clear Activity", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Today", role: .destructive) {
                Haptics.impact(.medium)
                taskStore.clearActivityAndCompletedTasks(timeframe: .today)
            }
            Button("This Week", role: .destructive) {
                Haptics.impact(.medium)
                taskStore.clearActivityAndCompletedTasks(timeframe: .thisWeek)
            }
            Button("All", role: .destructive) {
                Haptics.impact(.medium)
                taskStore.clearActivityAndCompletedTasks(timeframe: .all)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear activity logs and completed tasks for the selected timeframe.")
        }
    }

    // MARK: - Filter Tabs
    private var filterTabs: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(TaskStore.ActivityFilter.allCases, id: \.self) { filterOption in
                filterTab(for: filterOption)
            }
        }
    }

    private func filterTab(for filterOption: TaskStore.ActivityFilter) -> some View {
        let isSelected = filter == filterOption
        let count = taskStore.filteredActivityLog(filterOption).count

        return HStack(spacing: Spacing.xs) {
            Text(filterOption.rawValue)
                .font(Typography.labelSmall)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.surfaceBorder)
                    )
            }
        }
        .foregroundColor(isSelected ? .white : .textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(isSelected ? Color.accentPrimary : Color.surfacePrimary)
        )
        .onTapGesture {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                filter = filterOption
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.textMuted)

            VStack(spacing: Spacing.sm) {
                Text("No activity yet")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("Your task activity will appear here")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Activity Log Row
struct ActivityLogRow: View {
    let log: ActivityLog

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: log.timestamp, relativeTo: Date())
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: log.timestamp)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Action icon
            ZStack {
                Circle()
                    .fill(log.action.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: log.action.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(log.action.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(log.taskName)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text(log.action.rawValue)
                        .font(Typography.labelSmall)
                        .foregroundColor(log.action.color)

                    Text("·")
                        .foregroundColor(.textMuted)

                    Text(timeAgo)
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }
            }

            Spacer()

            // Timestamp
            Text(formattedTime)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textMuted)
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
}

#Preview {
    let taskStore = TaskStore()
    taskStore.loadDemoData()

    return ActivityLogSheet(
        taskStore: taskStore,
        filter: .constant(.all)
    )
    .frame(width: 500, height: 400)
}
