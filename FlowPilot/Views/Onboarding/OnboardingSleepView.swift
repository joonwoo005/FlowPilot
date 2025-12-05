import SwiftUI

// MARK: - Glow Colors
extension Color {
    static let goldenGlow = Color(hex: "FFB800")
    static let goldenGlowLight = Color(hex: "FFD54F")
    static let purpleGlow = Color(hex: "A855F7")
    static let purpleGlowLight = Color(hex: "C084FC")
}

struct OnboardingSleepView: View {
    @ObservedObject var state: OnboardingState
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false
    @State private var showWakePicker = false
    @State private var showSleepPicker = false
    @State private var glowPulse = false

    private var awakeHours: Double {
        state.sleepSchedule.availableHoursPerDay
    }

    private var sleepHours: Double {
        24.0 - awakeHours
    }

    private var weeklyAwakeHours: Double {
        state.sleepSchedule.availableHoursPerWeek
    }

    private var awakeHoursText: String {
        let wholeHours = Int(awakeHours)
        let minutes = Int((awakeHours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours)h"
    }

    private var sleepHoursText: String {
        let wholeHours = Int(sleepHours)
        let minutes = Int((sleepHours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours)h"
    }

    private var weeklyHoursText: String {
        let wholeHours = Int(weeklyAwakeHours)
        return "\(wholeHours)"
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

                        StepIndicator(step: 3, title: "Sleep Schedule")

                        Spacer()

                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)

                    // Progress
                    OnboardingProgressIndicator(currentStep: 2, totalSteps: 4)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)

                // Title section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("When are you")
                        .font(Typography.displayMedium)
                        .foregroundColor(.textPrimary)

                    Text("awake?")
                        .font(Typography.displayMedium)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.goldenGlow, .goldenGlowLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("We'll use this to calculate your available hours")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textSecondary)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)

                // Circular time visualization
                ZStack {
                    // Glow background effects
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.goldenGlow.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 60,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .blur(radius: 20)
                        .opacity(glowPulse ? 0.8 : 0.5)

                    // Sleep arc (purple) - background
                    Circle()
                        .stroke(
                            Color.purpleGlow.opacity(0.2),
                            lineWidth: 24
                        )
                        .frame(width: 200, height: 200)

                    // Awake arc (golden)
                    Circle()
                        .trim(from: 0, to: awakeHours / 24.0)
                        .stroke(
                            LinearGradient(
                                colors: [.goldenGlow, .goldenGlowLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 24, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .goldenGlow.opacity(0.6), radius: 12, x: 0, y: 0)
                        .shadow(color: .goldenGlow.opacity(0.3), radius: 24, x: 0, y: 0)

                    // Sleep arc (purple) - visible portion
                    Circle()
                        .trim(from: awakeHours / 24.0, to: 1.0)
                        .stroke(
                            LinearGradient(
                                colors: [.purpleGlow, .purpleGlowLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 24, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .purpleGlow.opacity(0.5), radius: 12, x: 0, y: 0)
                        .shadow(color: .purpleGlow.opacity(0.25), radius: 24, x: 0, y: 0)

                    // Center content
                    VStack(spacing: Spacing.xs) {
                        // Awake hours
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.goldenGlow)
                            Text(awakeHoursText)
                                .font(Typography.mono)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.goldenGlow, .goldenGlowLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: .goldenGlow.opacity(0.5), radius: 8, x: 0, y: 0)

                        // Divider
                        Rectangle()
                            .fill(Color.surfaceBorder)
                            .frame(width: 40, height: 1)
                            .padding(.vertical, Spacing.xs)

                        // Sleep hours
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.purpleGlow)
                            Text(sleepHoursText)
                                .font(Typography.mono)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purpleGlow, .purpleGlowLight],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .shadow(color: .purpleGlow.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                }
                .padding(.vertical, Spacing.lg)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.8)

                // Time pickers
                VStack(spacing: Spacing.md) {
                    // Wake time
                    GlowingTimePickerRow(
                        icon: "sunrise.fill",
                        glowColor: .goldenGlow,
                        label: "Wake up",
                        time: state.sleepSchedule.wakeTime,
                        isExpanded: showWakePicker,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showWakePicker.toggle()
                                showSleepPicker = false
                            }
                        },
                        onTimeChange: { newTime in
                            state.sleepSchedule.wakeTime = newTime
                        }
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                    // Sleep time
                    GlowingTimePickerRow(
                        icon: "moon.fill",
                        glowColor: .purpleGlow,
                        label: "Go to sleep",
                        time: state.sleepSchedule.sleepTime,
                        isExpanded: showSleepPicker,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showSleepPicker.toggle()
                                showWakePicker = false
                            }
                        },
                        onTimeChange: { newTime in
                            state.sleepSchedule.sleepTime = newTime
                        }
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.05), value: hasAppeared)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()

                // Weekly hours display with golden glow
                VStack(spacing: Spacing.sm) {
                    Text("WEEKLY AWAKE HOURS")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                        .tracking(1.5)

                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(weeklyHoursText)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.goldenGlow, .goldenGlowLight],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .goldenGlow.opacity(glowPulse ? 0.8 : 0.4), radius: glowPulse ? 20 : 12, x: 0, y: 0)

                        Text("hrs")
                            .font(Typography.bodyLarge)
                            .foregroundColor(.textSecondary)
                    }

                    Text("available to allocate")
                        .font(Typography.bodySmall)
                        .foregroundColor(.textMuted)
                }
                .padding(.vertical, Spacing.lg)
                .padding(.horizontal, Spacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.goldenGlow.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(
                                    LinearGradient(
                                        colors: [.goldenGlow.opacity(0.4), .goldenGlow.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .goldenGlow.opacity(0.15), radius: 20, x: 0, y: 0)
                )
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAppeared)

                Spacer()

                // Bottom button
                VStack(spacing: Spacing.base) {
                    PrimaryButton(
                        title: "Continue",
                        action: onContinue
                    )
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .opacity(hasAppeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                hasAppeared = true
            }
            // Start glow pulse animation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Glowing Time Picker Row
struct GlowingTimePickerRow: View {
    let icon: String
    let glowColor: Color
    let label: String
    let time: Date
    let isExpanded: Bool
    let onTap: () -> Void
    let onTimeChange: (Date) -> Void

    @State private var selectedTime: Date

    init(
        icon: String,
        glowColor: Color,
        label: String,
        time: Date,
        isExpanded: Bool,
        onTap: @escaping () -> Void,
        onTimeChange: @escaping (Date) -> Void
    ) {
        self.icon = icon
        self.glowColor = glowColor
        self.label = label
        self.time = time
        self.isExpanded = isExpanded
        self.onTap = onTap
        self.onTimeChange = onTimeChange
        self._selectedTime = State(initialValue: time)
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: Spacing.base) {
                // Icon with glow
                ZStack {
                    // Glow background
                    Circle()
                        .fill(glowColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(glowColor)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.sm)
                                .fill(glowColor.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                                        .stroke(glowColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: glowColor.opacity(0.4), radius: 8, x: 0, y: 0)
                }

                // Label
                Text(label)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Time display with glow when expanded
                Text(timeFormatter.string(from: time))
                    .font(Typography.mono)
                    .foregroundColor(isExpanded ? glowColor : .textSecondary)
                    .shadow(color: isExpanded ? glowColor.opacity(0.5) : .clear, radius: 8, x: 0, y: 0)

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.base)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // Expanded picker
            if isExpanded {
                DatePicker(
                    "",
                    selection: $selectedTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 150)
                .padding(.horizontal, Spacing.md)
                .onChange(of: selectedTime) { _, newValue in
                    onTimeChange(newValue)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(
                            isExpanded ? glowColor.opacity(0.5) : Color.surfaceBorder,
                            lineWidth: 1
                        )
                )
                .shadow(color: isExpanded ? glowColor.opacity(0.2) : .clear, radius: 12, x: 0, y: 0)
        )
        .onChange(of: time) { _, newValue in
            selectedTime = newValue
        }
    }
}

#Preview {
    OnboardingSleepView(
        state: OnboardingState(),
        onContinue: {},
        onBack: {}
    )
}
