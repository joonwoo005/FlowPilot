import SwiftUI
import FirebaseAuth
import Combine
import UserNotifications

// MARK: - App Delegate for Foreground Notifications
class MacAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set notification delegate to show notifications in foreground
        UNUserNotificationCenter.current().delegate = self
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

// MARK: - Focused Values for Keyboard Shortcuts
struct ShowAddTaskKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

struct ShowAddBlockKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showAddTask: Binding<Bool>? {
        get { self[ShowAddTaskKey.self] }
        set { self[ShowAddTaskKey.self] = newValue }
    }
    var showAddBlock: Binding<Bool>? {
        get { self[ShowAddBlockKey.self] }
        set { self[ShowAddBlockKey.self] = newValue }
    }
}

// MARK: - Keyboard Shortcut Commands
struct FlowPilotCommands: Commands {
    @FocusedBinding(\.showAddTask) var showAddTask
    @FocusedBinding(\.showAddBlock) var showAddBlock

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Task") {
                showAddTask = true
            }
            .keyboardShortcut("t", modifiers: .command)
            .disabled(showAddTask == nil)

            Button("New Time Block") {
                showAddBlock = true
            }
            .keyboardShortcut("b", modifiers: .command)
            .disabled(showAddBlock == nil)
        }
    }
}

@main
struct FlowPilotmacOSApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var onboardingState = OnboardingState()
    @StateObject private var timeBlockStore = TimeBlockStore()

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    @State private var isLoadingUserData = false
    @State private var hasCheckedFirebase = false
    @State private var userPhotoURL: String? = nil
    @State private var userEmail: String = ""

    // Menu bar state
    @State private var menuBarShowAddTask = false
    @State private var menuBarShowAddBlock = false

    init() {
        // Configure Firebase
        FirebaseConfig.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !authService.isAuthenticated {
                    // Show Login Screen
                    LoginView(authService: authService)
                        .onAppear {
                            // Reset check state when logged out
                            hasCheckedFirebase = false
                        }
                } else if isLoadingUserData {
                    // Loading state while checking Firebase
                    ZStack {
                        Color.backgroundPrimary.ignoresSafeArea()
                        ProgressView()
                            .tint(.accentPrimary)
                            .controlSize(.large)
                    }
                } else if !hasCompletedOnboarding {
                    // Show Onboarding
                    OnboardingContainerView(
                        state: onboardingState,
                        onBack: {
                            // Sign out when going back from onboarding
                            try? authService.signOut()
                        },
                        onComplete: { state in
                            userName = state.userName

                            // Save to Firestore
                            Task {
                                await saveOnboardingData(state)
                            }

                            // Mark as checked to prevent Firebase from overwriting
                            hasCheckedFirebase = true

                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                hasCompletedOnboarding = true
                            }
                        }
                    )
                } else {
                    // Show Main App
                    MainSplitView(
                        userName: userName,
                        userEmail: userEmail,
                        userPhotoURL: userPhotoURL,
                        priorityStore: onboardingState,
                        timeBlockStore: timeBlockStore,
                        externalShowAddTask: $menuBarShowAddTask,
                        externalShowAddBlock: $menuBarShowAddBlock,
                        onDataReload: {
                            // Reload data from Firebase after account linking
                            hasCheckedFirebase = false
                            Task {
                                await checkUserDataFromFirebase()
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .preferredColorScheme(.dark)
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && !hasCheckedFirebase {
                    // Check Firebase for returning users
                    Task {
                        await checkUserDataFromFirebase()
                    }
                } else if !isAuthenticated {
                    // User signed out - stop listening
                    timeBlockStore.stopListening()
                }
            }
            .onAppear {
                // Check on initial launch if already authenticated
                if authService.isAuthenticated && !hasCheckedFirebase {
                    Task {
                        await checkUserDataFromFirebase()
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            FlowPilotCommands()
        }

        // Menu Bar Extra - Shows when app is running
        MenuBarExtra {
            MenuBarView(
                timeBlockStore: timeBlockStore,
                priorityStore: onboardingState,
                showAddTask: $menuBarShowAddTask,
                showAddBlock: $menuBarShowAddBlock
            )
        } label: {
            MenuBarLabel(timeBlockStore: timeBlockStore)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Scene Phase Handling
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Force UI refresh for time-based views (fixes frozen timers)
            timeBlockStore.triggerRefresh()
        case .background, .inactive:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Check User Data from Firebase
    private func checkUserDataFromFirebase() async {
        guard let userId = FirebaseConfig.shared.currentUserId else {
            #if DEBUG
            print("[App] No user ID found, skipping Firebase check")
            #endif
            await MainActor.run {
                hasCheckedFirebase = true
                isLoadingUserData = false
            }
            return
        }

        #if DEBUG
        let isAnonymous = FirebaseConfig.shared.auth.currentUser?.isAnonymous ?? false
        print("[App] Checking Firebase for user: \(userId) (anonymous: \(isAnonymous))")
        #endif

        await MainActor.run { isLoadingUserData = true }

        do {
            if let userData = try await UserRepository.shared.getUser(userId: userId) {
                #if DEBUG
                print("[App] Found user data - hasCompletedOnboarding: \(userData.hasCompletedOnboarding)")
                #endif

                await MainActor.run {
                    userName = userData.displayName
                    userEmail = userData.email
                    userPhotoURL = userData.photoURL
                    hasCompletedOnboarding = userData.hasCompletedOnboarding

                    if let wakeTime = userData.wakeTime {
                        onboardingState.sleepSchedule.wakeTime = wakeTime
                    }
                    if let sleepTime = userData.sleepTime {
                        onboardingState.sleepSchedule.sleepTime = sleepTime
                    }
                }

                // Load priorities
                let priorities = try await PriorityRepository.shared.getAllPriorities(userId: userId)
                await MainActor.run {
                    onboardingState.priorities = priorities
                }

                #if DEBUG
                print("[App] Loaded \(priorities.count) priorities")
                #endif
            } else {
                #if DEBUG
                print("[App] No user document found in Firebase - new user")
                #endif
            }

            // Start listening to time blocks for real-time sync
            await MainActor.run {
                timeBlockStore.startListening(userId: userId)
            }
        } catch {
            print("[App] Error checking user data: \(error.localizedDescription)")
        }

        await MainActor.run {
            isLoadingUserData = false
            hasCheckedFirebase = true
        }
    }

    // MARK: - Save Onboarding Data
    private func saveOnboardingData(_ state: OnboardingState) async {
        guard let userId = FirebaseConfig.shared.currentUserId else { return }

        do {
            // Update user profile
            try await UserRepository.shared.updateUserProfile(userId: userId, displayName: state.userName)

            // Save sleep schedule
            try await UserRepository.shared.updateSleepSchedule(
                userId: userId,
                wakeTime: state.sleepSchedule.wakeTime,
                sleepTime: state.sleepSchedule.sleepTime
            )

            // Save priorities
            try await PriorityRepository.shared.batchSavePriorities(state.priorities, userId: userId)

            // Mark onboarding complete
            try await UserRepository.shared.markOnboardingComplete(userId: userId)

            #if DEBUG
            print("[App] Onboarding data saved successfully")
            #endif
        } catch {
            print("[App] Error saving onboarding data: \(error.localizedDescription)")
        }
    }
}

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
            statusSection
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
                .padding(.horizontal, Spacing.md)
            quickActionsSection
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(height: 1)
                .padding(.horizontal, Spacing.md)
            footerSection
        }
        .frame(width: 280)
        .background(Color.backgroundPrimary)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }

    private var statusSection: some View {
        VStack(spacing: Spacing.sm) {
            if let block = currentBlock {
                ActiveBlockCard(block: block, currentTime: currentTime)
            } else if let block = nextBlock {
                UpcomingBlockCard(block: block, currentTime: currentTime)
            } else {
                NoBlocksCard()
            }
        }
        .padding(Spacing.md)
    }

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
        block.priorityColor
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
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

            HStack(spacing: Spacing.sm) {
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

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.surfaceSecondary)

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
        block.priorityColor
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
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
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var activeBlock: TimeBlock? {
        timeBlockStore.blocks(for: currentTime).first { block in
            currentTime >= block.startTime && currentTime < block.endTime
        }
    }

    private var nextBlock: TimeBlock? {
        timeBlockStore.blocks(for: currentTime)
            .filter { $0.startTime > currentTime }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private var statusText: String? {
        if let block = activeBlock {
            let remaining = Int(block.endTime.timeIntervalSince(currentTime) / 60)
            if remaining >= 60 {
                let hours = remaining / 60
                let mins = remaining % 60
                return mins > 0 ? "\(block.priorityName) • \(hours)h \(mins)m" : "\(block.priorityName) • \(hours)h"
            }
            return "\(block.priorityName) • \(remaining)m"
        } else if let block = nextBlock {
            let minutes = Int(block.startTime.timeIntervalSince(currentTime) / 60)
            if minutes >= 60 {
                let hours = minutes / 60
                let mins = minutes % 60
                return mins > 0 ? "Next: \(block.priorityName), in \(hours)h \(mins)m" : "Next: \(block.priorityName), in \(hours)h"
            }
            return "Next: \(block.priorityName), in \(minutes)m"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: activeBlock != nil ? "clock.badge.fill" : "clock")
                .symbolRenderingMode(.hierarchical)

            if let text = statusText {
                Text(text)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
}
