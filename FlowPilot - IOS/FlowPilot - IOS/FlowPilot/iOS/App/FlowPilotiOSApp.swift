import SwiftUI

@main
struct FlowPilotiOSApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var onboardingState = OnboardingState()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    init() {
        // Configure Firebase
        FirebaseConfig.shared.configure()

        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !authService.isAuthenticated {
                    // Show Login Screen
                    LoginView(authService: authService)
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

                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                hasCompletedOnboarding = true
                            }
                        }
                    )
                } else {
                    // Show Main App
                    MainTabView(userName: userName, priorityStore: onboardingState)
                        .onAppear {
                            // Load user data from Firestore
                            Task {
                                await loadUserData()
                            }
                        }
                }
            }
            .preferredColorScheme(.dark)
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
                wakeTime: state.wakeTime,
                sleepTime: state.sleepTime
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

    // MARK: - Load User Data
    private func loadUserData() async {
        guard let userId = FirebaseConfig.shared.currentUserId else { return }

        do {
            // Load user profile
            if let userData = try await UserRepository.shared.getUser(userId: userId) {
                await MainActor.run {
                    userName = userData.displayName
                    hasCompletedOnboarding = userData.hasCompletedOnboarding

                    if let wakeTime = userData.wakeTime {
                        onboardingState.wakeTime = wakeTime
                    }
                    if let sleepTime = userData.sleepTime {
                        onboardingState.sleepTime = sleepTime
                    }
                }
            }

            // Load priorities
            let priorities = try await PriorityRepository.shared.getAllPriorities(userId: userId)
            await MainActor.run {
                onboardingState.priorities = priorities
            }

            #if DEBUG
            print("[App] User data loaded successfully")
            #endif
        } catch {
            print("[App] Error loading user data: \(error.localizedDescription)")
        }
    }
}
