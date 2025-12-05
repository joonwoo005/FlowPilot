import SwiftUI

@main
struct FlowPilotApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                // Main app view (to be implemented)
                MainPlaceholderView(userName: userName)
            } else {
                OnboardingContainerView { state in
                    // Save onboarding data
                    userName = state.userName
                    // TODO: Save priorities and schedule to persistent storage

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
    }
}

// MARK: - Temporary Main View Placeholder
struct MainPlaceholderView: View {
    let userName: String
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Text("Welcome, \(userName)!")
                    .font(Typography.displayMedium)
                    .foregroundColor(.textPrimary)

                Text("Main app coming soon")
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textSecondary)

                // Reset button for testing
                Button(action: {
                    hasCompletedOnboarding = false
                }) {
                    Text("Reset Onboarding")
                        .font(Typography.labelMedium)
                        .foregroundColor(.accentError)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(Color.accentError.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.top, Spacing.xxl)
            }
        }
    }
}

#Preview {
    MainPlaceholderView(userName: "John")
}
