import SwiftUI

struct SleepScheduleSection: View {
    @ObservedObject var state: OnboardingState

    private var awakeHoursPerDay: Double {
        state.sleepSchedule.availableHoursPerDay
    }

    private var awakeHoursPerWeek: Double {
        state.sleepSchedule.availableHoursPerWeek
    }

    private var formattedDailyHours: String {
        let wholeHours = Int(awakeHoursPerDay)
        let minutes = Int((awakeHoursPerDay - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours)h"
    }

    private var formattedWeeklyHours: String {
        "\(Int(awakeHoursPerWeek))h"
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            SettingsSectionHeader(
                title: "Sleep Schedule",
                icon: "moon.stars.fill",
                iconColor: .purpleGlow
            )

            VStack(spacing: Spacing.sm) {
                // Time pickers
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

                // Hours Impact Card
                HoursImpactCard(
                    dailyHours: formattedDailyHours,
                    weeklyHours: formattedWeeklyHours
                )
            }
        }
    }
}

// MARK: - Hours Impact Card
struct HoursImpactCard: View {
    let dailyHours: String
    let weeklyHours: String

    var body: some View {
        HStack(spacing: 0) {
            // Daily Hours
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.goldenGlow)

                    Text("Daily")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Text(dailyHours)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.goldenGlow, .goldenGlowLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .goldenGlow.opacity(0.4), radius: 4, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Color.surfaceBorder)
                .frame(width: 1, height: 40)

            // Weekly Hours
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.accentPrimary)

                    Text("Weekly")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }

                Text(weeklyHours)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentPrimary, .accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .accentPrimary.opacity(0.4), radius: 4, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        SleepScheduleSection(state: OnboardingState())
            .padding()
    }
}
