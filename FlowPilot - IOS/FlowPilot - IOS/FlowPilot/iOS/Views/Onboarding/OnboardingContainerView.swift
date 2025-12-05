import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case priorities = 1
    case sleep = 2
    case allocate = 3

    var progress: Double {
        Double(rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    var stepLabel: String {
        "Step \(rawValue + 1) of \(OnboardingStep.allCases.count)"
    }
}

struct OnboardingContainerView: View {
    @ObservedObject var state: OnboardingState
    @State private var currentStep: OnboardingStep = .name
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var orbitPhase: CGFloat = 0

    let onBack: () -> Void
    let onComplete: (OnboardingState) -> Void

    enum NavigationDirection {
        case forward
        case backward
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height

            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                // Abstract orbital background
                orbitalBackground(screenWidth: screenWidth, screenHeight: screenHeight)

                Group {
                switch currentStep {
                case .name:
                    OnboardingNameView(
                        state: state,
                        step: currentStep,
                        onContinue: { navigateTo(.priorities) },
                        onBack: onBack
                    )

                case .priorities:
                    OnboardingPrioritiesView(
                        state: state,
                        step: currentStep,
                        onContinue: { navigateTo(.sleep) },
                        onBack: { navigateTo(.name) }
                    )

                case .sleep:
                    OnboardingSleepView(
                        state: state,
                        step: currentStep,
                        onContinue: { navigateTo(.allocate) },
                        onBack: { navigateTo(.priorities) }
                    )

                case .allocate:
                    OnboardingAllocateView(
                        state: state,
                        step: currentStep,
                        onComplete: { onComplete(state) },
                        onBack: { navigateTo(.sleep) }
                    )
                }
                }
                .transition(transition)
                .id(currentStep)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                orbitPhase = .pi * 2
            }
        }
    }

    // MARK: - Orbital Background

    @ViewBuilder
    private func orbitalBackground(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let centerX = screenWidth * 0.5
        let centerY = screenHeight * 0.25

        ZStack {
            // Large diffuse orb - blue accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentPrimary.opacity(0.25),
                            Color.accentPrimary.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: screenWidth * 0.5
                    )
                )
                .frame(width: screenWidth * 0.8, height: screenWidth * 0.8)
                .blur(radius: 60)
                .position(x: centerX, y: centerY)

            // Orbiting orb 1 - lighter blue
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentSecondary.opacity(0.35),
                            Color.accentSecondary.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 35)
                .offset(
                    x: cos(orbitPhase) * screenWidth * 0.28,
                    y: sin(orbitPhase) * screenHeight * 0.1
                )
                .position(x: centerX, y: centerY)

            // Orbiting orb 2 - purple accent, opposite phase
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.priorityPurple.opacity(0.25),
                            Color.priorityPurple.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 30)
                .offset(
                    x: cos(orbitPhase + .pi) * screenWidth * 0.22,
                    y: sin(orbitPhase + .pi) * screenHeight * 0.08
                )
                .position(x: centerX, y: centerY + screenHeight * 0.12)
        }
        .frame(width: screenWidth, height: screenHeight)
        .clipped()
    }

    private var transition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    private func navigateTo(_ step: OnboardingStep) {
        Haptics.impact(.light)
        navigationDirection = step.rawValue > currentStep.rawValue ? .forward : .backward
        currentStep = step
    }
}

// MARK: - Shared Onboarding Header
struct OnboardingHeader: View {
    let step: OnboardingStep
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.surfacePrimary))
                    .contentShape(Circle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        onBack()
                    }

                Spacer()
            }

            // Constellation progress bar
            ConstellationProgressBar(
                currentStep: step.rawValue,
                totalSteps: OnboardingStep.allCases.count
            )
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
    }
}

#Preview {
    OnboardingContainerView(
        state: OnboardingState(),
        onBack: { print("Back to sign in") },
        onComplete: { state in
            print("Onboarding complete!")
            print("Name: \(state.userName)")
        }
    )
}
