import SwiftUI
import FirebaseAuth
import AppKit

struct MainSplitView: View {
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @Binding var externalShowAddTask: Bool
    @Binding var externalShowAddBlock: Bool
    let onDataReload: () -> Void

    @StateObject private var taskStore = TaskStore()
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var authService = AuthService.shared

    @State private var selectedSection: SidebarSection = .today
    @State private var selectedDate: Date = Date()
    @State private var showSettings = false
    @State private var showAddTask = false
    @State private var showAddBlock = false
    @State private var taskToEdit: FlowTask? = nil
    @State private var isLinkingAccount = false
    @State private var linkError: String? = nil

    // Sidecar and Projects state
    @State private var showSearchSheet = false
    @State private var showCompletedSheet = false
    @State private var showAddProjectSheet = false
    @State private var projectsExpanded = true
    @State private var selectedProject: Project? = nil
    @State private var projectToDelete: Project? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var storedUserName = ""

    private var isAnonymous: Bool {
        FirebaseConfig.shared.auth.currentUser?.isAnonymous ?? false
    }

    enum SidebarSection: String, CaseIterable, Identifiable {
        case inbox = "Inbox"
        case today = "Today"
        case calendar = "Calendar"
        case completed = "Completed"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .inbox: return "tray.fill"
            case .today: return "sun.max.fill"
            case .calendar: return "calendar"
            case .completed: return "checkmark.circle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .inbox: return .accentPrimary
            case .today: return .accentWarm
            case .calendar: return .accentPrimary
            case .completed: return .accentSuccess
            }
        }
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            UnifiedOrbitalBackground()
            mainNavigationView
        }
    }

    private var mainNavigationView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
        } detail: {
            detailView
        }
        .toolbar { toolbarContent }
        .background(SidebarToggleHider())
        .modifier(MainSplitViewSheets(
            showSettings: $showSettings,
            showAddTask: $showAddTask,
            showAddBlock: $showAddBlock,
            taskToEdit: $taskToEdit,
            showSearchSheet: $showSearchSheet,
            showCompletedSheet: $showCompletedSheet,
            showAddProjectSheet: $showAddProjectSheet,
            selectedProject: $selectedProject,
            userName: userName,
            userEmail: userEmail,
            userPhotoURL: userPhotoURL,
            isAnonymous: isAnonymous,
            priorityStore: priorityStore,
            timeBlockStore: timeBlockStore,
            taskStore: taskStore,
            projectStore: projectStore,
            authService: authService,
            storedUserName: $storedUserName,
            isLoggedIn: $isLoggedIn,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            handleLinkWithGoogle: handleLinkWithGoogle
        ))
        .modifier(MainSplitViewOverlays(
            projectToDelete: $projectToDelete,
            isLinkingAccount: isLinkingAccount,
            linkError: $linkError,
            taskStore: taskStore,
            projectStore: projectStore
        ))
        .focusedSceneValue(\.showAddTask, $showAddTask)
        .focusedSceneValue(\.showAddBlock, $showAddBlock)
        .onChange(of: externalShowAddTask) { _, newValue in
            if newValue {
                showAddBlock = false
                showAddTask = true
                externalShowAddTask = false
            }
        }
        .onChange(of: externalShowAddBlock) { _, newValue in
            if newValue {
                showAddTask = false
                showAddBlock = true
                externalShowAddBlock = false
            }
        }
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    private func startListening() {
        if let userId = FirebaseConfig.shared.currentUserId {
            taskStore.startListening(userId: userId)
            projectStore.startListening(userId: userId)
        }
    }

    private func stopListening() {
        taskStore.stopListening()
        projectStore.stopListening()
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                    if columnVisibility == .detailOnly {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var settingsSheet: some View {
        SettingsView(
            userName: userName,
            userEmail: userEmail,
            userPhotoURL: userPhotoURL,
            isAnonymous: isAnonymous,
            priorityStore: priorityStore,
            timeBlockStore: timeBlockStore,
            taskStore: taskStore,
            onLinkWithGoogle: { handleLinkWithGoogle() },
            onSignOut: {
                // Stop listening to Firestore first
                taskStore.stopListening()
                projectStore.stopListening()

                // Always clear all local data on sign out
                taskStore.tasks.removeAll()
                taskStore.activityLog.removeAll()
                projectStore.projects.removeAll()
                timeBlockStore.timeBlocks.removeAll()
                priorityStore.priorities.removeAll()
                priorityStore.userName = ""
                storedUserName = ""

                try? authService.signOut()
                isLoggedIn = false
                hasCompletedOnboarding = false
                showSettings = false
            }
        )
        .frame(minWidth: 500, minHeight: 600)
    }

    @ViewBuilder
    private var addTaskSheet: some View {
        AddTaskSheet(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, contextDate: nil)
            .frame(minWidth: 400, minHeight: 300)
    }

    @ViewBuilder
    private var addBlockSheet: some View {
        AddTimeBlockSheet(priorityStore: priorityStore, timeBlockStore: timeBlockStore, targetDate: Date())
            .frame(minWidth: 500, minHeight: 600)
    }

    @ViewBuilder
    private func editTaskSheet(for task: FlowTask) -> some View {
        EditTaskSheet(task: task, taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore)
            .frame(minWidth: 400, minHeight: 300)
    }

    @ViewBuilder
    private var searchSheet: some View {
        SearchTasksView(taskStore: taskStore)
            .frame(minWidth: 500, minHeight: 400)
    }

    @ViewBuilder
    private var completedSheet: some View {
        CompletedTasksView(taskStore: taskStore)
            .frame(minWidth: 500, minHeight: 400)
    }

    @ViewBuilder
    private var addProjectSheet: some View {
        AddProjectSheet(projectStore: projectStore)
            .frame(width: 400, height: 300)
    }

    @ViewBuilder
    private func projectDetailSheet(for project: Project) -> some View {
        ProjectDetailSheet(
            project: project,
            taskStore: taskStore,
            projectStore: projectStore,
            priorityStore: priorityStore,
            timeBlockStore: timeBlockStore
        )
        .frame(minWidth: 600, minHeight: 500)
    }

    @ViewBuilder
    private var projectDeleteOverlay: some View {
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
                    }
                    withAnimation { projectToDelete = nil }
                }
            )
        }
    }

    @ViewBuilder
    private var linkingAccountOverlay: some View {
        if isLinkingAccount {
            ZStack {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .tint(.accentPrimary)
                        .controlSize(.large)
                    Text("Linking account...")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textPrimary)
                }
                .padding(Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfacePrimary)
                )
            }
        }
    }

    // MARK: - Sidebar Content
    @ViewBuilder
    private var sidebarContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                AddTaskButton(action: { showAddTask = true })

                VStack(spacing: 2) {
                    SidebarQuickItem(
                        icon: "magnifyingglass",
                        title: "Search",
                        iconColor: .priorityBlue,
                        entranceDelay: 0.15,
                        action: { showSearchSheet = true }
                    )
                }
                .padding(.horizontal, Spacing.sm)

                sidebarNavigationItems
                sidebarProjectsSection
            }
            .padding(.bottom, Spacing.xl)
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        .safeAreaInset(edge: .top) {
            sidebarHeader
        }
    }

    @ViewBuilder
    private var sidebarNavigationItems: some View {
        VStack(spacing: 4) {
            ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { index, section in
                SidebarNavItem(
                    icon: section.icon,
                    title: section.rawValue,
                    iconColor: section.iconColor,
                    isSelected: selectedSection == section,
                    badge: section == .inbox ? taskStore.activeTaskCount : nil,
                    entranceDelay: 0.28 + Double(index) * 0.08,
                    action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                            selectedSection = section
                        }
                    }
                )
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    @ViewBuilder
    private var sidebarProjectsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("PROJECTS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.textMuted)
                    .tracking(1.2)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textMuted)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.surfaceSecondary.opacity(0.5)))
                        .onTapGesture {
                            Haptics.impact(.light)
                            showAddProjectSheet = true
                        }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textMuted)
                        .rotationEffect(.degrees(projectsExpanded ? 0 : -90))
                        .frame(width: 22, height: 22)
                        .onTapGesture {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                projectsExpanded.toggle()
                            }
                        }
                }
            }
            .padding(.horizontal, Spacing.md)

            if projectsExpanded {
                VStack(spacing: 2) {
                    ForEach(Array(projectStore.projects.enumerated()), id: \.element.id) { index, project in
                        SidebarProjectItem(
                            project: project,
                            taskCount: taskStore.tasksForProject(project.id).count,
                            entranceDelay: 0.52 + Double(index) * 0.05,
                            onTap: { selectedProject = project },
                            onDelete: { projectToDelete = project }
                        )
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }
        }
        .padding(.top, Spacing.sm)
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        VStack(spacing: 0) {
            HStack {
                if let photoURL = userPhotoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.surfaceSecondary)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.textSecondary)
                }

                Text(userName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        showSettings = true
                    }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            Divider()
        }
        .background(Color.clear)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .inbox:
            InboxView(taskStore: taskStore, showAddTask: $showAddTask, taskToEdit: $taskToEdit, addTaskContextDate: .constant(nil))
        case .today:
            TodayView(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, resetToToday: .constant(false), externalTargetDate: .constant(nil))
        case .calendar:
            CalendarView(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, selectedTab: .constant(.calendar), todayViewTargetDate: .constant(nil), resetToThisWeek: .constant(false))
        case .completed:
            CompletedActivityView(taskStore: taskStore)
        }
    }

    // MARK: - Link with Google Handler
    private func handleLinkWithGoogle() {
        showSettings = false

        Task {
            await MainActor.run {
                isLinkingAccount = true
            }

            do {
                let anonymousUserId = FirebaseConfig.shared.currentUserId ?? ""
                let (newUserId, hasExistingOnboarding) = try await authService.linkAnonymousAccountWithGoogle()

                if hasExistingOnboarding {
                    #if DEBUG
                    print("[MainSplitView] Loading existing Google account data")
                    #endif

                    await MainActor.run {
                        isLinkingAccount = false
                    }

                    onDataReload()

                } else {
                    #if DEBUG
                    print("[MainSplitView] Migrating anonymous data to Google account")
                    #endif

                    if anonymousUserId != newUserId {
                        try await authService.migrateDataToUser(
                            fromUserId: anonymousUserId,
                            toUserId: newUserId,
                            onboardingState: priorityStore
                        )
                    }

                    if let googleDisplayName = FirebaseConfig.shared.auth.currentUser?.displayName,
                       !googleDisplayName.isEmpty {
                        await MainActor.run {
                            storedUserName = googleDisplayName
                        }
                    }

                    await MainActor.run {
                        isLinkingAccount = false
                    }

                    taskStore.stopListening()
                    projectStore.stopListening()
                    if let userId = FirebaseConfig.shared.currentUserId {
                        taskStore.startListening(userId: userId)
                        projectStore.startListening(userId: userId)
                    }
                }

            } catch let error as AuthError {
                await MainActor.run {
                    isLinkingAccount = false
                    if case .cancelled = error {
                        // User cancelled - no error message
                    } else {
                        linkError = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isLinkingAccount = false
                    linkError = error.localizedDescription
                }
            }
        }
    }
}

// Dummy enum for CalendarView compatibility
extension MainSplitView {
    enum Tab {
        case calendar
    }
}

// MARK: - Sidebar Orbital Background (Static - No Animation)
struct SidebarOrbitalBackground: View {
    private let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.36)
    private let accentPurple = Color(red: 0.55, green: 0.36, blue: 0.96)

    var body: some View {
        ZStack {
            // Large diffuse coral orb at top
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.25),
                            accentCoral.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 0, y: -200)

            // Coral orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.35),
                            accentCoral.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .blur(radius: 40)
                .offset(x: 50, y: -50)

            // Purple orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentPurple.opacity(0.25),
                            accentPurple.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 35)
                .offset(x: -40, y: 100)

            // Bottom accent glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: -30, y: 300)
        }
    }
}

// MARK: - Unified Orbital Background (Static - No Animation)
// Single orbital background spanning the entire window for cohesive appearance
struct UnifiedOrbitalBackground: View {
    private let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.36)
    private let accentPurple = Color(red: 0.55, green: 0.36, blue: 0.96)

    var body: some View {
        ZStack {
            // Large coral glow - left side (sidebar area)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.22),
                            accentCoral.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 400, height: 400)
                .blur(radius: 70)
                .offset(x: -300, y: -200)

            // Coral orb - upper center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.20),
                            accentCoral.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 0, y: -100)

            // Purple accent orb - right side
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentPurple.opacity(0.18),
                            accentPurple.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 180, height: 180)
                .blur(radius: 45)
                .offset(x: 250, y: 50)

            // Bottom coral accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.14),
                            accentCoral.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 65)
                .offset(x: -100, y: 300)
        }
    }
}

// MARK: - Content Orbital Background (Static - No Animation)
// Static orbital background for main content areas - matches sidebar coral tones
struct ContentOrbitalBackground: View {
    private let accentCoral = Color(red: 1.0, green: 0.42, blue: 0.36)

    var body: some View {
        ZStack {
            // Large coral glow - top left (continues from sidebar)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.20),
                            accentCoral.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 80)
                .offset(x: -350, y: -200)

            // Secondary coral orb - upper center
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.22),
                            accentCoral.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: 0, y: -100)

            // Coral orb - right side
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.18),
                            accentCoral.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 50)
                .offset(x: 280, y: 50)

            // Bottom coral accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.12),
                            accentCoral.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 350, height: 350)
                .blur(radius: 70)
                .offset(x: -150, y: 350)
        }
    }
}

// MARK: - Add Task Button
struct AddTaskButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .rotationEffect(.degrees(isHovered ? 90 : 0))

            Text("Add Task")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glow layer (static)
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.accentPrimary)
                    .blur(radius: isHovered ? 12 : 8)
                    .opacity(isHovered ? 0.6 : 0.4)

                // Main button
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentPrimary,
                                Color.accentPrimary.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
        .shadow(color: Color.accentPrimary.opacity(isHovered ? 0.5 : 0.3), radius: isHovered ? 12 : 8, x: 0, y: 4)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -10)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
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
                    Haptics.impact(.medium)
                    action()
                }
        )
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Sidebar Quick Item (Search, Completed)
struct SidebarQuickItem: View {
    let icon: String
    let title: String
    let iconColor: Color
    var badge: String? = nil
    var badgeColor: Color = .accentPrimary
    var entranceDelay: Double = 0
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var iconBounce = false
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(iconColor)
                .scaleEffect(iconBounce ? 1.2 : 1.0)
                .shadow(color: isHovered ? iconColor.opacity(0.5) : Color.clear, radius: 4, x: 0, y: 0)
                .frame(width: 24, height: 24)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovered ? .textPrimary : .textSecondary)

            Spacer()

            if let badge = badge {
                Text(badge)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(badgeColor.opacity(0.15))
                    )
                    .scaleEffect(isHovered ? 1.1 : 1.0)
            }
        }
        .padding(.horizontal, Spacing.sm)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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

// MARK: - Sidebar Nav Item (Inbox, Today, Calendar)
struct SidebarNavItem: View {
    let icon: String
    let title: String
    let iconColor: Color
    let isSelected: Bool
    var badge: Int? = nil
    var entranceDelay: Double = 0
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var iconBounce = false
    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with glow and bounce
            ZStack {
                // Animated glow ring on selection
                if isSelected {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .scaleEffect(hasAppeared ? 1.0 : 0.5)
                }

                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(iconColor)
                    .shadow(color: isSelected || isHovered ? iconColor.opacity(0.6) : Color.clear, radius: 6, x: 0, y: 0)
                    .scaleEffect(iconBounce ? 1.15 : 1.0)
                    .rotationEffect(.degrees(iconBounce ? -8 : 0))
            }
            .frame(width: 32, height: 32)

            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .textPrimary : (isHovered ? .textPrimary : .textSecondary))

            Spacer()

            // Badge for task count
            if let badge = badge, badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(iconColor.opacity(0.15))
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
            }

            // Selection indicator with pulse
            if isSelected {
                Circle()
                    .fill(iconColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: iconColor.opacity(0.6), radius: 4, x: 0, y: 0)
                    .scaleEffect(hasAppeared ? 1.0 : 0)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(isSelected ? Color.surfacePrimary : (isHovered ? Color.surfaceSecondary.opacity(0.3) : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isSelected ? iconColor.opacity(0.2) : Color.clear, lineWidth: 1)
                )
                .shadow(color: isSelected ? iconColor.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 2)
        )
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(hasAppeared ? 1 : 0)
        .offset(x: hasAppeared ? 0 : -15)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
            if hovering && !isSelected {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    iconBounce = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
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

// MARK: - Sidebar Project Item
struct SidebarProjectItem: View {
    let project: Project
    let taskCount: Int
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(project.color)
                .shadow(color: isHovered ? project.color.opacity(0.6) : Color.clear, radius: 4, x: 0, y: 0)
                .scaleEffect(iconWiggle ? 1.2 : 1.0)
                .rotationEffect(.degrees(iconWiggle ? 12 : 0))
                .frame(width: 20)

            Text(project.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isHovered ? .textPrimary : .textSecondary)
                .lineLimit(1)

            Spacer()

            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isHovered ? project.color : .textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isHovered ? project.color.opacity(0.15) : Color.surfaceSecondary)
                    )
                    .scaleEffect(isHovered ? 1.05 : 1.0)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .fill(isHovered ? Color.surfaceSecondary.opacity(0.4) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(isHovered ? project.color.opacity(0.15) : Color.clear, lineWidth: 1)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
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
            Button(role: .destructive) {
                onDelete()
            } label: {
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

// MARK: - Sidebar Toggle Hider
// NSViewRepresentable to hide the default sidebar toggle button
struct SidebarToggleHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hideSidebarToggle(in: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            hideSidebarToggle(in: nsView.window)
        }
    }

    private func hideSidebarToggle(in window: NSWindow?) {
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items {
            let id = item.itemIdentifier.rawValue
            // Only hide the system default sidebar toggle (com.apple.SwiftUI.navigationSplitView.toggleSidebar)
            // Don't hide our custom toolbar items
            if id.contains("navigationSplitView") && id.contains("toggleSidebar") {
                item.view?.isHidden = true
                item.menuFormRepresentation = nil
            }
        }
    }
}

// MARK: - Completed Activity View
struct CompletedActivityView: View {
    @ObservedObject var taskStore: TaskStore

    private var completedByDay: [CompletedDaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var sections: [CompletedDaySection] = []

        var todayTasks: [FlowTask] = []
        var yesterdayTasks: [FlowTask] = []
        var thisWeekTasks: [FlowTask] = []
        var olderTasks: [FlowTask] = []

        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        for task in taskStore.completedTasks {
            guard let completedAt = task.completedAt else { continue }
            let completedDay = calendar.startOfDay(for: completedAt)

            if calendar.isDateInToday(completedAt) {
                todayTasks.append(task)
            } else if calendar.isDateInYesterday(completedAt) {
                yesterdayTasks.append(task)
            } else if completedDay >= startOfWeek {
                thisWeekTasks.append(task)
            } else {
                olderTasks.append(task)
            }
        }

        if !todayTasks.isEmpty {
            sections.append(CompletedDaySection(title: "Today", color: .accentSuccess, tasks: todayTasks))
        }
        if !yesterdayTasks.isEmpty {
            sections.append(CompletedDaySection(title: "Yesterday", color: .textSecondary, tasks: yesterdayTasks))
        }
        if !thisWeekTasks.isEmpty {
            sections.append(CompletedDaySection(title: "This Week", color: .textSecondary, tasks: thisWeekTasks))
        }
        if !olderTasks.isEmpty {
            sections.append(CompletedDaySection(title: "Older", color: .textMuted, tasks: olderTasks))
        }

        return sections
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ContentOrbitalBackground()

            ScrollView {
                LazyVStack(spacing: Spacing.lg) {
                    HStack(alignment: .center) {
                        Text("Activity: Completed")
                            .font(Typography.displayMedium)
                            .foregroundColor(.white)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(taskStore.completedTasks.count)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentSuccess)

                            Text("completed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentSuccess.opacity(0.1))
                        )
                    }
                    .padding(.bottom, Spacing.md)

                    if completedByDay.isEmpty {
                        emptyState
                    } else {
                        ForEach(completedByDay) { section in
                            CompletedSection(
                                title: section.title,
                                titleColor: section.color,
                                tasks: section.tasks,
                                taskStore: taskStore
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
                .frame(height: 60)

            ZStack {
                Circle()
                    .fill(Color.accentSuccess.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.accentSuccess.opacity(0.2), radius: 20, x: 0, y: 0)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.accentSuccess)
            }

            VStack(spacing: Spacing.sm) {
                Text("No completed tasks")
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)

                Text("Tasks you complete will appear here")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

struct CompletedDaySection: Identifiable {
    let id = UUID()
    let title: String
    let color: Color
    let tasks: [FlowTask]
}

struct CompletedSection: View {
    let title: String
    let titleColor: Color
    let tasks: [FlowTask]
    @ObservedObject var taskStore: TaskStore

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(titleColor)
                        .frame(width: 8, height: 8)

                    Text(title)
                        .font(Typography.labelMedium)
                        .foregroundColor(titleColor)

                    Text("(\(tasks.count))")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(spacing: Spacing.xs) {
                    ForEach(tasks) { task in
                        CompletedTaskRow(task: task, taskStore: taskStore)
                    }
                }
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
                .shadow(color: titleColor.opacity(0.10), radius: 10, x: 0, y: 4)
        )
    }
}

struct CompletedTaskRow: View {
    let task: FlowTask
    @ObservedObject var taskStore: TaskStore

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentSuccess)
                    .frame(width: 22, height: 22)

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .onTapGesture {
                Haptics.impact(.light)
                taskStore.uncompleteTask(task)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .strikethrough(true, color: .textMuted)
                    .lineLimit(2)

                if let completedAt = task.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10))
                        Text(formatCompletedTime(completedAt))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentSuccess)
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
        .padding(.horizontal, Spacing.xs)
        .opacity(0.7)
    }

    private func formatCompletedTime(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Completed at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return "Completed \(formatter.string(from: date))"
        }
    }
}

// MARK: - Sheets Modifier
struct MainSplitViewSheets: ViewModifier {
    @Binding var showSettings: Bool
    @Binding var showAddTask: Bool
    @Binding var showAddBlock: Bool
    @Binding var taskToEdit: FlowTask?
    @Binding var showSearchSheet: Bool
    @Binding var showCompletedSheet: Bool
    @Binding var showAddProjectSheet: Bool
    @Binding var selectedProject: Project?
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    let isAnonymous: Bool
    let priorityStore: OnboardingState
    let timeBlockStore: TimeBlockStore
    let taskStore: TaskStore
    let projectStore: ProjectStore
    let authService: AuthService
    @Binding var storedUserName: String
    @Binding var isLoggedIn: Bool
    @Binding var hasCompletedOnboarding: Bool
    let handleLinkWithGoogle: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    userName: userName,
                    userEmail: userEmail,
                    userPhotoURL: userPhotoURL,
                    isAnonymous: isAnonymous,
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore,
                    taskStore: taskStore,
                    onLinkWithGoogle: { handleLinkWithGoogle() },
                    onSignOut: {
                        // Stop listening to Firestore first
                        taskStore.stopListening()
                        projectStore.stopListening()

                        // Always clear all local data on sign out
                        taskStore.tasks.removeAll()
                        taskStore.activityLog.removeAll()
                        projectStore.projects.removeAll()
                        timeBlockStore.timeBlocks.removeAll()
                        priorityStore.priorities.removeAll()
                        priorityStore.userName = ""
                        storedUserName = ""

                        try? authService.signOut()
                        isLoggedIn = false
                        hasCompletedOnboarding = false
                        showSettings = false
                    }
                )
                .frame(minWidth: 500, minHeight: 600)
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskSheet(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, contextDate: nil)
                    .frame(minWidth: 400, minHeight: 300)
            }
            .sheet(isPresented: $showAddBlock) {
                AddTimeBlockSheet(priorityStore: priorityStore, timeBlockStore: timeBlockStore, targetDate: Date())
                    .frame(minWidth: 500, minHeight: 600)
            }
            .sheet(item: $taskToEdit) { task in
                EditTaskSheet(task: task, taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore)
                    .frame(minWidth: 400, minHeight: 300)
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchTasksView(taskStore: taskStore)
                    .frame(minWidth: 500, minHeight: 400)
            }
            .sheet(isPresented: $showCompletedSheet) {
                CompletedTasksView(taskStore: taskStore)
                    .frame(minWidth: 500, minHeight: 400)
            }
            .sheet(isPresented: $showAddProjectSheet) {
                AddProjectSheet(projectStore: projectStore)
                    .frame(width: 400, height: 300)
            }
            .sheet(item: $selectedProject) { project in
                ProjectDetailSheet(
                    project: project,
                    taskStore: taskStore,
                    projectStore: projectStore,
                    priorityStore: priorityStore,
                    timeBlockStore: timeBlockStore
                )
                .frame(minWidth: 600, minHeight: 500)
            }
    }
}

// MARK: - Overlays Modifier
struct MainSplitViewOverlays: ViewModifier {
    @Binding var projectToDelete: Project?
    let isLinkingAccount: Bool
    @Binding var linkError: String?
    let taskStore: TaskStore
    let projectStore: ProjectStore

    func body(content: Content) -> some View {
        content
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
                            }
                            withAnimation { projectToDelete = nil }
                        }
                    )
                }
            }
            .overlay {
                if isLinkingAccount {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: Spacing.md) {
                            ProgressView()
                                .tint(.accentPrimary)
                                .controlSize(.large)
                            Text("Linking account...")
                                .font(Typography.bodyMedium)
                                .foregroundColor(.textPrimary)
                        }
                        .padding(Spacing.xl)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .fill(Color.surfacePrimary)
                        )
                    }
                }
            }
            .alert("Error", isPresented: .constant(linkError != nil)) {
                Button("OK") { linkError = nil }
            } message: {
                Text(linkError ?? "")
            }
    }
}

#Preview {
    MainSplitView(
        userName: "John",
        userEmail: "john@example.com",
        userPhotoURL: nil,
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore(),
        externalShowAddTask: .constant(false),
        externalShowAddBlock: .constant(false),
        onDataReload: {}
    )
}
