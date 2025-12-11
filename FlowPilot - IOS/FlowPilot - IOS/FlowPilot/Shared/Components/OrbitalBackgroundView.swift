import SwiftUI

/// A subtle, atmospheric background with slowly orbiting glowing orbs.
/// Designed to match the macOS onboarding aesthetic - calm, sophisticated, and premium.
struct OrbitalBackgroundView: View {
    @State private var orbitPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let centerX = screenWidth * 0.35
            let centerY = screenHeight * 0.38

            ZStack {
                // Primary coral orb - large, diffuse, stationary anchor
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentPrimary.opacity(0.18),
                                Color.accentPrimary.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
                    .frame(width: 500, height: 500)
                    .blur(radius: 80)
                    .position(x: centerX, y: centerY)

                // Orbiting coral accent - lighter, elliptical path
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentSecondary.opacity(0.28),
                                Color.accentSecondary.opacity(0.07),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .blur(radius: 45)
                    .offset(
                        x: cos(orbitPhase) * 200,
                        y: sin(orbitPhase) * 75
                    )
                    .position(x: centerX, y: centerY)

                // Orbiting purple accent - opposite phase for visual balance
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.priorityPurple.opacity(0.18),
                                Color.priorityPurple.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)
                    .blur(radius: 40)
                    .offset(
                        x: cos(orbitPhase + .pi) * 160,
                        y: sin(orbitPhase + .pi) * 60
                    )
                    .position(x: centerX, y: centerY + 90)

                // Blue depth orb - slower rotation, offset position for layered depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.priorityBlue.opacity(0.12),
                                Color.priorityBlue.opacity(0.03),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 35)
                    .offset(
                        x: cos(orbitPhase * 0.7 + .pi / 3) * 140,
                        y: sin(orbitPhase * 0.7 + .pi / 3) * 50
                    )
                    .position(x: centerX + 70, y: centerY - 40)
            }
            .frame(width: screenWidth, height: screenHeight)
            .clipped()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
                orbitPhase = .pi * 2
            }
        }
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary
        OrbitalBackgroundView()
    }
    .ignoresSafeArea()
}
