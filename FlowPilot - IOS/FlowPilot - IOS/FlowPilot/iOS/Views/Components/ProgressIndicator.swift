import SwiftUI

struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? Color.accentPrimary : Color.surfaceBorder)
                    .frame(width: index == currentStep ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
    }
}

struct StepIndicator: View {
    let step: Int
    let title: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text("\(step)")
                .font(Typography.labelSmall)
                .fontWeight(.bold)
                .foregroundColor(.textMuted)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.surfacePrimary)
                        .overlay(
                            Circle()
                                .stroke(Color.surfaceBorder, lineWidth: 1)
                        )
                )

            Text(title.uppercased())
                .font(Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundColor(.textMuted)
                .tracking(1.2)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        OnboardingProgressIndicator(currentStep: 0, totalSteps: 4)
        OnboardingProgressIndicator(currentStep: 1, totalSteps: 4)
        OnboardingProgressIndicator(currentStep: 2, totalSteps: 4)
        OnboardingProgressIndicator(currentStep: 3, totalSteps: 4)

        Divider()

        StepIndicator(step: 1, title: "Your Name")
        StepIndicator(step: 2, title: "Priorities")
    }
    .padding()
    .background(Color.backgroundPrimary)
}
