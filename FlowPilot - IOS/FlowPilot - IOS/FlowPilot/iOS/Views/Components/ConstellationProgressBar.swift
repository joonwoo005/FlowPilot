import SwiftUI

/// A constellation-style progress bar with glowing connected nodes
/// Designed to complement the orbital background aesthetic
struct ConstellationProgressBar: View {
    let currentStep: Int
    let totalSteps: Int

    @State private var hasAppeared = false
    @State private var pulsePhase: CGFloat = 0
    @State private var glowIntensity: CGFloat = 0.6

    private let nodeSize: CGFloat = 12
    private let activeNodeSize: CGFloat = 14
    private let lineHeight: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let nodeSpacing = (availableWidth - (CGFloat(totalSteps) * nodeSize)) / CGFloat(totalSteps - 1)

            ZStack {
                // Background track - subtle line connecting all nodes
                trackLine(width: availableWidth)

                // Progress line - glowing filled portion
                progressLine(width: availableWidth, nodeSpacing: nodeSpacing)

                // Nodes
                HStack(spacing: nodeSpacing) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        nodeView(for: step)
                    }
                }
            }
            .frame(height: 24)
        }
        .frame(height: 24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                hasAppeared = true
            }
            // Continuous pulse animation for active node
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulsePhase = 1
                glowIntensity = 1
            }
        }
    }

    // MARK: - Track Line (background)

    private func trackLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: lineHeight / 2)
            .fill(Color.surfaceBorder.opacity(0.5))
            .frame(width: width, height: lineHeight)
            .opacity(hasAppeared ? 1 : 0)
    }

    // MARK: - Progress Line (filled portion with glow)

    private func progressLine(width: CGFloat, nodeSpacing: CGFloat) -> some View {
        let progressWidth = currentStep == 0 ? nodeSize / 2 :
            CGFloat(currentStep) * (nodeSize + nodeSpacing) + nodeSize / 2

        return ZStack {
            // Glow layer
            RoundedRectangle(cornerRadius: lineHeight / 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentPrimary.opacity(0.3),
                            Color.accentPrimary.opacity(0.6),
                            Color.accentSecondary.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, progressWidth), height: lineHeight + 4)
                .blur(radius: 4)

            // Main progress line
            RoundedRectangle(cornerRadius: lineHeight / 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentPrimary,
                            Color.accentSecondary
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(0, progressWidth), height: lineHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
    }

    // MARK: - Node View

    private func nodeView(for step: Int) -> some View {
        let isCompleted = step < currentStep
        let isCurrent = step == currentStep
        let isUpcoming = step > currentStep

        return ZStack {
            // Outer glow for completed/current nodes
            if isCompleted || isCurrent {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentPrimary.opacity(isCurrent ? 0.4 * glowIntensity : 0.25),
                                Color.accentPrimary.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: isCurrent ? 18 : 14
                        )
                    )
                    .frame(width: 36, height: 36)
                    .scaleEffect(isCurrent ? 1 + (pulsePhase * 0.15) : 1)
            }

            // Node ring (for upcoming)
            if isUpcoming {
                Circle()
                    .stroke(Color.surfaceBorder, lineWidth: 1.5)
                    .frame(width: nodeSize, height: nodeSize)
            }

            // Node fill
            Circle()
                .fill(
                    isCompleted || isCurrent ?
                    LinearGradient(
                        colors: [Color.accentPrimary, Color.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color.surfacePrimary, Color.surfacePrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: isCurrent ? activeNodeSize : nodeSize,
                    height: isCurrent ? activeNodeSize : nodeSize
                )
                .shadow(
                    color: (isCompleted || isCurrent) ? Color.accentPrimary.opacity(0.5) : .clear,
                    radius: isCurrent ? 8 : 4
                )

            // Inner highlight for active/completed
            if isCompleted || isCurrent {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 4, height: 4)
                    .offset(x: -2, y: -2)
            }

            // Checkmark for completed steps
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: nodeSize, height: nodeSize)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.5)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7)
                .delay(Double(step) * 0.08),
            value: hasAppeared
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        ForEach(0..<5) { step in
            VStack(spacing: 8) {
                Text("Step \(step + 1) of 4")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                ConstellationProgressBar(currentStep: step, totalSteps: 4)
                    .padding(.horizontal, 24)
            }
        }
    }
    .padding(.vertical, 40)
    .background(Color.backgroundPrimary)
}
