import SwiftUI
import FirebaseAuth

@main
struct FlowPilotiOSApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var onboardingState = OnboardingState()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    @State private var isLoadingUserData = false
    @State private var hasCheckedFirebase = false

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
                    MainTabView(userName: userName, priorityStore: onboardingState)
                }
            }
            .preferredColorScheme(.dark)
            .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated && !hasCheckedFirebase {
                    // Check Firebase for returning users
                    Task {
                        await checkUserDataFromFirebase()
                    }
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
