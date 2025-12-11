import SwiftUI

// MARK: - Browse View
struct BrowseView: View {
    let userName: String
    let userPhotoURL: String?
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var showSettings: Bool

    @State private var showProfilePopup = false
    @State private var showSearch = false
    @State private var showCompleted = false
    @State private var showAddProject = false
    @State private var projectsExpanded = true
    @State private var taskToDelete: FlowTask? = nil
    @State private var taskToEdit: FlowTask? = nil
    @State private var selectedProject: Project? = nil
    @State private var projectToDelete: Project? = nil
    @State private var projectForAddTask: Project? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with orbital glow
                Color.backgroundPrimary
                    .ignoresSafeArea()
                OrbitalBackgroundView()

                ScrollView {
                    LazyVStack(spacing: Spacing.lg) {
                        // Header with profile and settings
                        headerView

                        // Action buttons row
                        actionButtonsRow

                        // My Projects Section
                        projectsSection
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .scrollContentBackground(.hidden)
            .overlay {
                if showProfilePopup {
                    ProfilePopupView(
                        userName: userName,
                        userPhotoURL: userPhotoURL,
                        onDismiss: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showProfilePopup = false
                            }
                        },
                        onSettings: {
                            showProfilePopup = false
                            showSettings = true
                        },
                        onSignOut: {
                            showProfilePopup = false
                            showSettings = true
                        }
                    )
                    .transition(.opacity)
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
            .overlay {
                if projectToDelete != nil {
                    ProjectDeleteConfirmationOverlay(
                        project: projectToDelete,
                        taskCount: taskStore.tasksForProject(projectToDelete?.id ?? UUID()).count,
                        onCancel: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                projectToDelete = nil
                            }
                        },
                        onDelete: {
                            if let project = projectToDelete {
                                // Delete all tasks in this project first
                                let projectTasks = taskStore.tasksForProject(project.id)
                                for task in projectTasks {
                                    taskStore.deleteTask(task)
                                }
                                projectStore.deleteProject(project)
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                projectToDelete = nil
                            }
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchTasksView(taskStore: taskStore, taskToEdit: $taskToEdit)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCompleted) {
            CompletedTasksView(taskStore: taskStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet(projectStore: projectStore)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskSheet(task: task, taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore)
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailSheet(
                project: project,
                taskStore: taskStore,
                projectStore: projectStore,
                taskToEdit: $taskToEdit
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $projectForAddTask) { project in
            AddProjectTaskSheet(taskStore: taskStore, project: project)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center) {
            // Profile section (tappable)
            HStack(spacing: Spacing.md) {
                // Profile picture
                profileImage
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)

                    Text(userName)
                        .font(Typography.headlineSmall)
                        .foregroundColor(.textPrimary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showProfilePopup = true
                }
            }

            Spacer()

            // Settings button
            settingsButton
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Profile Image
    @ViewBuilder
    private var profileImage: some View {
        if let photoURL = userPhotoURL, let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentPrimary.opacity(0.3), lineWidth: 2)
                        )
                case .failure, .empty:
                    profilePlaceholder
                @unknown default:
                    profilePlaceholder
                }
            }
        } else {
            profilePlaceholder
        }
    }

    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentPrimary.opacity(0.2), Color.accentPrimary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(String(userName.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.accentPrimary)
        }
    }

    // MARK: - Settings Button
    private var settingsButton: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 20))
            .foregroundColor(.textSecondary)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color.surfacePrimary)
            )
            .onTapGesture {
                Haptics.impact(.light)
                showSettings = true
            }
    }

    // MARK: - Action Buttons Row
    private var actionButtonsRow: some View {
        HStack(spacing: Spacing.md) {
            // Search button
            ActionButton(
                icon: "magnifyingglass",
                title: "Search",
                color: .priorityBlue
            ) {
                Haptics.impact(.light)
                showSearch = true
            }

            // Completed button
            ActionButton(
                icon: "checkmark.circle.fill",
                title: "Completed",
                count: taskStore.completedTasks.count,
                color: .accentSuccess
            ) {
                Haptics.impact(.light)
                showCompleted = true
            }
        }
    }

    // MARK: - Projects Section
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header
            projectsSectionHeader

            // Project items
            if projectsExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(projectStore.projects.enumerated()), id: \.element.id) { index, project in
                        ProjectRowView(
                            project: project,
                            tasks: taskStore.tasksForProject(project.id),
                            taskStore: taskStore,
                            taskToDelete: $taskToDelete,
                            onTap: { selectedProject = project },
                            onDelete: { projectToDelete = project },
                            onEditTask: { task in taskToEdit = task },
                            onAddTask: { projectForAddTask = project }
                        )

                        if index < projectStore.projects.count - 1 {
                            Rectangle()
                                .fill(Color.surfaceBorder.opacity(0.5))
                                .frame(height: 1)
                                .padding(.leading, 44)
                        }
                    }

                    // Divider before Manage Projects
                    if !projectStore.projects.isEmpty {
                        Rectangle()
                            .fill(Color.surfaceBorder.opacity(0.5))
                            .frame(height: 1)
                            .padding(.leading, 44)
                    }

                    // Manage Projects row
                    manageProjectsRow
                }
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfacePrimary)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Projects Section Header
    private var projectsSectionHeader: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Text("My Projects")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.textPrimary)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textMuted)

            Spacer()

            // Add project button
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.textMuted)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    showAddProject = true
                }

            // Collapse chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textMuted)
                .rotationEffect(.degrees(projectsExpanded ? 0 : -90))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        projectsExpanded.toggle()
                    }
                }
        }
    }

    // MARK: - Manage Projects Row
    private var manageProjectsRow: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "pencil")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textMuted)
                .frame(width: 24)

            Text("Manage Projects")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.textMuted)

            Spacer()
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            // TODO: Navigate to manage projects
        }
    }
}

// MARK: - Project Row View
struct ProjectRowView: View {
    let project: Project
    let tasks: [FlowTask]
    @ObservedObject var taskStore: TaskStore
    @Binding var taskToDelete: FlowTask?
    var onTap: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onEditTask: ((FlowTask) -> Void)? = nil
    var onAddTask: (() -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: Spacing.md) {
                Image(systemName: project.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(project.color)
                    .frame(width: 24)

                Text(project.name)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.textPrimary)

                Spacer()

                if tasks.count > 0 {
                    Text("\(tasks.count)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.textMuted)
                }

                // Expand dropdown button
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.surfaceSecondary)
                    )
                    .onTapGesture {
                        Haptics.impact(.light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }
            }
            .padding(.horizontal, Spacing.base)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                onTap?()
            }
            .onLongPressGesture {
                Haptics.impact(.medium)
                onDelete?()
            }

            // Expanded tasks list
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.surfaceBorder.opacity(0.5))
                        .frame(height: 1)
                        .padding(.leading, 44)

                    // Task list
                    if !tasks.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(tasks) { task in
                                BrowseTaskRow(
                                    task: task,
                                    taskStore: taskStore,
                                    taskToDelete: $taskToDelete,
                                    onEdit: { onEditTask?(task) }
                                )
                                .padding(.leading, 24)

                                Rectangle()
                                    .fill(Color.surfaceBorder.opacity(0.3))
                                    .frame(height: 1)
                                    .padding(.leading, 68)
                            }
                        }
                    }

                    // Add task button (always visible)
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(project.color.opacity(0.7))

                        Text("Add task")
                            .font(Typography.bodySmall)
                            .foregroundColor(project.color.opacity(0.8))

                        Spacer()
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.leading, 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        onAddTask?()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Project Detail Sheet
struct ProjectDetailSheet: View {
    let project: Project
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var projectStore: ProjectStore
    @Binding var taskToEdit: FlowTask?
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTask = false
    @State private var taskToDelete: FlowTask? = nil

    private var projectTasks: [FlowTask] {
        taskStore.tasksForProject(project.id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Project header
                        projectHeader

                        // Tasks list
                        if projectTasks.isEmpty {
                            emptyState
                        } else {
                            tasksList
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, 100)
                }

                // Floating add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        addTaskButton
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                }
            }
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

                ToolbarItem(placement: .principal) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: project.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(project.color)
                        Text(project.name)
                            .font(Typography.labelLarge)
                            .foregroundColor(.textPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddProjectTaskSheet(taskStore: taskStore, project: project)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
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
    }

    // MARK: - Project Header
    private var projectHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(projectTasks.count) tasks")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Text("No tasks yet")
                .font(Typography.bodyMedium)
                .foregroundColor(.textMuted)

            Text("Tap + to add your first task")
                .font(Typography.bodySmall)
                .foregroundColor(.textMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl)
    }

    // MARK: - Tasks List
    private var tasksList: some View {
        VStack(spacing: 0) {
            ForEach(projectTasks) { task in
                BrowseTaskRow(
                    task: task,
                    taskStore: taskStore,
                    taskToDelete: $taskToDelete,
                    onEdit: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            taskToEdit = task
                        }
                    }
                )

                if task.id != projectTasks.last?.id {
                    Rectangle()
                        .fill(Color.surfaceBorder.opacity(0.5))
                        .frame(height: 1)
                        .padding(.leading, Spacing.xxxl)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
        )
    }

    // MARK: - Add Task Button
    private var addTaskButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.textPrimary)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(project.color)
            )
            .shadow(color: project.color.opacity(0.3), radius: 8, x: 0, y: 4)
            .onTapGesture {
                Haptics.impact(.medium)
                showAddTask = true
            }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    var count: Int? = nil
    let color: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)

            Text(title)
                .font(Typography.labelMedium)
                .foregroundColor(.textPrimary)

            if let count = count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.15))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
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
            action()
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isExpanded: Bool
    var count: Int = 0

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.textMuted)
                .textCase(.uppercase)
                .tracking(1.2)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.textMuted.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.textMuted.opacity(0.5))
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Project Delete Confirmation Overlay
struct ProjectDeleteConfirmationOverlay: View {
    let project: Project?
    let taskCount: Int
    let onCancel: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    Haptics.impact(.light)
                    onCancel()
                }

            // Confirmation card
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: Spacing.lg) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.accentError.opacity(0.15))
                            .frame(width: 56, height: 56)

                        Image(systemName: "trash")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.accentError)
                    }

                    // Text
                    VStack(spacing: Spacing.xs) {
                        Text("Delete Project?")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.textPrimary)

                        if let project = project {
                            Text(project.name)
                                .font(Typography.bodyMedium)
                                .foregroundColor(.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if taskCount > 0 {
                                Text("This will also delete \(taskCount) task\(taskCount == 1 ? "" : "s")")
                                    .font(Typography.bodySmall)
                                    .foregroundColor(.textMuted)
                            }
                        }
                    }

                    // Buttons
                    VStack(spacing: Spacing.sm) {
                        // Delete button
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.accentError)
                            )
                            .onTapGesture {
                                Haptics.impact(.medium)
                                onDelete()
                            }

                        // Cancel button
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                            )
                            .onTapGesture {
                                Haptics.impact(.light)
                                onCancel()
                            }
                    }
                }
                .padding(Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .fill(Color.backgroundElevated)
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
        }
    }
}

#Preview {
    BrowseView(
        userName: "John",
        userPhotoURL: nil,
        taskStore: TaskStore(),
        priorityStore: OnboardingState(),
        projectStore: ProjectStore(),
        timeBlockStore: TimeBlockStore(),
        showSettings: .constant(false)
    )
}
