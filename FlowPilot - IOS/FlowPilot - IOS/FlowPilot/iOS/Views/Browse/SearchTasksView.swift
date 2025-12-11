import SwiftUI

// MARK: - Search Tasks View
struct SearchTasksView: View {
    @ObservedObject var taskStore: TaskStore
    @Binding var taskToEdit: FlowTask?
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var taskToDelete: FlowTask? = nil
    @FocusState private var isSearchFocused: Bool

    private var searchResults: [FlowTask] {
        taskStore.searchTasks(query: searchQuery)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)

                    if searchQuery.isEmpty {
                        // Empty search state
                        emptySearchState
                    } else if searchResults.isEmpty {
                        // No results
                        noResultsState
                    } else {
                        // Results list
                        ScrollView {
                            LazyVStack(spacing: Spacing.sm) {
                                ForEach(searchResults) { task in
                                    SearchResultRow(
                                        task: task,
                                        searchQuery: searchQuery,
                                        taskStore: taskStore,
                                        onEdit: {
                                            taskToEdit = task
                                            dismiss()
                                        },
                                        taskToDelete: $taskToDelete
                                    )
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.md)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationTitle("Search Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Done")
                        .font(Typography.labelLarge)
                        .foregroundColor(.accentPrimary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isSearchFocused = false
                        }
                        .font(Typography.labelLarge)
                        .foregroundColor(.accentPrimary)
                    }
                }
            }
            .overlay {
                if taskToDelete != nil {
                    DeleteConfirmationOverlay(
                        task: taskToDelete,
                        onCancel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                taskToDelete = nil
                            }
                        },
                        onDelete: {
                            if let task = taskToDelete {
                                taskStore.deleteTask(task)
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                taskToDelete = nil
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.textMuted)

            TextField("Search tasks...", text: $searchQuery)
                .font(Typography.bodyMedium)
                .foregroundColor(.textPrimary)
                .focused($isSearchFocused)

            if !searchQuery.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textMuted)
                    .onTapGesture {
                        Haptics.impact(.light)
                        searchQuery = ""
                    }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSearchFocused ? Color.accentPrimary.opacity(0.5) : Color.surfaceBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Empty Search State
    private var emptySearchState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.priorityBlue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.priorityBlue)
            }

            VStack(spacing: Spacing.sm) {
                Text("Search Tasks")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("Type to search through all your tasks")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - No Results State
    private var noResultsState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.textMuted.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundColor(.textMuted)
            }

            VStack(spacing: Spacing.sm) {
                Text("No results")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("No tasks match \"\(searchQuery)\"")
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

// MARK: - Search Result Row
struct SearchResultRow: View {
    let task: FlowTask
    let searchQuery: String
    @ObservedObject var taskStore: TaskStore
    let onEdit: () -> Void
    @Binding var taskToDelete: FlowTask?

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(task.isCompleted ? Color.accentSuccess : task.dueStatus.color.opacity(0.15))
                    .frame(width: 28, height: 28)

                if task.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .stroke(task.dueStatus.color, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
            }

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                // Highlighted task name
                highlightedText(task.name, highlight: searchQuery)
                    .font(Typography.bodyMedium)
                    .foregroundColor(task.isCompleted ? .textMuted : .textPrimary)
                    .strikethrough(task.isCompleted, color: .textMuted)

                // Meta info
                HStack(spacing: Spacing.sm) {
                    if task.isCompleted {
                        Text("Completed")
                            .font(Typography.labelSmall)
                            .foregroundColor(.accentSuccess)
                    } else if let displayLabel = task.displayDueLabel {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(displayLabel)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(task.dueStatus.color)
                    }

                    if let priority = task.priority {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 6, height: 6)
                            Text(priority.name)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
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
        .contentShape(Rectangle())
        .onTapGesture {
            guard !task.isCompleted else { return }
            Haptics.impact(.light)
            onEdit()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            Haptics.impact(.medium)
            taskToDelete = task
        }
    }

    // Highlight matching text
    private func highlightedText(_ text: String, highlight: String) -> Text {
        guard !highlight.isEmpty else { return Text(text) }

        let lowercaseText = text.lowercased()
        let lowercaseHighlight = highlight.lowercased()

        guard let range = lowercaseText.range(of: lowercaseHighlight) else {
            return Text(text)
        }

        let startIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.lowerBound))
        let endIndex = text.index(text.startIndex, offsetBy: lowercaseText.distance(from: lowercaseText.startIndex, to: range.upperBound))

        let before = String(text[..<startIndex])
        let match = String(text[startIndex..<endIndex])
        let after = String(text[endIndex...])

        return Text(before) + Text(match).foregroundColor(.accentPrimary).bold() + Text(after)
    }
}

#Preview {
    SearchTasksView(taskStore: TaskStore(), taskToEdit: .constant(nil))
}
