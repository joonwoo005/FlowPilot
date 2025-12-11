import SwiftUI

struct OnboardingAllocateView: View {
    @ObservedObject var state: OnboardingState
    let step: OnboardingStep
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false

    private var totalAllocated: Double {
        state.priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    private var availableHours: Double {
        state.sleepSchedule.availableHoursPerWeek
    }

    private var remainingHours: Double {
        availableHours - totalAllocated
    }

    private var allocationPercentage: Double {
        guard availableHours > 0 else { return 0 }
        return min(1.0, totalAllocated / availableHours)
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: step, onBack: onBack)
                .opacity(hasAppeared ? 1 : 0)

            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Allocate your")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text("weekly hours")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.accentPrimary)

                Text("Set hours for each priority")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)

            // Hours overview
            HoursOverviewCard(
                allocated: totalAllocated,
                available: availableHours,
                percentage: allocationPercentage
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.lg)
            .opacity(hasAppeared ? 1 : 0)

            // Priority sliders
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach($state.priorities) { $priority in
                        PrioritySliderRow(
                            priority: $priority,
                            totalAvailableHours: availableHours,
                            remainingHours: remainingHours,
                            onHoursChanged: { updatedPriority in
                                state.updatePriority(updatedPriority)
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
                .padding(.bottom, 120)
            }
            .opacity(hasAppeared ? 1 : 0)

            Spacer(minLength: 0)

            // Complete button
            PrimaryButton(
                title: "Complete Setup",
                action: onComplete,
                isEnabled: true
            )
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xxl)
            .opacity(hasAppeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Hours Overview Card
struct HoursOverviewCard: View {
    let allocated: Double
    let available: Double
    let percentage: Double

    var body: some View {
        VStack(spacing: Spacing.sm) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.surfaceBorder)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentPrimary)
                        .frame(width: geometry.size.width * min(percentage, 1.0), height: 6)
                        .animation(.spring(response: 0.4), value: percentage)
                }
            }
            .frame(height: 6)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allocated")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                    Text("\(Int(allocated))h")
                        .font(Typography.mono)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Remaining")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                    Text("\(Int(available - allocated))h")
                        .font(Typography.mono)
                        .foregroundColor(.accentSuccess)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Available")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                    Text("\(Int(available))h")
                        .font(Typography.mono)
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Priority Slider Row
struct PrioritySliderRow: View {
    @Binding var priority: Priority
    let totalAvailableHours: Double
    let remainingHours: Double
    var onHoursChanged: ((Priority) -> Void)?

    // Max this slider can go: current value + whatever is remaining
    private var maxAllowed: Double {
        priority.hoursPerWeek + remainingHours
    }

    // Custom binding that clamps value without lag
    private var clampedHours: Binding<Double> {
        Binding(
            get: { priority.hoursPerWeek },
            set: { newValue in
                // Only allow increase if there's remaining hours
                if newValue > priority.hoursPerWeek {
                    priority.hoursPerWeek = min(newValue, maxAllowed)
                } else {
                    priority.hoursPerWeek = max(1, newValue)
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 8, height: 8)

                    Text(priority.name)
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                Text("\(Int(priority.hoursPerWeek))h")
                    .font(Typography.mono)
                    .foregroundColor(.textSecondary)
            }

            // Fixed range for visual proportionality
            Slider(value: clampedHours, in: 1...max(1, totalAvailableHours), step: 1) { editing in
                // Only save when user finishes dragging
                if !editing {
                    onHoursChanged?(priority)
                }
            }
            .tint(priority.color)
        }
        .padding(Spacing.base)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingAllocateView(
            state: OnboardingState(),
            step: .allocate,
            onComplete: {},
            onBack: {}
        )
    }
}
