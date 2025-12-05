import SwiftUI

@main
struct FlowPilotiOSApp: App {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @StateObject private var onboardingState = OnboardingState()

    init() {
        #if DEBUG
        Bundle(path: "/Applications/InjectionIII.app/Contents/Resources/iOSInjection.bundle")?.load()
        #endif
    }
    @AppStorage("isGuestUser") private var isGuestUser = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    var body: some Scene {
        WindowGroup {
            Group {
                if !isLoggedIn {
                    // Show Login Screen
                    LoginView(
                        onGoogleSignIn: {
                            // TODO: Implement Google Sign In
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isGuestUser = false
                                isLoggedIn = true
                            }
                        },
                        onGuestContinue: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isGuestUser = true
                                isLoggedIn = true
                            }
                        }
                    )
                } else if !hasCompletedOnboarding {
                    // Show Onboarding
                    OnboardingContainerView(
                        state: onboardingState,
                        onBack: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isLoggedIn = false
                                isGuestUser = false
                            }
                        },
                        onComplete: { state in
                            userName = state.userName
                            // TODO: Save priorities and schedule to persistent storage

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
        }
    }
}
