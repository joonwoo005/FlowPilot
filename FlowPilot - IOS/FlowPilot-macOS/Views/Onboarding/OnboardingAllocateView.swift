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
        max(0, availableHours - totalAllocated)
    }

    private var allocationPercentage: Double {
        guard availableHours > 0 else { return 0 }
        return min(1.0, totalAllocated / availableHours)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: Spacing.xl)

            // Two-column layout
            HStack(alignment: .top, spacing: Spacing.xxxl) {
                // Left column - Visualization
                visualizationColumn
                    .frame(width: 320)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : -30)

                // Right column - Sliders
                slidersColumn
                    .frame(maxWidth: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : 30)
            }
            .padding(.horizontal, Spacing.xxxl)
            .padding(.bottom, Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Visualization Column (Left)

    private var visualizationColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Section header
            Text("Your Weekly Plan")
                .font(Typography.headlineSmall)
                .foregroundColor(.textPrimary)

            // Stacked bar chart
            stackedBarChart
                .frame(height: 200)

            // Stats row
            HStack(spacing: Spacing.md) {
                AllocationStatCard(
                    title: "Allocated",
                    value: "\(Int(totalAllocated))h",
                    color: .accentPrimary
                )

                AllocationStatCard(
                    title: "Remaining",
                    value: "\(Int(remainingHours))h",
                    color: .accentSuccess
                )
            }

            // Percentage ring
            percentageRing
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.md)

            Spacer()
        }
    }

    // MARK: - Stacked Bar Chart

    private var stackedBarChart: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let barHeight: CGFloat = 24

            VStack(alignment: .leading, spacing: Spacing.lg) {
                // The stacked bar
                HStack(spacing: 2) {
                    ForEach(state.priorities) { priority in
                        let widthPercentage = availableHours > 0 ? priority.hoursPerWeek / availableHours : 0
                        let segmentWidth = max(4, totalWidth * widthPercentage)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(priority.color)
                            .frame(width: segmentWidth, height: barHeight)
                            .shadow(color: priority.color.opacity(0.4), radius: 4, x: 0, y: 2)
                    }

                    // Remaining portion (gray)
                    if remainingHours > 0 {
                        let remainingPercentage = remainingHours / availableHours
                        let remainingWidth = totalWidth * remainingPercentage

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.surfaceBorder)
                            .frame(width: max(4, remainingWidth), height: barHeight)
                    }

                    Spacer(minLength: 0)
                }
                .animation(.spring(response: 0.4), value: totalAllocated)

                // Legend
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(state.priorities) { priority in
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 10, height: 10)

                            Text(priority.name)
                                .font(Typography.labelSmall)
                                .foregroundColor(.textSecondary)

                            Spacer()

                            Text("\(Int(priority.hoursPerWeek))h")
                                .font(Typography.labelSmall)
                                .foregroundColor(.textMuted)
                        }
                    }

                    if remainingHours > 0 {
                        HStack(spacing: Spacing.sm) {
                            Circle()
                                .fill(Color.surfaceBorder)
                                .frame(width: 10, height: 10)

                            Text("Unallocated")
                                .font(Typography.labelSmall)
                                .foregroundColor(.textMuted)

                            Spacer()

                            Text("\(Int(remainingHours))h")
                                .font(Typography.labelSmall)
                                .foregroundColor(.textMuted)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Percentage Ring

    private var percentageRing: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.surfaceBorder, lineWidth: 10)
                    .frame(width: 100, height: 100)

                // Progress ring
                Circle()
                    .trim(from: 0, to: allocationPercentage)
                    .stroke(
                        LinearGradient(
                            colors: [.accentPrimary, .accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .accentPrimary.opacity(0.4), radius: 8, x: 0, y: 0)
                    .animation(.spring(response: 0.4), value: allocationPercentage)

                // Percentage text
                VStack(spacing: 0) {
                    Text("\(Int(allocationPercentage * 100))")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.textPrimary)
                    Text("%")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }
            }

            Text("Time Allocated")
                .font(Typography.labelSmall)
                .foregroundColor(.textMuted)
        }
    }

    // MARK: - Sliders Column (Right)

    private var slidersColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Allocate your")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text("weekly hours")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.accentPrimary)
            }

            // Priority sliders
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    ForEach($state.priorities) { $priority in
                        EnhancedPrioritySlider(
                            priority: $priority,
                            totalAvailableHours: availableHours,
                            remainingHours: remainingHours
                        )
                    }
                }
            }

            Spacer()

            // Complete button
            HStack {
                // Allocation summary
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(totalAllocated)) of \(Int(availableHours)) hours")
                        .font(Typography.labelMedium)
                        .foregroundColor(.textSecondary)
                    Text("allocated")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                PrimaryButton(
                    title: "Complete Setup",
                    action: onComplete,
                    isEnabled: true
                )
                .frame(width: 180)
            }
        }
    }
}

// MARK: - Allocation Stat Card

struct AllocationStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.labelSmall)
                .foregroundColor(.textMuted)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Enhanced Priority Slider

struct EnhancedPrioritySlider: View {
    @Binding var priority: Priority
    let totalAvailableHours: Double
    let remainingHours: Double

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var inputBuffer = ""
    @FocusState private var isFocused: Bool

    private var maxAllowed: Double {
        priority.hoursPerWeek + remainingHours
    }

    private var clampedHours: Binding<Double> {
        Binding(
            get: { priority.hoursPerWeek },
            set: { newValue in
                if newValue > priority.hoursPerWeek {
                    priority.hoursPerWeek = min(newValue, maxAllowed)
                } else {
                    priority.hoursPerWeek = max(1, newValue)
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header row
            HStack {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 12, height: 12)
                        .shadow(color: priority.color.opacity(0.5), radius: 4, x: 0, y: 0)

                    Text(priority.name)
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Hours with +/- controls
                HStack(spacing: Spacing.sm) {
                    // Minus button
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(priority.hoursPerWeek > 1 ? .textSecondary : .textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.surfaceSecondary)
                        )
                        .onTapGesture {
                            if priority.hoursPerWeek > 1 {
                                Haptics.impact(.light)
                                priority.hoursPerWeek -= 1
                            }
                        }

                    // Editable hours display
                    ZStack {
                        // Hidden TextField for input capture
                        TextField("", text: $inputBuffer)
                            .focused($isFocused)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .frame(width: 50, height: 28)
                            .opacity(isEditing ? 1 : 0)
                            .tint(priority.color)
                            .onChange(of: inputBuffer) {
                                // Filter to only digits and limit to 3 characters
                                let filtered = inputBuffer.filter { $0.isNumber }
                                if filtered != inputBuffer {
                                    inputBuffer = filtered
                                }
                                if inputBuffer.count > 3 {
                                    inputBuffer = String(inputBuffer.prefix(3))
                                }
                            }
                            .onSubmit {
                                commitHours()
                            }
                            .onChange(of: isFocused) {
                                if !isFocused && isEditing {
                                    commitHours()
                                }
                            }

                        // Display text (shown when not editing)
                        if !isEditing {
                            Text("\(Int(priority.hoursPerWeek))h")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(.textPrimary)
                                .frame(width: 50, alignment: .center)
                        }
                    }
                    .frame(width: 50, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isEditing ? Color.surfaceSecondary : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isEditing ? priority.color.opacity(0.6) : Color.clear, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        isEditing = true
                        inputBuffer = ""
                        isFocused = true
                    }

                    // Plus button
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(remainingHours > 0 ? .textSecondary : .textMuted)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.surfaceSecondary)
                        )
                        .onTapGesture {
                            if remainingHours > 0 {
                                Haptics.impact(.light)
                                priority.hoursPerWeek += 1
                            }
                        }
                }
            }

            // Custom slider track
            GeometryReader { geometry in
                let fillPercentage = totalAvailableHours > 0 ? priority.hoursPerWeek / totalAvailableHours : 0
                let fillWidth = geometry.size.width * fillPercentage

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.surfaceBorder)
                        .frame(height: 8)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [priority.color, priority.color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, fillWidth), height: 8)
                        .shadow(color: priority.color.opacity(0.4), radius: 4, x: 0, y: 0)
                        .animation(.spring(response: 0.3), value: priority.hoursPerWeek)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let percentage = max(0, min(1, value.location.x / geometry.size.width))
                            let newValue = percentage * totalAvailableHours
                            clampedHours.wrappedValue = max(1, round(newValue))
                        }
                )
            }
            .frame(height: 8)

            // Min/max labels
            HStack {
                Text("1h")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)
                Spacer()
                Text("\(Int(totalAvailableHours))h")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)
            }
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(isHovered ? priority.color.opacity(0.4) : Color.surfaceBorder, lineWidth: 1)
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func commitHours() {
        isEditing = false
        isFocused = false

        guard !inputBuffer.isEmpty else {
            inputBuffer = ""
            return
        }

        if let value = Double(inputBuffer) {
            let clamped = min(max(1, value), maxAllowed)
            withAnimation(.spring(response: 0.3)) {
                priority.hoursPerWeek = clamped
            }
            Haptics.impact(.medium)
        }

        inputBuffer = ""
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingAllocateView(
            state: {
                let s = OnboardingState()
                s.priorities = [
                    Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 40),
                    Priority(id: UUID(), name: "Health", color: .priorityGreen, hoursPerWeek: 10),
                    Priority(id: UUID(), name: "Family", color: .priorityPurple, hoursPerWeek: 20)
                ]
                return s
            }(),
            step: .allocate,
            onComplete: {},
            onBack: {}
        )
    }
    .frame(width: 900, height: 700)
}
