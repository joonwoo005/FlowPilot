import SwiftUI

struct OnboardingNameView: View {
    @ObservedObject var state: OnboardingState
    let step: OnboardingStep
    let onContinue: () -> Void
    let onBack: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var hasAppeared = false
    @State private var showLimitError = false
    @State private var pulseGlow = false

    private let characterLimit = 20

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Two-column layout
            HStack(alignment: .center, spacing: Spacing.xxxl) {
                // Left column - Welcome visual
                welcomeVisual
                    .frame(maxWidth: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : -30)

                // Right column - Input area
                inputArea
                    .frame(maxWidth: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : 30)
            }
            .padding(.horizontal, Spacing.xxxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                hasAppeared = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isNameFocused = true
            }
        }
    }

    // MARK: - Welcome Visual (Left Column)

    private var welcomeVisual: some View {
        VStack(spacing: Spacing.xxl) {
            // Animated waving hand with glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 60)
                    .scaleEffect(pulseGlow ? 1.1 : 0.9)

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentPrimary.opacity(0.3),
                                Color.accentPrimary.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                    .scaleEffect(pulseGlow ? 1.05 : 0.95)

                // Hand icon with gradient background
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentPrimary.opacity(0.25),
                                    Color.accentPrimary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    // Waving hand icon
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 56, weight: .regular))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.accentPrimary,
                                    Color.accentSecondary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(pulseGlow ? 15 : -5))
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseGlow)
                }
                .shadow(color: Color.accentPrimary.opacity(0.4), radius: 25, x: 0, y: 10)
            }

            // Welcome text
            VStack(spacing: Spacing.sm) {
                Text("Welcome to")
                    .font(Typography.headlineMedium)
                    .foregroundColor(.textSecondary)

                Text("FlowPilot")
                    .font(Typography.displayLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentPrimary, Color.accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Input Area (Right Column)

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("What should we")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text("call you?")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.accentPrimary)
            }

            // Text field
            VStack(alignment: .leading, spacing: Spacing.sm) {
                TextField("Enter your name", text: $state.userName)
                    .font(Typography.headlineSmall)
                    .foregroundColor(.textPrimary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.lg)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.surfacePrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(
                                        showLimitError ? Color.accentError : (isNameFocused ? Color.accentPrimary : Color.surfaceBorder),
                                        lineWidth: isNameFocused ? 2 : 1
                                    )
                            )
                            .shadow(color: isNameFocused ? Color.accentPrimary.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
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
                    .onSubmit {
                        if state.isNameValid {
                            onContinue()
                        }
                    }

                // Character count and error
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

            Spacer()
                .frame(height: Spacing.lg)

            // Continue button - full width to match input
            PrimaryButton(
                title: "Continue",
                action: onContinue,
                isEnabled: state.isNameValid
            )
        }
        .frame(maxWidth: 400)
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
    .frame(width: 900, height: 700)
}
