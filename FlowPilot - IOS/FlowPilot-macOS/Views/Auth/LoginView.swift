import SwiftUI

struct LoginView: View {
    @ObservedObject var authService: AuthService

    @State private var showContent = false
    @State private var showButtons = false
    @State private var orbitPhase: CGFloat = 0
    @State private var showError = false
    @State private var errorMessage = ""

    // Welcome screen accent colors (warm coral)
    private let accentCoral = Color(hex: "FF6B5B")
    private let accentCoralLight = Color(hex: "FF8A7A")

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width

            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()

                // Orbital background
                cosmicBackground(screenWidth: screenWidth, screenHeight: screenHeight)

                // Main content - centered for desktop
                VStack(spacing: 0) {
                    Spacer()

                    // Hero section
                    heroSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)

                    Spacer()
                        .frame(height: Spacing.xxxl)

                    // Value propositions
                    valuePropositions
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    Spacer()
                        .frame(height: Spacing.xxxl)

                    // Sign in actions
                    signInActions
                        .frame(maxWidth: 360)
                        .opacity(showButtons ? 1 : 0)
                        .offset(y: showButtons ? 0 : 15)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.xl)
            }
            .frame(width: screenWidth, height: screenHeight)
        }
        .onAppear {
            startAnimations()
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Abstract Orbital Background

    @ViewBuilder
    private func cosmicBackground(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let centerX = screenWidth * 0.5
        let centerY = screenHeight * 0.35

        ZStack {
            // Large diffuse orb - coral
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoral.opacity(0.35),
                            accentCoral.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 350
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 80)
                .position(x: centerX, y: centerY)

            // Orbiting orb 1
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accentCoralLight.opacity(0.5),
                            accentCoralLight.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(
                    x: cos(orbitPhase) * 200,
                    y: sin(orbitPhase) * 100
                )
                .position(x: centerX, y: centerY)

            // Orbiting orb 2 - purple accent
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.priorityPurple.opacity(0.3),
                            Color.priorityPurple.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 45)
                .offset(
                    x: cos(orbitPhase + .pi) * 180,
                    y: sin(orbitPhase + .pi) * 80
                )
                .position(x: centerX, y: centerY + 120)
        }
        .frame(width: screenWidth, height: screenHeight)
        .clipped()
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.sm) {
            // App name
            Text("FlowPilot")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
                .tracking(0.5)

            // Tagline
            Text("YOUR TIME, OPTIMISED")
                .font(Typography.labelMedium)
                .foregroundColor(accentCoralLight)
                .tracking(4)
        }
    }

    // MARK: - Value Propositions

    private var valuePropositions: some View {
        VStack(spacing: Spacing.lg) {
            Text("Take control of your week")
                .font(Typography.headlineMedium)
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.base) {
                FeatureRow(icon: "calendar.badge.clock", text: "Smart time blocking", accent: accentCoralLight)
                FeatureRow(icon: "chart.bar.fill", text: "Track what matters", accent: accentCoralLight)
                FeatureRow(icon: "sparkles", text: "Achieve your goals", accent: accentCoralLight)
            }
            .padding(.top, Spacing.xs)
        }
    }

    // MARK: - Sign In Actions

    private var signInActions: some View {
        VStack(spacing: Spacing.lg) {
            // Primary: Google Sign In
            Button {
                Haptics.impact(.medium)
                Task {
                    do {
                        try await authService.signInWithGoogle()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    GoogleIcon()
                        .frame(width: 20, height: 20)

                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(hex: "1F1F1F"))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.white)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())

            // Divider with "or"
            HStack(spacing: Spacing.md) {
                Rectangle()
                    .fill(Color.surfaceBorder)
                    .frame(height: 1)

                Text("or")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)

                Rectangle()
                    .fill(Color.surfaceBorder)
                    .frame(height: 1)
            }

            // Secondary: Guest access
            Button {
                Haptics.impact(.light)
                Task {
                    do {
                        try await authService.continueAsGuest()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundColor(.textSecondary)

                    Text("Continue as Guest")
                        .font(Typography.bodyMedium)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                .stroke(Color.surfaceBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())

            // Terms
            Text("By continuing, you agree to our Terms & Privacy Policy")
                .font(Typography.labelSmall)
                .foregroundColor(.textMuted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.7).delay(0.1)) {
            showContent = true
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            showButtons = true
        }

        // Slow orbital drift
        withAnimation(
            .linear(duration: 20)
            .repeatForever(autoreverses: false)
        ) {
            orbitPhase = .pi * 2
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let text: String
    let accent: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(accent)

            Text(text)
                .font(Typography.bodyMedium)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Google Icon

struct GoogleIcon: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            // Four colored arcs
            let segments: [(Color, Double, Double)] = [
                (Color(hex: "4285F4"), 0, 90),
                (Color(hex: "34A853"), 90, 180),
                (Color(hex: "FBBC05"), 180, 270),
                (Color(hex: "EA4335"), 270, 360),
            ]

            for (color, start, end) in segments {
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                           startAngle: .degrees(start - 90),
                           endAngle: .degrees(end - 90),
                           clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }

            // White center
            let inner = radius * 0.55
            var innerPath = Path()
            innerPath.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner,
                                            width: inner * 2, height: inner * 2))
            context.fill(innerPath, with: .color(.white))

            // G cutout
            var cutout = Path()
            cutout.move(to: CGPoint(x: center.x, y: center.y - radius * 0.3))
            cutout.addLine(to: CGPoint(x: center.x + radius, y: center.y - radius * 0.3))
            cutout.addLine(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.15))
            cutout.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.15))
            cutout.closeSubpath()
            context.fill(cutout, with: .color(.white))

            // Blue bar
            var bar = Path()
            bar.addRect(CGRect(x: center.x - radius * 0.1, y: center.y - radius * 0.15,
                               width: radius * 1.1, height: radius * 0.35))
            context.fill(bar, with: .color(Color(hex: "4285F4")))
        }
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    LoginView(authService: AuthService.shared)
}
