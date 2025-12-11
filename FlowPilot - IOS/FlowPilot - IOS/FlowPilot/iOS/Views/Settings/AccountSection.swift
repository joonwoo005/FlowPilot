import SwiftUI

struct AccountSection: View {
    let userName: String
    let userEmail: String
    let userPhotoURL: String?
    let isAnonymous: Bool
    let onLinkWithGoogle: () -> Void
    let onDeleteData: () -> Void
    let onSignOut: () -> Void

    @State private var showSignOutConfirmation = false
    @State private var showGuestSignOutWarning = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            SettingsSectionHeader(
                title: "Account",
                icon: "person.fill",
                iconColor: .accentPrimary
            )

            // Profile Card (separate from action items)
            HStack(spacing: Spacing.md) {
                // Avatar - profile picture or initial
                ZStack {
                    Circle()
                        .fill(Color.accentPrimary.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .blur(radius: 8)

                    if let photoURL = userPhotoURL, let url = URL(string: photoURL) {
                        // Profile picture from Google
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentPrimary.opacity(0.4), lineWidth: 1)
                                    )
                            case .failure, .empty:
                                // Fallback to initial
                                initialAvatar
                            @unknown default:
                                initialAvatar
                            }
                        }
                    } else {
                        // Initial-based avatar
                        initialAvatar
                    }
                }
                .shadow(color: .accentPrimary.opacity(0.3), radius: 8, x: 0, y: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(Typography.bodyLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    Text(isAnonymous ? "Guest Account" : userEmail)
                        .font(Typography.labelSmall)
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
                            .stroke(Color.surfaceBorder, lineWidth: 1)
                    )
            )

            // Action Items - unified group
            VStack(spacing: 1) {
                // Continue with Google (only for anonymous users)
                if isAnonymous {
                    ContinueWithGoogleRow(onTap: onLinkWithGoogle)
                }

                // Sign Out
                SignOutRow(
                    action: {
                        if isAnonymous {
                            showGuestSignOutWarning = true
                        } else {
                            showSignOutConfirmation = true
                        }
                    },
                    isFirst: !isAnonymous
                )
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(Color.surfacePrimary)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .stroke(Color.surfaceBorder, lineWidth: 1)
            )
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                onSignOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog("Sign Out Guest Account", isPresented: $showGuestSignOutWarning, titleVisibility: .visible) {
            Button("Sign Out & Delete Data", role: .destructive) {
                onDeleteData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Guest accounts cannot be recovered. All your tasks, time blocks, and priorities will be permanently deleted.")
        }
    }

    private var initialAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.accentPrimary.opacity(0.3), Color.accentPrimary.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 52, height: 52)
            .overlay(
                Circle()
                    .stroke(Color.accentPrimary.opacity(0.4), lineWidth: 1)
            )
            .overlay(
                Text(String(userName.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.accentPrimary)
            )
    }
}

// MARK: - Continue with Google Row
struct ContinueWithGoogleRow: View {
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Google icon in a container
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color.white)
                    .frame(width: 36, height: 36)

                GoogleIcon()
                    .frame(width: 18, height: 18)
            }
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)

            Text("Continue with Google")
                .font(Typography.bodyMedium)
                .foregroundColor(.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textMuted)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(Color.surfacePrimary)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            Haptics.impact(.medium)
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                onTap()
            }
        }
    }
}

// MARK: - Sign Out Row
struct SignOutRow: View {
    let action: () -> Void
    var isFirst: Bool = false
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle()
                    .fill(Color.surfaceBorder)
                    .frame(height: 1)
                    .padding(.leading, 60)
            }

            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .fill(Color.accentError.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.accentError)
                }

                Text("Sign Out")
                    .font(Typography.bodyMedium)
                    .foregroundColor(.accentError)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
            }
            .padding(.horizontal, Spacing.base)
            .padding(.vertical, Spacing.md)
        }
        .background(Color.surfacePrimary)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            Haptics.impact(.light)
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        AccountSection(
            userName: "John Doe",
            userEmail: "john@example.com",
            userPhotoURL: nil,
            isAnonymous: false,
            onLinkWithGoogle: {},
            onDeleteData: {},
            onSignOut: {}
        )
        .padding()
    }
}
