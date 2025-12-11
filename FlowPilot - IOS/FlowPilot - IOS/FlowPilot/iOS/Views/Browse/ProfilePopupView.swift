import SwiftUI

// MARK: - Profile Popup View
struct ProfilePopupView: View {
    let userName: String
    let userPhotoURL: String?
    let onDismiss: () -> Void
    let onSettings: () -> Void
    let onSignOut: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    Haptics.impact(.light)
                    onDismiss()
                }

            // Popup content
            VStack(spacing: 0) {
                // Profile header
                VStack(spacing: Spacing.md) {
                    // Profile image with glow effect
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.2))
                            .frame(width: 88, height: 88)
                            .blur(radius: 12)

                        profileImage
                            .frame(width: 72, height: 72)
                    }

                    VStack(spacing: Spacing.xs) {
                        Text(userName)
                            .font(Typography.headlineMedium)
                            .foregroundColor(.textPrimary)

                        Text("FlowPilot User")
                            .font(Typography.bodySmall)
                            .foregroundColor(.textMuted)
                    }
                }
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.lg)

                // Divider
                Rectangle()
                    .fill(Color.surfaceBorder)
                    .frame(height: 1)
                    .padding(.horizontal, Spacing.lg)

                // Actions
                VStack(spacing: 0) {
                    // Settings
                    PopupActionRow(
                        icon: "gearshape.fill",
                        title: "Settings",
                        color: .textSecondary
                    ) {
                        Haptics.impact(.light)
                        onSettings()
                    }

                    // Sign Out
                    PopupActionRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "Sign Out",
                        color: .accentError
                    ) {
                        Haptics.impact(.light)
                        onSignOut()
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .fill(Color.surfacePrimary)
                    .shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 12)
            )
            .padding(.horizontal, Spacing.xxl)
            .scaleEffect(showContent ? 1 : 0.9)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }

    // MARK: - Profile Image
    @ViewBuilder
    private var profileImage: some View {
        if let photoURL = userPhotoURL, let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentPrimary.opacity(0.4), lineWidth: 3)
                        )
                case .failure, .empty:
                    profilePlaceholder
                @unknown default:
                    profilePlaceholder
                }
            }
        } else {
            profilePlaceholder
        }
    }

    private var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentPrimary.opacity(0.3), Color.accentPrimary.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.accentPrimary.opacity(0.4), lineWidth: 3)
                )

            Text(String(userName.prefix(1)).uppercased())
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.accentPrimary)
        }
    }
}

// MARK: - Popup Action Row
struct PopupActionRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        ProfilePopupView(
            userName: "John Doe",
            userPhotoURL: nil,
            onDismiss: {},
            onSettings: {},
            onSignOut: {}
        )
    }
}
