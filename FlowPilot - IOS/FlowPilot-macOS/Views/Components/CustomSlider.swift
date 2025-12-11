import SwiftUI

// MARK: - Custom Slider (macOS)
/// A styled slider with gradient fill, +/- buttons, and editable value display

struct CustomSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 1...100
    var step: Double = 1
    var label: String? = nil
    var valueFormatter: ((Double) -> String)? = nil
    var accentColor: Color = .accentPrimary
    var showPlusMinus: Bool = true
    var showMinMaxLabels: Bool = true

    @State private var isEditing: Bool = false
    @State private var inputBuffer: String = ""
    @State private var isHovered: Bool = false
    @FocusState private var isFocused: Bool

    private var formattedValue: String {
        if let formatter = valueFormatter {
            return formatter(value)
        }
        return "\(Int(value))"
    }

    private var canDecrease: Bool {
        value > range.lowerBound
    }

    private var canIncrease: Bool {
        value < range.upperBound
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // Header row
            HStack {
                // Label
                if let label = label {
                    Text(label)
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                // Value with +/- controls
                HStack(spacing: Spacing.sm) {
                    if showPlusMinus {
                        // Minus button
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(canDecrease ? .textSecondary : .textMuted)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.surfaceSecondary))
                            .onTapGesture {
                                if canDecrease {
                                    Haptics.impact(.light)
                                    value = max(range.lowerBound, value - step)
                                }
                            }
                    }

                    // Editable value display
                    editableValueDisplay

                    if showPlusMinus {
                        // Plus button
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(canIncrease ? .textSecondary : .textMuted)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.surfaceSecondary))
                            .onTapGesture {
                                if canIncrease {
                                    Haptics.impact(.light)
                                    value = min(range.upperBound, value + step)
                                }
                            }
                    }
                }
            }

            // Custom slider track
            GeometryReader { geometry in
                let fillPercentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let fillWidth = geometry.size.width * fillPercentage

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.surfaceBorder)
                        .frame(height: 8)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, fillWidth), height: 8)
                        .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
                        .animation(.spring(response: 0.3), value: value)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { dragValue in
                            let percentage = max(0, min(1, dragValue.location.x / geometry.size.width))
                            let newValue = range.lowerBound + percentage * (range.upperBound - range.lowerBound)
                            value = round(newValue / step) * step
                        }
                )
            }
            .frame(height: 8)

            // Min/max labels
            if showMinMaxLabels {
                HStack {
                    Text(valueFormatter?(range.lowerBound) ?? "\(Int(range.lowerBound))")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                    Spacer()
                    Text(valueFormatter?(range.upperBound) ?? "\(Int(range.upperBound))")
                        .font(Typography.labelSmall)
                        .foregroundColor(.textMuted)
                }
            }
        }
    }

    // MARK: - Editable Value Display

    private var editableValueDisplay: some View {
        ZStack {
            // Hidden TextField for input capture
            TextField("", text: $inputBuffer)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(width: 50, height: 28)
                .opacity(isEditing ? 1 : 0)
                .tint(accentColor)
                .onChange(of: inputBuffer) {
                    let filtered = inputBuffer.filter { $0.isNumber }
                    if filtered != inputBuffer {
                        inputBuffer = filtered
                    }
                    if inputBuffer.count > 3 {
                        inputBuffer = String(inputBuffer.prefix(3))
                    }
                }
                .onSubmit {
                    commitValue()
                }
                .onChange(of: isFocused) {
                    if !isFocused && isEditing {
                        commitValue()
                    }
                }

            // Display text (shown when not editing)
            if !isEditing {
                Text(formattedValue)
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .frame(width: 50, alignment: .center)
            }
        }
        .frame(width: 50, height: 28)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isEditing ? Color.surfaceSecondary : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isEditing ? accentColor.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            isEditing = true
            inputBuffer = ""
            isFocused = true
        }
    }

    private func commitValue() {
        isEditing = false
        isFocused = false

        guard !inputBuffer.isEmpty else {
            inputBuffer = ""
            return
        }

        if let newValue = Double(inputBuffer) {
            let clamped = min(max(range.lowerBound, newValue), range.upperBound)
            withAnimation(.spring(response: 0.3)) {
                value = clamped
            }
            Haptics.impact(.medium)
        }

        inputBuffer = ""
    }
}

// MARK: - Compact Slider (for inline use)

struct CompactSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...100
    var accentColor: Color = .accentPrimary

    var body: some View {
        GeometryReader { geometry in
            let fillPercentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let fillWidth = geometry.size.width * fillPercentage

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.surfaceBorder)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: max(6, fillWidth), height: 6)
                    .shadow(color: accentColor.opacity(0.3), radius: 3, x: 0, y: 0)
                    .animation(.spring(response: 0.25), value: value)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        let percentage = max(0, min(1, dragValue.location.x / geometry.size.width))
                        value = range.lowerBound + percentage * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 6)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: Spacing.xxl) {
            CustomSlider(
                value: .constant(35),
                range: 1...80,
                label: "Work",
                valueFormatter: { "\(Int($0))h" },
                accentColor: .priorityBlue
            )
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.surfacePrimary)
            )

            CustomSlider(
                value: .constant(15),
                range: 1...40,
                label: "Health",
                valueFormatter: { "\(Int($0))h" },
                accentColor: .priorityGreen
            )
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.surfacePrimary)
            )

            CompactSlider(
                value: .constant(0.6),
                range: 0...1,
                accentColor: .accentPrimary
            )
            .frame(width: 200)
        }
        .padding(Spacing.xl)
        .frame(width: 400)
    }
}
