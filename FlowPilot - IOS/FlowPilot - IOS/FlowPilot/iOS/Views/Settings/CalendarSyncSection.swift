import SwiftUI
import EventKit

struct CalendarSyncSection: View {
    @ObservedObject var timeBlockStore: TimeBlockStore
    @ObservedObject var taskStore: TaskStore

    @StateObject private var calendarService = CalendarService.shared
    @StateObject private var syncStore = CalendarSyncStore.shared
    @State private var showPermissionAlert = false
    @State private var isSyncing = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            SettingsSectionHeader(
                title: "Calendar Sync",
                icon: "calendar.badge.clock",
                iconColor: .accentSuccess
            )

            VStack(spacing: 0) {
                // Permission banner if needed
                if !calendarService.hasCalendarAccess && syncStore.isEnabled {
                    CalendarPermissionBanner {
                        Task {
                            let granted = await calendarService.requestAccess()
                            if !granted {
                                showPermissionAlert = true
                            }
                        }
                    }

                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(height: 1)
                }

                // Single sync toggle
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.accentSuccess.opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentSuccess)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync to Calendar")
                            .font(Typography.bodyMedium)
                            .foregroundColor(.textPrimary)

                        Text("Time blocks appear in Apple Calendar")
                            .font(Typography.labelSmall)
                            .foregroundColor(.textMuted)
                    }

                    Spacer()

                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentSuccess))
                            .scaleEffect(0.8)
                    } else {
                        // Custom toggle
                        ZStack {
                            Capsule()
                                .fill(syncStore.isEnabled ? Color.accentSuccess.opacity(0.3) : Color.surfaceSecondary)
                                .frame(width: 48, height: 28)
                                .overlay(
                                    Capsule()
                                        .stroke(syncStore.isEnabled ? Color.accentSuccess.opacity(0.5) : Color.surfaceBorder, lineWidth: 1)
                                )

                            Circle()
                                .fill(syncStore.isEnabled ? Color.accentSuccess : Color.textMuted)
                                .frame(width: 22, height: 22)
                                .shadow(color: syncStore.isEnabled ? Color.accentSuccess.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
                                .offset(x: syncStore.isEnabled ? 10 : -10)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: syncStore.isEnabled)
                        }
                        .onTapGesture {
                            handleToggle()
                        }
                    }
                }
                .padding(.horizontal, Spacing.base)
                .padding(.vertical, Spacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.surfaceBorder, lineWidth: 1)
                    )
            )
        }
        .alert("Calendar Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable calendar access in Settings to sync your time blocks.")
        }
        .onAppear {
            calendarService.checkAuthorizationStatus()
        }
    }

    // MARK: - Toggle Handler

    private func handleToggle() {
        Haptics.impact(.light)

        let newValue = !syncStore.isEnabled

        if newValue && !calendarService.hasCalendarAccess {
            // Request permission first
            Task {
                let granted = await calendarService.requestAccess()
                if granted {
                    await MainActor.run {
                        syncStore.setEnabled(true)
                        performSync()
                    }
                } else {
                    await MainActor.run {
                        showPermissionAlert = true
                    }
                }
            }
        } else {
            syncStore.setEnabled(newValue)

            if newValue {
                performSync()
            } else {
                // Remove all synced items
                Task {
                    try? calendarService.removeAllSynced()
                }
            }
        }
    }

    private func performSync() {
        isSyncing = true
        Task {
            do {
                let blocks = timeBlockStore.todayBlocks + timeBlockStore.upcomingBlocks
                try await calendarService.syncAllTimeBlocks(blocks)
            } catch {
                print("Sync error: \(error)")
            }
            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

// MARK: - Calendar Permission Banner

struct CalendarPermissionBanner: View {
    let onRequestAccess: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentWarm.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .blur(radius: 4)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.accentWarm)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar Access Required")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.textPrimary)

                Text("Enable to sync with Apple Calendar")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)
            }

            Spacer()

            Text("Enable")
                .font(Typography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(.accentPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.accentPrimary.opacity(0.15))
                )
                .onTapGesture {
                    Haptics.impact(.light)
                    onRequestAccess()
                }
        }
        .padding(Spacing.base)
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        CalendarSyncSection(
            timeBlockStore: TimeBlockStore(),
            taskStore: TaskStore()
        )
        .padding()
    }
}
