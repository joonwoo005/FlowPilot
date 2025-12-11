import SwiftUI

// MARK: - Project Section View
struct ProjectSectionView: View {
    let project: Project
    let tasks: [FlowTask]
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var projectStore: ProjectStore
    @Binding var taskToDelete: FlowTask?
    var onEditTask: ((FlowTask) -> Void)? = nil

    @State private var isExpanded = false
    @State private var showAddTask = false
    @State private var showEditProject = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                HStack(spacing: Spacing.sm) {
                    // Project icon
                    ZStack {
                        Circle()
                            .fill(project.color.opacity(0.15))
                            .frame(width: 28, height: 28)

                        Image(systemName: project.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(project.color)
                    }

                    Text(project.name)
                        .font(Typography.labelLarge)
                        .foregroundColor(.textPrimary)

                    Text("(\(tasks.count))")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                // More options button
                Menu {
                    Button {
                        showAddTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }

                    Button {
                        showEditProject = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.surfaceSecondary)
                        )
                }

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .padding(.leading, Spacing.xs)
            }
            .padding(Spacing.base)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                Haptics.impact(.medium)
                showDeleteConfirm = true
            }

            // Tasks list
            if isExpanded {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(height: 1)

                    if tasks.isEmpty {
                        // Empty state
                        VStack(spacing: Spacing.sm) {
                            Text("No tasks yet")
                                .font(Typography.bodySmall)
                                .foregroundColor(.textMuted)

                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Add task")
                                    .font(Typography.bodySmall)
                            }
                            .foregroundColor(project.color)
                            .onTapGesture {
                                Haptics.impact(.light)
                                showAddTask = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.base)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(tasks) { task in
                                BrowseTaskRow(
                                    task: task,
                                    taskStore: taskStore,
                                    taskToDelete: $taskToDelete,
                                    onEdit: { onEditTask?(task) }
                                )

                                if task.id != tasks.last?.id {
                                    Rectangle()
                                        .fill(Color.surfaceBorder.opacity(0.5))
                                        .frame(height: 1)
                                        .padding(.leading, Spacing.xxxl)
                                }
                            }

                            // Add task inline
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Add task")
                                    .font(Typography.bodySmall)
                            }
                            .foregroundColor(.textMuted)
                            .padding(.horizontal, Spacing.base)
                            .padding(.vertical, Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.impact(.light)
                                showAddTask = true
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showAddTask) {
            AddProjectTaskSheet(taskStore: taskStore, project: project)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditProject) {
            AddProjectSheet(projectStore: projectStore, editingProject: project)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete Project?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete all tasks in this project first
                for task in tasks {
                    taskStore.deleteTask(task)
                }
                projectStore.deleteProject(project)
            }
        } message: {
            Text("This will also delete all \(tasks.count) task(s) in this project.")
        }
    }
}

// MARK: - Add Project Task Sheet
struct AddProjectTaskSheet: View {
    @ObservedObject var taskStore: TaskStore
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var taskName = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    // Project badge
                    HStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(project.color.opacity(0.15))
                                .frame(width: 24, height: 24)

                            Image(systemName: project.icon)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(project.color)
                        }

                        Text(project.name)
                            .font(Typography.labelMedium)
                            .foregroundColor(project.color)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(project.color.opacity(0.1))
                    )

                    // Task name input
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Task Name")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textSecondary)

                        TextField("What needs to be done?", text: $taskName)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textPrimary)
                            .padding(Spacing.base)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(Color.surfaceBorder, lineWidth: 1)
                                    )
                            )
                            .focused($isNameFocused)
                    }

                    Spacer()
                }
                .padding(Spacing.lg)
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text("Add")
                        .font(Typography.labelLarge)
                        .foregroundColor(taskName.isEmpty ? .textMuted : .accentPrimary)
                        .onTapGesture {
                            guard !taskName.isEmpty else { return }
                            Haptics.impact(.medium)
                            addTask()
                        }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isNameFocused = false
                        }
                        .font(Typography.labelLarge)
                        .foregroundColor(.accentPrimary)
                    }
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    private func addTask() {
        let task = FlowTask(
            name: taskName,
            projectId: project.id
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            taskStore.tasks.append(task)
        }

        // Save to Firestore
        if let userId = FirebaseConfig.shared.currentUserId {
            Task {
                try? await TaskRepository.shared.createTask(task, userId: userId)
            }
        }

        dismiss()
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack {
            ProjectSectionView(
                project: Project(name: "Side Project", color: .priorityOrange, icon: "folder.fill"),
                tasks: [
                    FlowTask(name: "Design mockups"),
                    FlowTask(name: "Build MVP")
                ],
                taskStore: TaskStore(),
                projectStore: ProjectStore(),
                taskToDelete: .constant(nil)
            )
        }
        .padding()
    }
}
