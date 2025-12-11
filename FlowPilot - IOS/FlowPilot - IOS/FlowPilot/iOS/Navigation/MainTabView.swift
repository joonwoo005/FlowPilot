import SwiftUI
import FirebaseAuth

struct MainTabView: View {
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore  // Passed from App - same instance with sync
    let onDataReload: () -> Void  // Callback to reload data from Firebase
    @StateObject private var taskStore = TaskStore()
    @StateObject private var projectStore = ProjectStore()
    @StateObject private var authService = AuthService.shared
    @State private var selectedTab: Tab = .today

    init(userName: String, userEmail: String, userPhotoURL: String?, priorityStore: OnboardingState, timeBlockStore: TimeBlockStore, onDataReload: @escaping () -> Void) {
        self.userName = userName
        self.userEmail = userEmail
        self.userPhotoURL = userPhotoURL
        self._priorityStore = ObservedObject(wrappedValue: priorityStore)
        self._timeBlockStore = ObservedObject(wrappedValue: timeBlockStore)
        self.onDataReload = onDataReload

        // Configure transparent tab bar at UIKit level
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = UIColor(Color.backgroundPrimary.opacity(0.85))
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Configure transparent navigation bar at UIKit level
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.backgroundColor = .clear
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
    @State private var resetTodayView: Bool = false  // Toggle to reset TodayView to today
    @State private var resetCalendarView: Bool = false  // Toggle to reset CalendarView to this week
    @State private var todayViewTargetDate: Date? = nil  // For cross-tab navigation from Calendar
    @State private var showSettings = false
    @State private var showAddTask = false
    @State private var taskToEdit: FlowTask? = nil
    @State private var addTaskContextDate: Date? = nil
    @State private var isLinkingAccount = false
    @State private var linkError: String? = nil
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var storedUserName = ""

    private var isAnonymous: Bool {
        FirebaseConfig.shared.auth.currentUser?.isAnonymous ?? false
    }

    enum Tab {
        case inbox
        case today
        case calendar
        case browse
    }

    // Custom binding to detect tab re-selection
    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .today && selectedTab == .today {
                    // Re-tapped Today tab while already on it - reset to today
                    resetTodayView.toggle()
                } else if newTab == .calendar && selectedTab == .calendar {
                    // Re-tapped Calendar tab while already on it - reset to this week
                    resetCalendarView.toggle()
                }
                selectedTab = newTab
            }
        )
    }

    var body: some View {
        ZStack {
            // Base background color
            Color.backgroundPrimary
                .ignoresSafeArea()

            TabView(selection: tabSelection) {
            // Inbox Tab
            InboxView(taskStore: taskStore, showAddTask: $showAddTask, taskToEdit: $taskToEdit, addTaskContextDate: $addTaskContextDate)
                .toolbarBackground(.hidden, for: .tabBar)
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .tag(Tab.inbox)
                .badge(taskStore.activeTaskCount > 0 ? taskStore.activeTaskCount : 0)

            // Today Tab
            TodayView(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, resetToToday: $resetTodayView, externalTargetDate: $todayViewTargetDate)
                .toolbarBackground(.hidden, for: .tabBar)
                .tabItem {
                    Label("Day", systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            // Calendar Tab
            CalendarView(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, selectedTab: $selectedTab, todayViewTargetDate: $todayViewTargetDate, resetToThisWeek: $resetCalendarView)
                .toolbarBackground(.hidden, for: .tabBar)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            // Browse Tab
            BrowseView(
                userName: userName,
                userPhotoURL: userPhotoURL,
                taskStore: taskStore,
                priorityStore: priorityStore,
                projectStore: projectStore,
                timeBlockStore: timeBlockStore,
                showSettings: $showSettings
            )
                .toolbarBackground(.hidden, for: .tabBar)
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2.fill")
                }
                .tag(Tab.browse)
            }
            .tint(.accentPrimary)
            .background(Color.clear)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                userName: userName,
                userEmail: userEmail,
                userPhotoURL: userPhotoURL,
                isAnonymous: isAnonymous,
                priorityStore: priorityStore,
                timeBlockStore: timeBlockStore,
                taskStore: taskStore,
                onLinkWithGoogle: {
                    handleLinkWithGoogle()
                },
                onDeleteData: {
                    // Clear all data stores and sign out
                    taskStore.deleteAllTasks()
                    timeBlockStore.timeBlocks.removeAll()
                    priorityStore.priorities.removeAll()
                    hasCompletedOnboarding = false
                    showSettings = false
                    try? authService.signOut()
                },
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
        }
        .overlay {
            if isLinkingAccount {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: Spacing.md) {
                        ProgressView()
                            .tint(.accentPrimary)
                            .scaleEffect(1.2)

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
            Button("OK") {
                linkError = nil
            }
        } message: {
            Text(linkError ?? "")
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore, contextDate: addTaskContextDate)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $taskToEdit) { task in
            EditTaskSheet(task: task, taskStore: taskStore, priorityStore: priorityStore, timeBlockStore: timeBlockStore)
        }
        .onAppear {
            // Start Firestore listeners if authenticated
            if let userId = FirebaseConfig.shared.currentUserId {
                taskStore.startListening(userId: userId)
                projectStore.startListening(userId: userId)
            }
        }
        .onDisappear {
            taskStore.stopListening()
            projectStore.stopListening()
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
                    // Google account has existing data - reload it
                    #if DEBUG
                    print("[MainTabView] Loading existing Google account data")
                    #endif

                    await MainActor.run {
                        isLinkingAccount = false
                    }

                    // Trigger data reload from Firebase
                    onDataReload()

                } else {
                    // Google account is new or was just linked - migrate current data
                    #if DEBUG
                    print("[MainTabView] Migrating anonymous data to Google account")
                    #endif

                    // If it's a different user (existing Google account without onboarding),
                    // migrate the anonymous user's data
                    if anonymousUserId != newUserId {
                        try await authService.migrateDataToUser(
                            fromUserId: anonymousUserId,
                            toUserId: newUserId,
                            onboardingState: priorityStore
                        )
                    }

                    // Update stored user name from Google account
                    if let googleDisplayName = FirebaseConfig.shared.auth.currentUser?.displayName,
                       !googleDisplayName.isEmpty {
                        await MainActor.run {
                            storedUserName = googleDisplayName
                        }
                    }

                    await MainActor.run {
                        isLinkingAccount = false
                    }

                    // Restart listeners with new user ID
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

// MARK: - Placeholder Views

struct InboxPlaceholderView: View {
    @Binding var showSettings: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentPrimary)

                    Text("Inbox")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.textPrimary)

                    Text("Your tasks will appear here")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                }
            }
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            showSettings = true
                        }
                }
            }
        }
    }
}

struct TodayPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentWarm)

                    Text("Today")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.textPrimary)

                    Text("Your daily schedule")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct CalendarPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48))
                        .foregroundColor(.accentPrimary)

                    Text("Calendar")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.textPrimary)

                    Text("Week view coming soon")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct BrowsePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.priorityPurple)

                    Text("Browse")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.textPrimary)

                    Text("Explore your priorities")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textMuted)
                }
            }
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}


#Preview("MainTabView") {
    MainTabView(userName: "John", userEmail: "john@example.com", userPhotoURL: nil, priorityStore: OnboardingState(), timeBlockStore: TimeBlockStore(), onDataReload: {})
}

#Preview("Settings") {
    SettingsView(
        userName: "John",
        userEmail: "john@example.com",
        userPhotoURL: nil,
        isAnonymous: false,
        priorityStore: {
            let state = OnboardingState()
            state.priorities = [
                Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 40),
                Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 10)
            ]
            return state
        }(),
        timeBlockStore: TimeBlockStore(),
        taskStore: TaskStore(),
        onLinkWithGoogle: {},
        onDeleteData: {},
        onSignOut: {}
    )
}

