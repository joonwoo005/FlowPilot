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
    let step: OnboardingStep
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false

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
        VStack(spacing: 0) {
            OnboardingHeader(step: step, onBack: onBack)
                .opacity(hasAppeared ? 1 : 0)

            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("When are you")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text("awake?")
                    .font(Typography.headlineLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.goldenGlow, .goldenGlowLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("We'll use this to calculate your available hours")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textSecondary)
                    .padding(.top, Spacing.xs)
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
                            startRadius: 50,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .blur(radius: 20)
                    .opacity(0.6)

                // Sleep arc (purple) - background
                Circle()
                    .stroke(
                        Color.purpleGlow.opacity(0.2),
                        lineWidth: 20
                    )
                    .frame(width: 160, height: 160)

                // Awake arc (golden)
                Circle()
                    .trim(from: 0, to: awakeHours / 24.0)
                    .stroke(
                        LinearGradient(
                            colors: [.goldenGlow, .goldenGlowLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
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
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .purpleGlow.opacity(0.5), radius: 12, x: 0, y: 0)
                    .shadow(color: .purpleGlow.opacity(0.25), radius: 24, x: 0, y: 0)

                // Center content
                VStack(spacing: Spacing.xs) {
                    // Awake hours
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.goldenGlow)
                        Text(awakeHoursText)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
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
                        .frame(width: 32, height: 1)
                        .padding(.vertical, 2)

                    // Sleep hours
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.purpleGlow)
                        Text(sleepHoursText)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
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
            .padding(.top, Spacing.lg)
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.8)

            // Weekly hours subtext
            HStack(spacing: Spacing.xs) {
                Text(weeklyHoursText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.goldenGlow, .goldenGlowLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .goldenGlow.opacity(0.4), radius: 6, x: 0, y: 0)

                Text("awake hours available per week")
                    .font(Typography.bodySmall)
                    .foregroundColor(.textMuted)
            }
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
            .opacity(hasAppeared ? 1 : 0)

            // Time pickers
            VStack(spacing: Spacing.md) {
                GlowingTimePickerRow(
                    icon: "sunrise.fill",
                    glowColor: .goldenGlow,
                    label: "Wake up",
                    time: $state.sleepSchedule.wakeTime
                )

                GlowingTimePickerRow(
                    icon: "moon.fill",
                    glowColor: .purpleGlow,
                    label: "Go to sleep",
                    time: $state.sleepSchedule.sleepTime
                )
            }
            .padding(.horizontal, Spacing.xl)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
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

// MARK: - Glowing Time Picker Row
struct GlowingTimePickerRow: View {
    let icon: String
    let glowColor: Color
    let label: String
    @Binding var time: Date

    @State private var showPicker = false

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .blur(radius: 8)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(glowColor)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(glowColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: glowColor.opacity(0.4), radius: 8, x: 0, y: 0)
            }

            Text(label)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)

            Spacer()

            // Custom time button with glow
            Text(timeFormatter.string(from: time))
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundColor(glowColor)
                .shadow(color: glowColor.opacity(0.4), radius: 6, x: 0, y: 0)
                .padding(.horizontal, Spacing.base)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(glowColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [glowColor.opacity(0.6), glowColor.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: glowColor.opacity(0.2), radius: 12, x: 0, y: 0)
                .contentShape(Capsule())
                .onTapGesture {
                    Haptics.impact(.light)
                    showPicker = true
                }
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
        .sheet(isPresented: $showPicker) {
            GlowingTimePickerSheet(time: $time, glowColor: glowColor, label: label)
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Glowing Time Picker Sheet
struct GlowingTimePickerSheet: View {
    @Binding var time: Date
    let glowColor: Color
    let label: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Header
            HStack {
                Text(label)
                    .font(Typography.headlineSmall)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [glowColor, glowColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Text("Done")
                    .font(Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentPrimary)
                    .onTapGesture {
                        Haptics.impact(.light)
                        dismiss()
                    }
            }
            .padding(.top, Spacing.base)

            // Wheel picker
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingSleepView(
            state: OnboardingState(),
            step: .sleep,
            onContinue: {},
            onBack: {}
        )
    }
}
