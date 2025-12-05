import SwiftUI

struct MainTabView: View {
    let userName: String
    @ObservedObject var priorityStore: OnboardingState
    @StateObject private var taskStore = TaskStore()
    @State private var selectedTab: Tab = .inbox
    @State private var showSettings = false
    @State private var showAddTask = false
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum Tab {
        case inbox
        case today
        case calendar
        case browse
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Inbox Tab
            InboxView(taskStore: taskStore, showSettings: $showSettings, showAddTask: $showAddTask)
                .tabItem {
                    Label("Inbox", systemImage: "tray.fill")
                }
                .tag(Tab.inbox)

            // Today Tab
            TodayPlaceholderView()
                .tabItem {
                    Label("Today", systemImage: "sun.max.fill")
                }
                .tag(Tab.today)

            // Calendar Tab
            CalendarPlaceholderView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(Tab.calendar)

            // Browse Tab
            BrowsePlaceholderView()
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2.fill")
                }
                .tag(Tab.browse)
        }
        .tint(.accentPrimary)
        .sheet(isPresented: $showSettings) {
            SettingsView(
                userName: userName,
                onResetOnboarding: {
                    hasCompletedOnboarding = false
                    showSettings = false
                },
                onSignOut: {
                    isLoggedIn = false
                    hasCompletedOnboarding = false
                    showSettings = false
                }
            )
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskSheet(taskStore: taskStore, priorityStore: priorityStore)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Start Firestore listener if authenticated
            if let userId = FirebaseConfig.shared.currentUserId {
                taskStore.startListening(userId: userId)
            }
        }
        .onDisappear {
            taskStore.stopListening()
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

// MARK: - Settings Sheet

struct SettingsView: View {
    let userName: String
    let onResetOnboarding: () -> Void
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xxl) {
                        // Profile section
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Color.surfacePrimary)
                                    .frame(width: 80, height: 80)

                                Text(String(userName.prefix(1)).uppercased())
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.accentPrimary)
                            }

                            Text(userName)
                                .font(Typography.headlineSmall)
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.top, Spacing.xl)

                        // Actions
                        VStack(spacing: Spacing.md) {
                            // Reset Onboarding
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .foregroundColor(.accentWarm)
                                Text("Reset Onboarding")
                                    .font(Typography.bodyLarge)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textMuted)
                            }
                            .padding(Spacing.base)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                            )
                            .onTapGesture {
                                Haptics.impact(.light)
                                onResetOnboarding()
                            }

                            // Sign Out
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.accentError)
                                Text("Sign Out")
                                    .font(Typography.bodyLarge)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textMuted)
                            }
                            .padding(Spacing.base)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                            )
                            .onTapGesture {
                                Haptics.impact(.light)
                                onSignOut()
                            }
                        }
                        .padding(.horizontal, Spacing.base)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
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
            }
        }
    }
}

#Preview("MainTabView") {
    MainTabView(userName: "John", priorityStore: OnboardingState())
}

#Preview("Settings") {
    SettingsView(
        userName: "John",
        onResetOnboarding: {},
        onSignOut: {}
    )
}
