import SwiftUI

// MARK: - Primary Button (macOS)
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true

    @State private var isPressed = false

    var body: some View {
        Text(title)
            .font(Typography.bodyLarge)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? .white : .textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .fill(isEnabled ? Color.accentPrimary : Color.surfaceSecondary)
            )
            .shadow(color: isEnabled ? .accentPrimary.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                Haptics.impact(.medium)
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    action()
                }
            }
    }
}

// MARK: - Flow Layout (for reminder chips)
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)

        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (placements: [(x: CGFloat, y: CGFloat)], height: CGFloat) {
        var placements: [(x: CGFloat, y: CGFloat)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            placements.append((x: currentX, y: currentY))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return (placements, currentY + rowHeight)
    }
}

// MARK: - Placeholder Extension for TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Glowing Time Picker Row
struct GlowingTimePickerRow: View {
    let icon: String
    let glowColor: Color
    let label: String
    @Binding var time: Date

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .blur(radius: 6)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(glowColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.surfaceSecondary)
                    )
            }
            .shadow(color: glowColor.opacity(0.4), radius: 6, x: 0, y: 0)

            Text(label)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)

            Spacer()

            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        PrimaryButton(title: "Continue", action: {})
        PrimaryButton(title: "Disabled", action: {}, isEnabled: false)
    }
    .padding()
    .background(Color.backgroundPrimary)
}
