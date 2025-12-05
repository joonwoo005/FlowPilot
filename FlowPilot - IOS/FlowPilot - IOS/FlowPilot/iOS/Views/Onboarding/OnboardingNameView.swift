import SwiftUI

struct OnboardingNameView: View {
    @ObservedObject var state: OnboardingState
    let step: OnboardingStep
    let onContinue: () -> Void
    let onBack: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var hasAppeared = false
    @State private var showLimitError = false

    private let characterLimit = 20

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: step, onBack: onBack)
                .opacity(hasAppeared ? 1 : 0)

            Spacer()
                .frame(height: Spacing.xxxl)

            // Main content
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("What should we")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.textPrimary)

                    Text("call you?")
                        .font(Typography.headlineLarge)
                        .foregroundColor(.accentPrimary)
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)

                Text("This helps personalize your experience")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    TextField("", text: $state.userName)
                        .font(Typography.headlineSmall)
                        .foregroundColor(.textPrimary)
                        .placeholder(when: state.userName.isEmpty) {
                            Text("Enter your name")
                                .font(Typography.headlineSmall)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, Spacing.base)
                        .padding(.vertical, Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(Color.surfacePrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .stroke(showLimitError ? Color.accentError : (isNameFocused ? Color.accentPrimary : Color.surfaceBorder), lineWidth: 1)
                                )
                        )
                        .focused($isNameFocused)
                        .onChange(of: state.userName) {
                            if state.userName.count > characterLimit {
                                state.userName = String(state.userName.prefix(characterLimit))
                                showLimitError = true
                                Haptics.impact(.heavy)
                            } else {
                                showLimitError = false
                            }
                        }

                    HStack {
                        if showLimitError {
                            Text("Maximum \(characterLimit) characters")
                                .font(Typography.labelSmall)
                                .foregroundColor(.accentError)
                        }

                        Spacer()

                        Text("\(state.userName.count)/\(characterLimit)")
                            .font(Typography.labelSmall)
                            .foregroundColor(showLimitError ? .accentError : .textMuted)
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .padding(.top, Spacing.sm)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            PrimaryButton(
                title: "Continue",
                action: onContinue,
                isEnabled: state.isNameValid
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                hasAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isNameFocused = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingNameView(
            state: OnboardingState(),
            step: .name,
            onContinue: {},
            onBack: {}
        )
    }
}
