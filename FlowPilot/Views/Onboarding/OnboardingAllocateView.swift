import SwiftUI

struct OnboardingAllocateView: View {
    @ObservedObject var state: OnboardingState
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
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: Spacing.xl) {
                    // Back button and step indicator
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.surfaceBorder, lineWidth: 1)
                                        )
                                )
                        }

                        Spacer()

                        StepIndicator(step: 4, title: "Allocate Time")

                        Spacer()

                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)

                    // Progress
                    OnboardingProgressIndicator(currentStep: 3, totalSteps: 4)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)

                // Title section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Allocate your")
                        .font(Typography.displayMedium)
                        .foregroundColor(.textPrimary)

                    Text("weekly hours")
                        .font(Typography.displayMedium)
                        .foregroundColor(.accentPrimary)

                    Text("Drag the sliders to set hours for each priority")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textSecondary)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xxl)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)

                // Hours overview card
                HoursOverviewCard(
                    allocated: totalAllocated,
                    available: availableHours,
                    percentage: allocationPercentage
                )
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)

                // Priority sliders
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(Array(state.priorities.enumerated()), id: \.element.id) { index, priority in
                            PrioritySliderRow(
                                priority: priority,
                                maxHours: min(80, availableHours),
                                onHoursChange: { newHours in
                                    if let idx = state.priorities.firstIndex(where: { $0.id == priority.id }) {
                                        state.priorities[idx].hoursPerWeek = newHours
                                    }
                                }
                            )
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05 + 0.1), value: hasAppeared)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)

                // Bottom button
                VStack(spacing: Spacing.sm) {
                    if remainingHours < 0 {
                        Text("Over-allocated by \(Int(abs(remainingHours))) hours")
                            .font(Typography.labelMedium)
                            .foregroundColor(.accentError)
                    }

                    PrimaryButton(
                        title: "Complete Setup",
                        action: onComplete,
                        isEnabled: remainingHours >= 0
                    )
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .background(
                    LinearGradient(
                        colors: [
                            Color.backgroundPrimary.opacity(0),
                            Color.backgroundPrimary
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .offset(y: -60)
                )
                .opacity(hasAppeared ? 1 : 0)
            }
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
        VStack(spacing: Spacing.md) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.surfaceBorder)
                        .frame(height: 8)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            percentage > 1.0
                                ? Color.accentError
                                : Color.accentPrimary
                        )
                        .frame(width: geometry.size.width * min(percentage, 1.0), height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: percentage)
                }
            }
            .frame(height: 8)

            // Stats row
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

                VStack(alignment: .center, spacing: 2) {
                    Text("Remaining")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                    Text("\(Int(available - allocated))h")
                        .font(Typography.mono)
                        .foregroundColor(available - allocated < 0 ? .accentError : .accentSuccess)
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
        .padding(Spacing.lg)
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
    let priority: Priority
    let maxHours: Double
    let onHoursChange: (Double) -> Void

    @State private var sliderValue: Double

    init(priority: Priority, maxHours: Double, onHoursChange: @escaping (Double) -> Void) {
        self.priority = priority
        self.maxHours = maxHours
        self.onHoursChange = onHoursChange
        self._sliderValue = State(initialValue: priority.hoursPerWeek)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack {
                // Color dot and name
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 10, height: 10)

                    Text(priority.name)
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Hours display
                Text("\(Int(sliderValue))h / week")
                    .font(Typography.mono)
                    .foregroundColor(.textSecondary)
            }

            // Custom slider
            CustomSlider(
                value: $sliderValue,
                range: 0...maxHours,
                color: priority.color,
                onEditingChanged: { _ in
                    onHoursChange(sliderValue)
                }
            )
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
        .onChange(of: priority.hoursPerWeek) { _, newValue in
            sliderValue = newValue
        }
    }
}

// MARK: - Custom Slider
struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = width * normalizedValue

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.surfaceBorder)
                    .frame(height: 6)

                // Filled track
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: max(0, thumbX), height: 6)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: color.opacity(0.3), radius: isDragging ? 8 : 4, x: 0, y: 2)
                    .scaleEffect(isDragging ? 1.1 : 1.0)
                    .offset(x: thumbX - 12)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                if !isDragging {
                                    isDragging = true
                                    onEditingChanged(true)
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                }
                                let newX = min(max(0, gesture.location.x), width)
                                let newNormalized = newX / width
                                let newValue = range.lowerBound + newNormalized * (range.upperBound - range.lowerBound)
                                value = round(newValue) // Snap to whole numbers
                            }
                            .onEnded { _ in
                                isDragging = false
                                onEditingChanged(false)
                            }
                    )
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDragging)
        }
        .frame(height: 24)
    }
}

#Preview {
    OnboardingAllocateView(
        state: OnboardingState(),
        onComplete: {},
        onBack: {}
    )
}
