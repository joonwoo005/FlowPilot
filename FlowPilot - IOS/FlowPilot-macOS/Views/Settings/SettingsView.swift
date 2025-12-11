import SwiftUI

// MARK: - Settings View (macOS)
struct SettingsView: View {
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    let isAnonymous: Bool
    @ObservedObject var priorityStore: OnboardingState
    @ObservedObject var timeBlockStore: TimeBlockStore
    @ObservedObject var taskStore: TaskStore
    let onLinkWithGoogle: () -> Void
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false
    @State private var closeButtonHovered = false

    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    // Title with icon
                    HStack(spacing: Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.accentPrimary.opacity(0.15))
                                .frame(width: 36, height: 36)

                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.accentPrimary, .accentSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("Settings")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                    }

                    Spacer()

                    // Close button with hover
                    ZStack {
                        Circle()
                            .fill(closeButtonHovered ? Color.surfaceSecondary.opacity(1.5) : Color.surfaceSecondary)
                            .frame(width: 30, height: 30)

                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(closeButtonHovered ? .textPrimary : .textSecondary)
                    }
                    .scaleEffect(closeButtonHovered ? 1.05 : 1.0)
                    .contentShape(Circle())
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            closeButtonHovered = hovering
                        }
                    }
                    .onTapGesture {
                        Haptics.impact(.light)
                        dismiss()
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

                // Content
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Account Section
                        SimpleAccountSection(
                            userName: userName,
                            userEmail: userEmail,
                            userPhotoURL: userPhotoURL,
                            isAnonymous: isAnonymous,
                            onLinkWithGoogle: onLinkWithGoogle,
                            onSignOut: { showSignOutConfirmation = true }
                        )

                        // Calendar Sync Section
                        SimpleCalendarSyncSection(timeBlockStore: timeBlockStore)

                        // Sleep Schedule Section
                        SimpleSleepSection(state: priorityStore)

                        // Priorities Section
                        SimplePrioritiesSection(state: priorityStore)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.lg)
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .confirmationDialog(
            isAnonymous ? "Sign Out Guest Account" : "Sign Out",
            isPresented: $showSignOutConfirmation
        ) {
            Button(isAnonymous ? "Sign Out & Delete Data" : "Sign Out", role: .destructive) {
                onSignOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isAnonymous
                ? "Guest accounts cannot be recovered. All your tasks, time blocks, and priorities will be permanently deleted."
                : "Are you sure you want to sign out?")
        }
    }
}

// MARK: - Section Header
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

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Account Section
struct SimpleAccountSection: View {
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    let isAnonymous: Bool
    let onLinkWithGoogle: () -> Void
    let onSignOut: () -> Void

    @State private var profileHovered = false
    @State private var linkHovered = false
    @State private var signOutHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SettingsSectionHeader(title: "Account", icon: "person.fill", iconColor: .accentPrimary)

            VStack(spacing: Spacing.sm) {
                // Profile card
                HStack(spacing: Spacing.md) {
                    // Avatar - profile picture or initial
                    ZStack {
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.15))
                            .frame(width: 52, height: 52)
                            .blur(radius: 6)

                        if let photoURL = userPhotoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 48, height: 48)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.accentPrimary.opacity(0.4), lineWidth: 1)
                                        )
                                case .failure, .empty:
                                    initialAvatar
                                @unknown default:
                                    initialAvatar
                                }
                            }
                        } else {
                            initialAvatar
                        }
                    }
                    .shadow(color: .accentPrimary.opacity(0.3), radius: 6, x: 0, y: 0)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(userName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.textPrimary)

                        Text(isAnonymous ? "Guest Account" : userEmail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .stroke(
                                    profileHovered ? Color.accentPrimary.opacity(0.3) : Color.surfaceBorder,
                                    lineWidth: 1
                                )
                        )
                )
                .scaleEffect(profileHovered ? 1.01 : 1.0)
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        profileHovered = hovering
                    }
                }

                if isAnonymous {
                    // Link with Google button
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 16))
                        Text("Link with Google")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(
                                LinearGradient(
                                    colors: linkHovered ? [.accentPrimary.opacity(0.9), .accentPrimary] : [.accentPrimary, .accentPrimary.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(linkHovered ? 1.02 : 1.0)
                    .shadow(color: linkHovered ? Color.accentPrimary.opacity(0.4) : Color.clear, radius: 8, x: 0, y: 2)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeOut(duration: 0.15)) {
                            linkHovered = hovering
                        }
                    }
                    .onTapGesture {
                        Haptics.impact(.light)
                        onLinkWithGoogle()
                    }
                }

                // Sign Out button
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                    Text("Sign Out")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(signOutHovered ? .accentError : .accentError.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(signOutHovered ? Color.accentError.opacity(0.1) : Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(signOutHovered ? Color.accentError.opacity(0.5) : Color.accentError.opacity(0.2), lineWidth: 1)
                        )
                )
                .scaleEffect(signOutHovered ? 1.01 : 1.0)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        signOutHovered = hovering
                    }
                }
                .onTapGesture {
                    Haptics.impact(.light)
                    onSignOut()
                }
            }
        }
    }

    private var initialAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.accentPrimary.opacity(0.3), Color.accentPrimary.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 48)
            .overlay(
                Circle()
                    .stroke(Color.accentPrimary.opacity(0.4), lineWidth: 1)
            )
            .overlay(
                Text(String(userName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentPrimary, .accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

// MARK: - Sleep Section
struct SimpleSleepSection: View {
    @ObservedObject var state: OnboardingState

    @State private var wakeRowHovered = false
    @State private var sleepRowHovered = false

    private var awakeHoursPerDay: Double { state.sleepSchedule.availableHoursPerDay }
    private var awakeHoursPerWeek: Double { state.sleepSchedule.availableHoursPerWeek }

    private var formattedDailyHours: String {
        let wholeHours = Int(awakeHoursPerDay)
        let minutes = Int((awakeHoursPerDay - Double(wholeHours)) * 60)
        return minutes > 0 ? "\(wholeHours)h \(minutes)m" : "\(wholeHours)h"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SettingsSectionHeader(title: "Sleep Schedule", icon: "moon.stars.fill", iconColor: .purpleGlow)

            VStack(spacing: Spacing.sm) {
                // Wake up time row
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.goldenGlow.opacity(wakeRowHovered ? 0.2 : 0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.goldenGlow)
                    }

                    Text("Wake up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    CustomTimeInput(
                        time: $state.sleepSchedule.wakeTime,
                        accentColor: .goldenGlow
                    )
                }
                .padding(Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(wakeRowHovered ? Color.goldenGlow.opacity(0.3) : Color.surfaceBorder, lineWidth: 1)
                        )
                )
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        wakeRowHovered = hovering
                    }
                }

                // Sleep time row
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.purpleGlow.opacity(sleepRowHovered ? 0.2 : 0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: "moon.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purpleGlow)
                    }

                    Text("Go to sleep")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Spacer()

                    CustomTimeInput(
                        time: $state.sleepSchedule.sleepTime,
                        accentColor: .purpleGlow
                    )
                }
                .padding(Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(sleepRowHovered ? Color.purpleGlow.opacity(0.3) : Color.surfaceBorder, lineWidth: 1)
                        )
                )
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.15)) {
                        sleepRowHovered = hovering
                    }
                }

                // Hours summary
                HStack(spacing: 0) {
                    // Daily hours
                    VStack(spacing: Spacing.xs) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.goldenGlow)
                            Text("Daily")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                        Text(formattedDailyHours)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.goldenGlow, Color(hex: "FFD54F")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(maxWidth: .infinity)

                    // Divider
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.goldenGlow.opacity(0.3), .purpleGlow.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 1, height: 40)

                    // Weekly hours
                    VStack(spacing: Spacing.xs) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(.accentPrimary)
                            Text("Weekly")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textMuted)
                        }
                        Text("\(Int(awakeHoursPerWeek))h")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accentPrimary, .accentSecondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(maxWidth: .infinity)
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
    }
}

// MARK: - Priorities Section
struct SimplePrioritiesSection: View {
    @ObservedObject var state: OnboardingState
    @State private var editingPriority: Priority? = nil
    @State private var showAddPriority = false

    private var totalAllocated: Double {
        state.priorities.reduce(0) { $0 + $1.hoursPerWeek }
    }

    private var allocationProgress: Double {
        guard state.sleepSchedule.availableHoursPerWeek > 0 else { return 0 }
        return min(totalAllocated / state.sleepSchedule.availableHoursPerWeek, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with progress
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    SettingsSectionHeader(title: "Priorities", icon: "square.stack.3d.up.fill", iconColor: .accentSecondary)

                    Spacer()

                    Text("\(Int(totalAllocated))h / \(Int(state.sleepSchedule.availableHoursPerWeek))h")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(allocationProgress >= 1.0 ? .accentSuccess : .textMuted)
                }

                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.surfaceSecondary)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.accentPrimary, .accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, 400 * allocationProgress), height: 4)
                }
            }

            // Priority rows
            VStack(spacing: 0) {
                ForEach(state.priorities) { priority in
                    HStack(spacing: Spacing.md) {
                        // Color indicator
                        ZStack {
                            Circle()
                                .fill(priority.color.opacity(0.2))
                                .frame(width: 32, height: 32)

                            Circle()
                                .fill(priority.color)
                                .frame(width: 12, height: 12)
                        }

                        Text(priority.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textPrimary)

                        Spacer()

                        Text("\(Int(priority.hoursPerWeek))h/wk")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(priority.color)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.textMuted)
                    }
                    .padding(.horizontal, Spacing.base)
                    .padding(.vertical, Spacing.sm + 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.impact(.light)
                        editingPriority = priority
                    }

                    if priority.id != state.priorities.last?.id {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(Color.surfaceBorder, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))

            if state.canAddPriority {
                // Add Priority button
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add Priority")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                        )
                        .foregroundColor(Color.accentPrimary.opacity(0.3))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    Haptics.impact(.light)
                    showAddPriority = true
                }
            }
        }
        .sheet(item: $editingPriority) { priority in
            SimpleEditPrioritySheet(priority: priority, state: state) { updated in
                if let index = state.priorities.firstIndex(where: { $0.id == priority.id }) {
                    state.priorities[index] = updated
                }
                editingPriority = nil
            } onDelete: {
                state.priorities.removeAll { $0.id == priority.id }
                editingPriority = nil
            }
        }
        .sheet(isPresented: $showAddPriority) {
            SimpleAddPrioritySheet(state: state)
        }
    }
}

// MARK: - Priority Row View
struct PriorityRowView: View {
    let priority: Priority
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Color indicator with glow
            ZStack {
                Circle()
                    .fill(priority.color.opacity(isHovered ? 0.3 : 0.2))
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(priority.color)
                    .frame(width: 12, height: 12)
            }

            Text(priority.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textPrimary)

            Spacer()

            Text("\(Int(priority.hoursPerWeek))h/wk")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(priority.color)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isHovered ? .textSecondary : .textMuted)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.sm + 2)
        .background(isHovered ? priority.color.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            Haptics.impact(.light)
            onTap()
        }
    }
}

// MARK: - Simple Edit Priority Sheet
struct SimpleEditPrioritySheet: View {
    let priority: Priority
    @ObservedObject var state: OnboardingState
    let onSave: (Priority) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var hoursPerWeek: Double = 10
    @State private var hoursText: String = ""
    @State private var hoursError: String? = nil
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var hoursFieldFocused: Bool

    @State private var closeHovered = false
    @State private var deleteHovered = false
    @State private var saveHovered = false
    @State private var minusHovered = false
    @State private var plusHovered = false

    private var priorityColor: Color { priority.color }
    private var isValidName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasHoursError: Bool { hoursError != nil }

    private var remainingHours: Double {
        let otherPrioritiesHours = state.priorities
            .filter { $0.id != priority.id }
            .reduce(0) { $0 + $1.hoursPerWeek }
        return max(1, state.sleepSchedule.availableHoursPerWeek - otherPrioritiesHours)
    }

    private var hoursProgress: Double {
        min(1.0, hoursPerWeek / remainingHours)
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            // Subtle ambient glow at top
            VStack {
                RadialGradient(
                    colors: [priorityColor.opacity(0.08), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(height: 200)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack(alignment: .center) {
                    Spacer()

                    // Close button
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(closeHovered ? .textPrimary : .textSecondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(closeHovered ? Color.surfaceSecondary.opacity(1.2) : Color.surfaceSecondary)
                        )
                        .scaleEffect(closeHovered ? 1.05 : 1.0)
                        .contentShape(Circle())
                        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { closeHovered = h } }
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.base)

                // Color orb with progress ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(priorityColor.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 20)

                    // Progress ring background
                    Circle()
                        .stroke(Color.surfaceBorder, lineWidth: 3)
                        .frame(width: 72, height: 72)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: hoursProgress)
                        .stroke(
                            LinearGradient(
                                colors: [priorityColor, priorityColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    // Inner orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [priorityColor.opacity(0.95), priorityColor],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 25
                            )
                        )
                        .frame(width: 44, height: 44)
                        .shadow(color: priorityColor.opacity(0.5), radius: 12, x: 0, y: 4)
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)

                // Form fields
                VStack(spacing: Spacing.lg) {
                    // Name field
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("NAME")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .tracking(1.2)

                        TextField("Priority name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .focused($nameFieldFocused)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm + 4)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(
                                                nameFieldFocused ? priorityColor.opacity(0.6) : Color.surfaceBorder,
                                                lineWidth: nameFieldFocused ? 1.5 : 1
                                            )
                                    )
                            )
                            .shadow(color: nameFieldFocused ? priorityColor.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
                    }

                    // Hours field with stepper
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("WEEKLY HOURS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .tracking(1.2)

                            Spacer()

                            Text("\(Int(remainingHours))h available")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(priorityColor.opacity(0.8))
                        }

                        HStack(spacing: Spacing.sm) {
                            // Minus button
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(minusHovered ? Color.surfaceSecondary : Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .stroke(Color.surfaceBorder, lineWidth: 1)
                                    )

                                Image(systemName: "minus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(hoursPerWeek > 1 ? .textPrimary : .textMuted)
                            }
                            .frame(width: 36, height: 36)
                            .scaleEffect(minusHovered ? 0.95 : 1.0)
                            .contentShape(Rectangle())
                            .onHover { h in withAnimation(.easeOut(duration: 0.1)) { minusHovered = h } }
                            .onTapGesture {
                                guard hoursPerWeek > 1 else { return }
                                Haptics.impact(.light)
                                hoursPerWeek -= 1
                                hoursText = "\(Int(hoursPerWeek))"
                                hoursError = nil
                            }

                            // Hours text input
                            HStack(spacing: 4) {
                                TextField("", text: $hoursText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(hasHoursError ? .accentError : priorityColor)
                                    .multilineTextAlignment(.center)
                                    .focused($hoursFieldFocused)
                                    .frame(width: 50)
                                    .onChange(of: hoursText) {
                                        validateAndUpdateHours()
                                    }

                                Text("h")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(
                                                hasHoursError ? Color.accentError :
                                                    (hoursFieldFocused ? priorityColor.opacity(0.6) : Color.surfaceBorder),
                                                lineWidth: hoursFieldFocused ? 1.5 : 1
                                            )
                                    )
                            )
                            .shadow(color: hoursFieldFocused ? priorityColor.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)

                            // Plus button
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(plusHovered ? Color.surfaceSecondary : Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .stroke(Color.surfaceBorder, lineWidth: 1)
                                    )

                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(hoursPerWeek < remainingHours ? .textPrimary : .textMuted)
                            }
                            .frame(width: 36, height: 36)
                            .scaleEffect(plusHovered ? 0.95 : 1.0)
                            .contentShape(Rectangle())
                            .onHover { h in withAnimation(.easeOut(duration: 0.1)) { plusHovered = h } }
                            .onTapGesture {
                                guard hoursPerWeek < remainingHours else { return }
                                Haptics.impact(.light)
                                hoursPerWeek += 1
                                hoursText = "\(Int(hoursPerWeek))"
                                hoursError = nil
                            }
                        }

                        // Error message
                        if let error = hoursError {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(error)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.accentError)
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                // Bottom actions
                VStack(spacing: Spacing.sm) {
                    // Save button
                    Text("Save Changes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isValidName && !hasHoursError ? .white : .textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .fill(isValidName && !hasHoursError ? priorityColor : Color.surfaceSecondary)
                        )
                        .scaleEffect(saveHovered && isValidName && !hasHoursError ? 1.01 : 1.0)
                        .shadow(color: saveHovered && isValidName && !hasHoursError ? priorityColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 3)
                        .contentShape(Rectangle())
                        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { saveHovered = h } }
                        .onTapGesture {
                            guard isValidName && !hasHoursError else { return }
                            Haptics.impact(.medium)
                            let updated = Priority(
                                id: priority.id,
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                color: priorityColor,
                                hoursPerWeek: hoursPerWeek
                            )
                            onSave(updated)
                        }

                    // Delete button
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Delete Priority")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(deleteHovered ? .accentError : .accentError.opacity(0.7))
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                    .onHover { h in withAnimation(.easeOut(duration: 0.12)) { deleteHovered = h } }
                    .onTapGesture {
                        Haptics.impact(.medium)
                        onDelete()
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
        .frame(width: 340, height: 420)
        .onAppear {
            name = priority.name
            hoursPerWeek = priority.hoursPerWeek
            hoursText = "\(Int(priority.hoursPerWeek))"
        }
    }

    private func validateAndUpdateHours() {
        guard let value = Double(hoursText) else {
            if !hoursText.isEmpty {
                hoursError = "Enter a number"
            }
            return
        }

        if value < 1 {
            hoursError = "Min 1 hour"
            hoursPerWeek = 1
        } else if value > remainingHours {
            hoursError = "Max \(Int(remainingHours))h available"
            hoursPerWeek = remainingHours
        } else {
            hoursError = nil
            hoursPerWeek = round(value)
        }
    }
}

// MARK: - Simple Add Priority Sheet
struct SimpleAddPrioritySheet: View {
    @ObservedObject var state: OnboardingState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var hoursPerWeek: Double = 10
    @State private var hoursText: String = "10"
    @State private var hoursError: String? = nil
    @State private var assignedColor: Color = .priorityBlue
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var hoursFieldFocused: Bool

    @State private var closeHovered = false
    @State private var createHovered = false
    @State private var minusHovered = false
    @State private var plusHovered = false

    private var isValidName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasHoursError: Bool { hoursError != nil }

    private var remainingHours: Double {
        let existingHours = state.priorities.reduce(0) { $0 + $1.hoursPerWeek }
        return max(1, state.sleepSchedule.availableHoursPerWeek - existingHours)
    }

    private var hoursProgress: Double {
        min(1.0, hoursPerWeek / remainingHours)
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            // Subtle ambient glow at top
            VStack {
                RadialGradient(
                    colors: [assignedColor.opacity(0.08), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(height: 200)
                Spacer()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                HStack(alignment: .center) {
                    Spacer()

                    // Close button
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(closeHovered ? .textPrimary : .textSecondary)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle()
                                .fill(closeHovered ? Color.surfaceSecondary.opacity(1.2) : Color.surfaceSecondary)
                        )
                        .scaleEffect(closeHovered ? 1.05 : 1.0)
                        .contentShape(Circle())
                        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { closeHovered = h } }
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.base)

                // Color orb with progress ring and plus icon
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(assignedColor.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 20)

                    // Progress ring background
                    Circle()
                        .stroke(Color.surfaceBorder, lineWidth: 3)
                        .frame(width: 72, height: 72)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: hoursProgress)
                        .stroke(
                            LinearGradient(
                                colors: [assignedColor, assignedColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    // Inner orb with plus
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [assignedColor.opacity(0.95), assignedColor],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: assignedColor.opacity(0.5), radius: 12, x: 0, y: 4)

                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)

                // Form fields
                VStack(spacing: Spacing.lg) {
                    // Name field
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("NAME")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.textMuted)
                            .tracking(1.2)

                        TextField("Priority name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textPrimary)
                            .focused($nameFieldFocused)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm + 4)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(
                                                nameFieldFocused ? assignedColor.opacity(0.6) : Color.surfaceBorder,
                                                lineWidth: nameFieldFocused ? 1.5 : 1
                                            )
                                    )
                            )
                            .shadow(color: nameFieldFocused ? assignedColor.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
                    }

                    // Hours field with stepper
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Text("WEEKLY HOURS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.textMuted)
                                .tracking(1.2)

                            Spacer()

                            Text("\(Int(remainingHours))h available")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(assignedColor.opacity(0.8))
                        }

                        HStack(spacing: Spacing.sm) {
                            // Minus button
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(minusHovered ? Color.surfaceSecondary : Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .stroke(Color.surfaceBorder, lineWidth: 1)
                                    )

                                Image(systemName: "minus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(hoursPerWeek > 1 ? .textPrimary : .textMuted)
                            }
                            .frame(width: 36, height: 36)
                            .scaleEffect(minusHovered ? 0.95 : 1.0)
                            .contentShape(Rectangle())
                            .onHover { h in withAnimation(.easeOut(duration: 0.1)) { minusHovered = h } }
                            .onTapGesture {
                                guard hoursPerWeek > 1 else { return }
                                Haptics.impact(.light)
                                hoursPerWeek -= 1
                                hoursText = "\(Int(hoursPerWeek))"
                                hoursError = nil
                            }

                            // Hours text input
                            HStack(spacing: 4) {
                                TextField("", text: $hoursText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(hasHoursError ? .accentError : assignedColor)
                                    .multilineTextAlignment(.center)
                                    .focused($hoursFieldFocused)
                                    .frame(width: 50)
                                    .onChange(of: hoursText) {
                                        validateAndUpdateHours()
                                    }

                                Text("h")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(
                                                hasHoursError ? Color.accentError :
                                                    (hoursFieldFocused ? assignedColor.opacity(0.6) : Color.surfaceBorder),
                                                lineWidth: hoursFieldFocused ? 1.5 : 1
                                            )
                                    )
                            )
                            .shadow(color: hoursFieldFocused ? assignedColor.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)

                            // Plus button
                            ZStack {
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .fill(plusHovered ? Color.surfaceSecondary : Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .stroke(Color.surfaceBorder, lineWidth: 1)
                                    )

                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(hoursPerWeek < remainingHours ? .textPrimary : .textMuted)
                            }
                            .frame(width: 36, height: 36)
                            .scaleEffect(plusHovered ? 0.95 : 1.0)
                            .contentShape(Rectangle())
                            .onHover { h in withAnimation(.easeOut(duration: 0.1)) { plusHovered = h } }
                            .onTapGesture {
                                guard hoursPerWeek < remainingHours else { return }
                                Haptics.impact(.light)
                                hoursPerWeek += 1
                                hoursText = "\(Int(hoursPerWeek))"
                                hoursError = nil
                            }
                        }

                        // Error message
                        if let error = hoursError {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 10))
                                Text(error)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(.accentError)
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)

                Spacer()

                // Create button
                Text("Create Priority")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isValidName && !hasHoursError ? .white : .textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(isValidName && !hasHoursError ? assignedColor : Color.surfaceSecondary)
                    )
                    .scaleEffect(createHovered && isValidName && !hasHoursError ? 1.01 : 1.0)
                    .shadow(color: createHovered && isValidName && !hasHoursError ? assignedColor.opacity(0.4) : .clear, radius: 10, x: 0, y: 3)
                    .contentShape(Rectangle())
                    .onHover { h in withAnimation(.easeOut(duration: 0.12)) { createHovered = h } }
                    .onTapGesture {
                        guard isValidName && !hasHoursError else { return }
                        Haptics.impact(.medium)
                        let newPriority = Priority(
                            id: UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            color: assignedColor,
                            hoursPerWeek: hoursPerWeek
                        )
                        state.priorities.append(newPriority)
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
            }
        }
        .frame(width: 340, height: 400)
        .onAppear {
            assignedColor = Priority.nextUniqueColor(excluding: state.priorities)
            let initialHours = min(10, remainingHours)
            hoursPerWeek = initialHours
            hoursText = "\(Int(initialHours))"
        }
    }

    private func validateAndUpdateHours() {
        guard let value = Double(hoursText) else {
            if !hoursText.isEmpty {
                hoursError = "Enter a number"
            }
            return
        }

        if value < 1 {
            hoursError = "Min 1 hour"
            hoursPerWeek = 1
        } else if value > remainingHours {
            hoursError = "Max \(Int(remainingHours))h available"
            hoursPerWeek = remainingHours
        } else {
            hoursError = nil
            hoursPerWeek = round(value)
        }
    }
}

// MARK: - Simple Calendar Sync Section (macOS)
struct SimpleCalendarSyncSection: View {
    @ObservedObject var timeBlockStore: TimeBlockStore

    // Use @AppStorage for persistence - doesn't trigger any service access
    @AppStorage("calendarSyncEnabled") private var isEnabled: Bool = false
    @State private var isSyncing = false
    @State private var isHovered = false
    @State private var showPermissionAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SettingsSectionHeader(title: "Calendar Sync", icon: "calendar.badge.clock", iconColor: .accentSuccess)

            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.accentSuccess.opacity(isHovered ? 0.2 : 0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accentSuccess)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync to Calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Text("Time blocks appear in Apple Calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.textMuted)
                }

                Spacer()

                if isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentSuccess))
                        .scaleEffect(0.7)
                } else {
                    // Custom toggle
                    ZStack {
                        Capsule()
                            .fill(isEnabled ? Color.accentSuccess.opacity(0.3) : Color.surfaceSecondary)
                            .frame(width: 44, height: 26)
                            .overlay(
                                Capsule()
                                    .stroke(isEnabled ? Color.accentSuccess.opacity(0.5) : Color.surfaceBorder, lineWidth: 1)
                            )

                        Circle()
                            .fill(isEnabled ? Color.accentSuccess : Color.textMuted)
                            .frame(width: 20, height: 20)
                            .shadow(color: isEnabled ? Color.accentSuccess.opacity(0.4) : .clear, radius: 4, x: 0, y: 0)
                            .offset(x: isEnabled ? 9 : -9)
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        handleToggle()
                    }
                }
            }
            .padding(Spacing.base)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.lg)
                            .stroke(isHovered ? Color.accentSuccess.opacity(0.3) : Color.surfaceBorder, lineWidth: 1)
                    )
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
        .alert("Calendar Access Required", isPresented: $showPermissionAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable calendar access in System Settings > Privacy & Security > Calendars.")
        }
    }

    // Only access CalendarService.shared in action handlers, never in body
    private func handleToggle() {
        Haptics.impact(.light)

        let newValue = !isEnabled

        if newValue {
            // Turning ON - need to check/request permission first
            Task {
                // Access CalendarService only here, on user action
                let service = CalendarService.shared
                service.checkAuthorizationStatus()

                if !service.hasCalendarAccess {
                    let granted = await service.requestAccess()
                    await MainActor.run {
                        if granted {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEnabled = true
                            }
                            performSync()
                        } else {
                            showPermissionAlert = true
                        }
                    }
                } else {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEnabled = true
                        }
                        performSync()
                    }
                }
            }
        } else {
            // Turning OFF
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isEnabled = false
            }
            Task {
                try? CalendarService.shared.removeAllSynced()
            }
        }
    }

    private func performSync() {
        isSyncing = true
        Task {
            do {
                let blocks = timeBlockStore.todayBlocks + timeBlockStore.upcomingBlocks
                try await CalendarService.shared.syncAllTimeBlocks(blocks)
            } catch {
                print("Sync error: \(error)")
            }
            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

#Preview {
    SettingsView(
        userName: "John",
        userEmail: "john@example.com",
        userPhotoURL: nil,
        isAnonymous: true,
        priorityStore: OnboardingState(),
        timeBlockStore: TimeBlockStore(),
        taskStore: TaskStore(),
        onLinkWithGoogle: {},
        onSignOut: {}
    )
}

