import SwiftUI

struct OnboardingNameView: View {
    @ObservedObject var state: OnboardingState
    let onContinue: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            // Subtle gradient overlay at top
            VStack {
                LinearGradient(
                    colors: [
                        Color.accentPrimary.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
                .blur(radius: 60)

                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: Spacing.xl) {
                    // Step indicator
                    StepIndicator(step: 1, title: "Your Name")
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)

                    // Progress
                    OnboardingProgressIndicator(currentStep: 0, totalSteps: 4)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.top, Spacing.xl)

                Spacer()

                // Main content
                VStack(alignment: .leading, spacing: Spacing.xxl) {
                    // Title
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("What should we")
                            .font(Typography.displayMedium)
                            .foregroundColor(.textPrimary)

                        Text("call you?")
                            .font(Typography.displayMedium)
                            .foregroundColor(.accentPrimary)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                    // Subtitle
                    Text("This helps personalize your experience")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textSecondary)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    // Input field
                    TextInputField(
                        placeholder: "Enter your name",
                        text: $state.userName,
                        isLarge: true,
                        isFocused: $isNameFocused
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()
                Spacer()

                // Bottom button
                VStack(spacing: Spacing.base) {
                    PrimaryButton(
                        title: "Continue",
                        action: onContinue,
                        isEnabled: state.isNameValid
                    )
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                hasAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }
}

#Preview {
    OnboardingNameView(
        state: OnboardingState(),
        onContinue: {}
    )
}
