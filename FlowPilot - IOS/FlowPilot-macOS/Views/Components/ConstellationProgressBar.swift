import SwiftUI

// MARK: - Constellation Progress Bar (macOS)
struct ConstellationProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                ZStack {
                    // Connection line to previous star
                    if index > 0 {
                        Rectangle()
                            .fill(index <= currentStep ? Color.accentPrimary : Color.surfaceBorder)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }

                    // Star
                    Circle()
                        .fill(index <= currentStep ? Color.accentPrimary : Color.surfaceSecondary)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(index <= currentStep ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 1)
                        )
                        .shadow(color: index == currentStep ? .accentPrimary.opacity(0.5) : .clear, radius: 4)
                }
            }
        }
        .animation(.spring(response: 0.4), value: currentStep)
    }
}

#Preview {
    VStack(spacing: 20) {
        ConstellationProgressBar(currentStep: 0, totalSteps: 4)
        ConstellationProgressBar(currentStep: 1, totalSteps: 4)
        ConstellationProgressBar(currentStep: 2, totalSteps: 4)
        ConstellationProgressBar(currentStep: 3, totalSteps: 4)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
