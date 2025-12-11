import SwiftUI

// MARK: - Browse View (macOS)
struct BrowseView: View {
    let userName: String
    let userPhotoURL: String?
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var showSettings: Bool

    @State private var showSearch = false
    @State private var showCompleted = false
    @State private var showAddProject = false
    @State private var projectsExpanded = true
    @State private var taskToEdit: FlowTask? = nil
    @State private var selectedProject: Project? = nil
    @State private var projectToDelete: Project? = nil

    var body: some View {
        HSplitView {
            // Left sidebar - Navigation
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: Spacing.md) {
                    profileImage
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Welcome back")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)

                        Text(userName)
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()
                }
                .padding(Spacing.lg)

                Divider()

                // Navigation items
                VStack(spacing: 0) {
                    NavigationRow(
                        icon: "magnifyingglass",
                        title: "Search",
                        color: .priorityBlue,
                        entranceDelay: 0.1,
                        action: { showSearch = true }
                    )

                    NavigationRow(
                        icon: "checkmark.circle.fill",
                        title: "Completed",
                        color: .accentSuccess,
                        count: taskStore.completedTasks.count,
                        entranceDelay: 0.18,
                        action: { showCompleted = true }
                    )
                }
                .padding(.vertical, Spacing.md)

                Divider()

                // Projects section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Projects")
                            .font(Typography.labelMedium)
                            .foregroundColor(.textMuted)

                        Spacer()

                        Button {
                            showAddProject = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundColor(.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.sm)

                    ForEach(Array(projectStore.projects.enumerated()), id: \.element.id) { index, project in
                        ProjectNavigationRow(
                            project: project,
                            taskCount: taskStore.tasksForProject(project.id).count,
                            isSelected: selectedProject?.id == project.id,
                            entranceDelay: 0.26 + Double(index) * 0.06,
                            onTap: { selectedProject = project },
                            onDelete: { projectToDelete = project }
                        )
                    }
                }

                Spacer()
            }
            .frame(width: 240)
            .background(
                ZStack {
                    Color.surfacePrimary
                    BrowseSidebarOrbitalBackground()
                }
            )

            // Right content - Project details or overview
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ParticleBackgroundView()

                if let project = selectedProject {
                    ProjectDetailView(
                        project: project,
                        taskStore: taskStore,
                        projectStore: projectStore,
                        taskToEdit: $taskToEdit
                    )
                } else {
                    overviewView
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchTasksView(taskStore: taskStore)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showCompleted) {
            CompletedTasksView(taskStore: taskStore)
                .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectSheet(projectStore: projectStore)
                .frame(width: 400, height: 300)
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskSheet(task: task, taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore)
                .frame(minWidth: 400, minHeight: 300)
        }
        .overlay {
            if projectToDelete != nil {
                ProjectDeleteConfirmationOverlay(
                    project: projectToDelete,
                    taskCount: taskStore.tasksForProject(projectToDelete?.id ?? UUID()).count,
                    onCancel: { withAnimation { projectToDelete = nil } },
                    onDelete: {
                        if let project = projectToDelete {
                            let projectTasks = taskStore.tasksForProject(project.id)
                            for task in projectTasks {
                                taskStore.deleteTask(task)
                            }
                            projectStore.deleteProject(project)
                            if selectedProject?.id == project.id {
                                selectedProject = nil
                            }
                        }
                        withAnimation { projectToDelete = nil }
                    }
                )
            }
        }
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
                .fill(Color.accentPrimary.opacity(0.2))

            Text(String(userName.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentPrimary)
        }
    }

    // MARK: - Overview View
    private var overviewView: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.textMuted)

            VStack(spacing: Spacing.sm) {
                Text("Browse")
                    .font(Typography.headlineMedium)
                    .foregroundColor(.textPrimary)

                Text("Select a project or use search to find tasks")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }

            HStack(spacing: Spacing.lg) {
                Text("\(projectStore.projects.count) projects")
                    .font(Typography.bodySmall)
                    .foregroundColor(.textMuted)

                Text("•")
                    .foregroundColor(.textMuted)

                Text("\(taskStore.activeTasks.count) active tasks")
                    .font(Typography.bodySmall)
                    .foregroundColor(.textMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Navigation Row
struct NavigationRow: View {
    let icon: String
    let title: String
    let color: Color
    var count: Int? = nil
    var entranceDelay: Double = 0
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var iconBounce = false
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .shadow(color: isHovered ? color.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
                .scaleEffect(iconBounce ? 1.2 : 1.0)
                .frame(width: 20)

            Text(title)
                .font(Typography.bodyMedium)
                .foregroundColor(isHovered ? .textPrimary : .textSecondary)

            Spacer()

            if let count = count, count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isHovered ? color : .textMuted)
                    .scaleEffect(isHovered ? 1.05 : 1.0)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(isHovered ? Color.surfaceSecondary.opacity(0.5) : Color.clear)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : -12)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
            if hovering {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    iconBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        iconBounce = false
                    }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                    Haptics.impact(.light)
                    action()
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(entranceDelay)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Project Navigation Row
struct ProjectNavigationRow: View {
    let project: Project
    let taskCount: Int
    let isSelected: Bool
    var entranceDelay: Double = 0
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var iconWiggle = false
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: project.icon)
                .font(.system(size: 12))
                .foregroundColor(project.color)
                .shadow(color: isHovered ? project.color.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
                .scaleEffect(iconWiggle ? 1.2 : 1.0)
                .rotationEffect(.degrees(iconWiggle ? 10 : 0))
                .frame(width: 20)

            Text(project.name)
                .font(Typography.bodyMedium)
                .foregroundColor(isSelected || isHovered ? .textPrimary : .textSecondary)
                .lineLimit(1)

            Spacer()

            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isHovered ? project.color : .textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isHovered ? project.color.opacity(0.12) : Color.clear)
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(isSelected ? Color.accentPrimary.opacity(0.1) : (isHovered ? Color.surfaceSecondary.opacity(0.4) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(isSelected ? project.color.opacity(0.2) : Color.clear, lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : -10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
            if hovering {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                    iconWiggle = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        iconWiggle = false
                    }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                    Haptics.impact(.light)
                    onTap()
                }
        )
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(entranceDelay)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Project Detail View
struct ProjectDetailView: View {
    let project: Project
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var projectStore: ProjectStore
    @Binding var taskToEdit: FlowTask?

    @State private var showAddTask = false

    private var projectTasks: [FlowTask] {
        taskStore.tasksForProject(project.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: Spacing.md) {
                Image(systemName: project.icon)
                    .font(.system(size: 24))
                    .foregroundColor(project.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(Typography.headlineMedium)
                        .foregroundColor(.textPrimary)

                    Text("\(projectTasks.count) tasks")
                        .font(Typography.bodySmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Button {
                    showAddTask = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus")
                        Text("Add Task")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(project.color)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(Spacing.xl)

            Divider()

            // Tasks list
            if projectTasks.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()

                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.textMuted)

                    Text("No tasks yet")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textMuted)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add task")
                    }
                    .font(Typography.bodyMedium)
                    .foregroundColor(project.color)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(project.color.opacity(0.15))
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        showAddTask = true
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(projectTasks) { task in
                            BrowseTaskRow(
                                task: task,
                                taskStore: taskStore,
                                onEdit: { taskToEdit = task }
                            )

                            if task.id != projectTasks.last?.id {
                                Divider()
                                    .padding(.leading, Spacing.xxxl)
                            }
                        }
                    }
                    .padding(Spacing.xl)
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddProjectTaskSheet(taskStore: taskStore, project: project)
                .frame(width: 400, height: 250)
        }
    }
}

// MARK: - Browse Task Row
struct BrowseTaskRow: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore
    var onEdit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .stroke(Color.textMuted, lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .onTapGesture {
                    Haptics.impact(.medium)
                    taskStore.completeTask(task)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)

                if let dueLabel = task.displayDueLabel {
                    Text(dueLabel)
                        .font(Typography.labelSmall)
                        .foregroundColor(task.dueStatus.color)
                }
            }

            Spacer()

            if let priority = task.priority {
                Circle()
                    .fill(priority.color)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture { onEdit?() }
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
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: Spacing.lg) {
                Image(systemName: "trash")
                    .font(.system(size: 32))
                    .foregroundColor(.accentError)

                Text("Delete Project?")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                if let project = project {
                    VStack(spacing: Spacing.xs) {
                        Text(project.name)
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textSecondary)

                        if taskCount > 0 {
                            Text("This will also delete \(taskCount) task\(taskCount == 1 ? "" : "s")")
                                .font(Typography.bodySmall)
                                .foregroundColor(.textMuted)
                        }
                    }
                }

                HStack(spacing: Spacing.md) {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(.plain)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.surfaceSecondary)
                        )

                    Button("Delete") { onDelete() }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.accentError)
                        )
                }
            }
            .padding(Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(Color.surfacePrimary)
            )
        }
    }
}

// MARK: - Search Tasks View
struct SearchTasksView: View {
    @ObservedObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private var filteredTasks: [FlowTask] {
        if searchText.isEmpty {
            return taskStore.activeTasks
        }
        return taskStore.activeTasks.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Search Tasks")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentPrimary)
            }
            .padding(Spacing.lg)

            CustomTextField(
                text: $searchText,
                placeholder: "Search...",
                accentColor: .priorityBlue,
                icon: "magnifyingglass"
            )
            .padding(.horizontal, Spacing.lg)

            Divider()
                .padding(.top, Spacing.md)

            if filteredTasks.isEmpty {
                VStack(spacing: Spacing.md) {
                    Spacer()
                    Text(searchText.isEmpty ? "No tasks" : "No matching tasks")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textMuted)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredTasks) { task in
                            HStack(spacing: Spacing.md) {
                                Text(task.name)
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                if let priority = task.priority {
                                    Circle()
                                        .fill(priority.color)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)

                            Divider()
                        }
                    }
                }
            }
        }
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Completed Tasks View
struct CompletedTasksView: View {
    @ObservedObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Completed Tasks")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentPrimary)
            }
            .padding(Spacing.lg)

            Divider()

            if taskStore.completedTasks.isEmpty {
                VStack(spacing: Spacing.md) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.textMuted)
                    Text("No completed tasks")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textMuted)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(taskStore.completedTasks) { task in
                            HStack(spacing: Spacing.md) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentSuccess)

                                Text(task.name)
                                    .font(Typography.bodyMedium)
                                    .foregroundColor(.textMuted)
                                    .strikethrough()

                                Spacer()
                            }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)

                            Divider()
                        }
                    }
                }
            }
        }
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Add Project Sheet
struct AddProjectSheet: View {
    @ObservedObject var projectStore: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor: Color = .accentPrimary

    private let icons = ["folder.fill", "star.fill", "heart.fill", "bookmark.fill", "tag.fill", "flag.fill"]
    private let colors: [Color] = [.accentPrimary, .accentError, .priorityOrange, .priorityGreen, .priorityPurple, .priorityCyan]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("New Project")
                    .font(Typography.labelLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    projectStore.addProject(
                        name: projectName.trimmingCharacters(in: .whitespacesAndNewlines),
                        color: selectedColor,
                        icon: selectedIcon
                    )
                    dismiss()
                } label: {
                    Text("Add")
                }
                .buttonStyle(.plain)
                .foregroundColor(projectName.isEmpty ? .textMuted : .accentPrimary)
                .disabled(projectName.isEmpty)
            }
            .padding(.top, Spacing.lg)

            CustomTextField(
                text: $projectName,
                placeholder: "Project name",
                accentColor: selectedColor
            )

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Icon")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)

                HStack(spacing: Spacing.md) {
                    ForEach(icons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(selectedIcon == icon ? selectedColor : .textMuted)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedIcon == icon ? selectedColor.opacity(0.15) : Color.surfaceSecondary)
                            )
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Color")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)

                HStack(spacing: Spacing.md) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                            )
                            .onTapGesture { selectedColor = color }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Add Project Task Sheet
struct AddProjectTaskSheet: View {
    @ObservedObject var taskStore: TaskStore
    let project: Project
    @Environment(\.dismiss) private var dismiss

    @State private var taskName = ""

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("Add Task to \(project.name)")
                    .font(Typography.labelLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    taskStore.addTask(
                        name: taskName.trimmingCharacters(in: .whitespacesAndNewlines),
                        dueDate: nil,
                        priority: nil,
                        timeBlockId: nil
                    )
                    dismiss()
                } label: {
                    Text("Add")
                }
                .buttonStyle(.plain)
                .foregroundColor(taskName.isEmpty ? .textMuted : .accentPrimary)
                .disabled(taskName.isEmpty)
            }
            .padding(.top, Spacing.lg)

            CustomTextField(
                text: $taskName,
                placeholder: "Task name",
                accentColor: project.color
            )

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
    }
}

// MARK: - Project Detail Sheet (for sidebar navigation)
struct ProjectDetailSheet: View {
    let project: Project
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Environment(\.dismiss) private var dismiss

    @State private var taskToEdit: FlowTask? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)

            ProjectDetailView(
                project: project,
                taskStore: taskStore,
                projectStore: projectStore,
                taskToEdit: $taskToEdit
            )
        }
        .background(Color.backgroundPrimary)
        .sheet(item: $taskToEdit) { task in
            EditTaskSheet(task: task, taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore)
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}

// MARK: - Particle Background View
struct ParticleBackgroundView: View {
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = 0

    private let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.36)
    private let accentPurple = Color(red: 0.55, green: 0.36, blue: 0.96)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Diffuse coral glow at bottom right
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentCoral.opacity(0.08),
                                accentCoral.opacity(0.02),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .position(x: width * 0.8, y: height * 0.7)

                // Floating purple orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentPurple.opacity(0.10),
                                accentPurple.opacity(0.03),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 50)
                    .offset(
                        x: cos(phase1) * 40,
                        y: sin(phase1) * 25
                    )
                    .position(x: width * 0.3, y: height * 0.3)

                // Small coral accent orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentCoral.opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .offset(
                        x: sin(phase2) * 30,
                        y: cos(phase2) * 20
                    )
                    .position(x: width * 0.6, y: height * 0.5)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                phase1 = .pi * 2
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                phase2 = .pi * 2
            }
        }
    }
}

// MARK: - Browse Sidebar Orbital Background
struct BrowseSidebarOrbitalBackground: View {
    @State private var orbitPhase: CGFloat = 0

    private let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.36)
    private let accentPurple = Color(red: 0.55, green: 0.36, blue: 0.96)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                // Large diffuse coral orb at top
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentCoral.opacity(0.18),
                                accentCoral.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 140
                        )
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 50)
                    .position(x: width * 0.5, y: height * 0.2)

                // Orbiting purple orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentPurple.opacity(0.20),
                                accentPurple.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .offset(
                        x: cos(orbitPhase) * 50,
                        y: sin(orbitPhase) * 30
                    )
                    .position(x: width * 0.5, y: height * 0.5)
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 20)
                .repeatForever(autoreverses: false)
            ) {
                orbitPhase = .pi * 2
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
    .frame(width: 900, height: 600)
}
