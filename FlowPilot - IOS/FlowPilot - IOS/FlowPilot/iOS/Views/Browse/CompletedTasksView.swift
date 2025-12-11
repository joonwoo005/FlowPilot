import SwiftUI

// MARK: - Completed Tasks View
struct CompletedTasksView: View {
    @ObservedObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var showClearOptions = false
    @State private var selectedTimeframe: TaskStore.ClearTimeframe = .today

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                if taskStore.completedTasks.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.sm) {
                            // Stats header
                            statsHeader

                            // Completed tasks list
                            ForEach(taskStore.completedTasks) { task in
                                CompletedTaskRow(task: task, taskStore: taskStore)
                            }
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Completed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !taskStore.completedTasks.isEmpty {
                        Menu {
                            ForEach(TaskStore.ClearTimeframe.allCases, id: \.self) { timeframe in
                                Button {
                                    selectedTimeframe = timeframe
                                    showClearOptions = true
                                } label: {
                                    Text("Clear \(timeframe.rawValue)")
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text("Done")
                        .font(Typography.labelLarge)
                        .foregroundColor(.accentPrimary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }
            }
            .alert("Clear Completed Tasks?", isPresented: $showClearOptions) {
                Button("Cancel", role: .cancel) {}
                Button("Clear \(selectedTimeframe.rawValue)", role: .destructive) {
                    Haptics.impact(.medium)
                    taskStore.clearActivityAndCompletedTasks(timeframe: selectedTimeframe)
                }
            } message: {
                Text("This will permanently delete completed tasks from \(selectedTimeframe.rawValue.lowercased()).")
            }
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: Spacing.md) {
            // Total completed
            StatBadge(
                value: "\(taskStore.completedTasks.count)",
                label: "Total",
                color: .accentSuccess
            )

            // Today's completions
            StatBadge(
                value: "\(todayCompletions)",
                label: "Today",
                color: .priorityBlue
            )

            // This week
            StatBadge(
                value: "\(weekCompletions)",
                label: "This Week",
                color: .priorityPurple
            )
        }
        .padding(.bottom, Spacing.sm)
    }

    private var todayCompletions: Int {
        let calendar = Calendar.current
        return taskStore.completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }.count
    }

    private var weekCompletions: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return taskStore.completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfWeek
        }.count
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentSuccess.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.accentSuccess)
            }

            VStack(spacing: Spacing.sm) {
                Text("No completed tasks")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("Complete some tasks to see them here")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)

            Text(label)
                .font(Typography.labelSmall)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Completed Task Row
struct CompletedTaskRow: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Completed checkmark
            ZStack {
                Circle()
                    .fill(Color.accentSuccess)
                    .frame(width: 24, height: 24)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textMuted)
                    .strikethrough(true, color: .textMuted)
                    .lineLimit(2)

                // Completion time
                if let completedAt = task.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text(formatCompletedDate(completedAt))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentSuccess)
                }
            }

            Spacer()

            // Uncomplete button
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.surfaceSecondary)
                )
                .onTapGesture {
                    Haptics.impact(.light)
                    taskStore.uncompleteTask(task)
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

    private func formatCompletedDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    CompletedTasksView(taskStore: TaskStore())
}
