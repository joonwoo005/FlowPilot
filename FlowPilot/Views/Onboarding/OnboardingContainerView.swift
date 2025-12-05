import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case name = 0
    case priorities = 1
    case sleep = 2
    case allocate = 3
}

struct OnboardingContainerView: View {
    @StateObject private var state = OnboardingState()
    @State private var currentStep: OnboardingStep = .name
    @State private var navigationDirection: NavigationDirection = .forward

    let onComplete: (OnboardingState) -> Void

    enum NavigationDirection {
        case forward
        case backward
    }

    var body: some View {
        ZStack {
            // Current step view
            Group {
                switch currentStep {
                case .name:
                    OnboardingNameView(state: state) {
                        navigateTo(.priorities)
                    }

                case .priorities:
                    OnboardingPrioritiesView(
                        state: state,
                        onContinue: { navigateTo(.sleep) },
                        onBack: { navigateTo(.name) }
                    )

                case .sleep:
                    OnboardingSleepView(
                        state: state,
                        onContinue: { navigateTo(.allocate) },
                        onBack: { navigateTo(.priorities) }
                    )

                case .allocate:
                    OnboardingAllocateView(
                        state: state,
                        onComplete: { onComplete(state) },
                        onBack: { navigateTo(.sleep) }
                    )
                }
            }
            .transition(transition)
            .id(currentStep)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
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
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        navigationDirection = step.rawValue > currentStep.rawValue ? .forward : .backward
        currentStep = step
    }
}

#Preview {
    OnboardingContainerView { state in
        print("Onboarding complete!")
        print("Name: \(state.userName)")
        print("Priorities: \(state.priorities.map { $0.name })")
    }
}
