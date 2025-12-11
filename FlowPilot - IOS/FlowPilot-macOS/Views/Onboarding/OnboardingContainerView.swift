import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case priorities = 1
    case sleep = 2
    case allocate = 3

    var progress: Double {
        Double(rawValue + 1) / Double(OnboardingStep.allCases.count)
    }

    var title: String {
        switch self {
        case .name: return "Name"
        case .priorities: return "Priorities"
        case .sleep: return "Sleep"
        case .allocate: return "Allocate"
        }
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

                // Abstract orbital background - scaled for desktop
                orbitalBackground(screenWidth: screenWidth, screenHeight: screenHeight)

                // Back button at top left
                VStack {
                    HStack {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.surfacePrimary))
                            .contentShape(Circle())
                            .onTapGesture {
                                Haptics.impact(.light)
                                handleBack()
                            }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    Spacer()
                }

                VStack(spacing: 0) {
                    // Enhanced step indicator at top
                    stepIndicator
                        .padding(.top, Spacing.xl)
                        .padding(.bottom, Spacing.lg)

                    // Content area with max width constraint
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
                    .frame(maxWidth: 800)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(transition)
                    .id(currentStep)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
        .onAppear {
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                orbitPhase = .pi * 2
            }
        }
    }

    // MARK: - Enhanced Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: Spacing.xxl) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                stepNode(for: step)
            }
        }
        .padding(.horizontal, Spacing.xxxl)
    }

    @ViewBuilder
    private func stepNode(for step: OnboardingStep) -> some View {
        let isCompleted = step.rawValue < currentStep.rawValue
        let isCurrent = step == currentStep

        HStack(spacing: Spacing.md) {
            // Step dot with glow
            ZStack {
                if isCurrent {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .blur(radius: 8)
                }

                Circle()
                    .fill(isCompleted ? Color.accentPrimary : (isCurrent ? Color.accentPrimary : Color.surfacePrimary))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(isCurrent ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 2)
                    )

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.backgroundPrimary)
                }
            }
            .frame(width: 32, height: 32)

            // Step label
            Text(step.title)
                .font(Typography.labelMedium)
                .foregroundColor(isCurrent ? .textPrimary : (isCompleted ? .textSecondary : .textMuted))

            // Connecting line (not after last step)
            if step != .allocate {
                Rectangle()
                    .fill(isCompleted ? Color.accentPrimary.opacity(0.5) : Color.surfaceBorder)
                    .frame(height: 1)
                    .frame(maxWidth: 60)
            }
        }
    }

    // MARK: - Orbital Background (Scaled for Desktop)

    @ViewBuilder
    private func orbitalBackground(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let centerX = screenWidth * 0.35
        let centerY = screenHeight * 0.4

        ZStack {
            // Large diffuse orb - coral accent (scaled up)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentPrimary.opacity(0.2),
                            Color.accentPrimary.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 450
                    )
                )
                .frame(width: 800, height: 800)
                .blur(radius: 100)
                .position(x: centerX, y: centerY)

            // Orbiting orb 1 - lighter coral
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.accentSecondary.opacity(0.3),
                            Color.accentSecondary.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 55)
                .offset(
                    x: cos(orbitPhase) * 280,
                    y: sin(orbitPhase) * 100
                )
                .position(x: centerX, y: centerY)

            // Orbiting orb 2 - purple accent, opposite phase
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.priorityPurple.opacity(0.2),
                            Color.priorityPurple.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(
                    x: cos(orbitPhase + .pi) * 220,
                    y: sin(orbitPhase + .pi) * 80
                )
                .position(x: centerX, y: centerY + 120)

            // Third subtle orb - adds depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.priorityBlue.opacity(0.15),
                            Color.priorityBlue.opacity(0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 45)
                .offset(
                    x: cos(orbitPhase * 0.7 + .pi/3) * 180,
                    y: sin(orbitPhase * 0.7 + .pi/3) * 60
                )
                .position(x: centerX + 100, y: centerY - 50)
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

    private func handleBack() {
        switch currentStep {
        case .name:
            onBack()
        case .priorities:
            navigateTo(.name)
        case .sleep:
            navigateTo(.priorities)
        case .allocate:
            navigateTo(.sleep)
        }
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 36, height: 36)
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
        .padding(.top, Spacing.lg)
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
    .frame(width: 800, height: 700)
}
