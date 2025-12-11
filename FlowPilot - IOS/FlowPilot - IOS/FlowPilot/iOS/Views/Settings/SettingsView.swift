import SwiftUI

struct SettingsView: View {
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    let isAnonymous: Bool
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @ObservedObject var taskStore: TaskStore
    let onLinkWithGoogle: () -> Void
    let onDeleteData: () -> Void
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Calendar Sync Section
                        CalendarSyncSection(
                            timeBlockStore: timeBlockStore,
                            taskStore: taskStore
                        )

                        // Sleep Schedule Section
                        SleepScheduleSection(state: priorityStore)

                        // Priorities Section
                        PrioritiesSection(state: priorityStore)

                        // Account Section
                        AccountSection(
                            userName: userName,
                            userEmail: userEmail,
                            userPhotoURL: userPhotoURL,
                            isAnonymous: isAnonymous,
                            onLinkWithGoogle: onLinkWithGoogle,
                            onDeleteData: onDeleteData,
                            onSignOut: onSignOut
                        )
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("Done")
                        .font(Typography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.accentPrimary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }
            }
        }
    }
}

// MARK: - Section Header Component
struct SettingsSectionHeader: View {
    let title: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .blur(radius: 4)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .shadow(color: iconColor.opacity(0.3), radius: 6, x: 0, y: 0)

            Text(title)
                .font(Typography.labelLarge)
                .foregroundColor(.textPrimary)

            Spacer()
        }
    }
}

#Preview {
    SettingsView(
        userName: "John",
        userEmail: "john@example.com",
        userPhotoURL: nil,
        isAnonymous: false,
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore(),
        taskStore: TaskStore(),
        onLinkWithGoogle: {},
        onDeleteData: {},
        onSignOut: {}
    )
}
