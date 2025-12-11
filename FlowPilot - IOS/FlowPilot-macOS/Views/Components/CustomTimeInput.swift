import SwiftUI

// MARK: - Custom Time Input (macOS)
/// A digit-based time input with AM/PM toggle, matching the onboarding design

struct CustomTimeInput: View {
    @Binding var time: Date
    var accentColor: Color = .accentPrimary
    var showClearButton: Bool = false
    var onClear: (() -> Void)? = nil

    @State private var inputBuffer: String = ""
    @State private var typedDigits: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool

    private var displayHour: Int {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        if hour == 0 { return 12 }
        if hour > 12 { return hour - 12 }
        return hour
    }

    private var displayMinute: Int {
        Calendar.current.component(.minute, from: time)
    }

    private var isCurrentlyPM: Bool {
        Calendar.current.component(.hour, from: time) >= 12
    }

    private var formattedTime: String {
        let hourStr = String(format: "%d", displayHour)
        let minStr = String(format: "%02d", displayMinute)
        return "\(hourStr):\(minStr)"
    }

    private var displayFromTyped: String {
        let padded = String(repeating: "0", count: max(0, 4 - typedDigits.count)) + typedDigits
        let h = String(padded.prefix(2))
        let m = String(padded.suffix(2))
        return "\(h):\(m)"
    }

    private var displayText: String {
        isEditing ? displayFromTyped : formattedTime
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Time input with hidden TextField and visible Text overlay
            ZStack {
                // Hidden input field to capture keystrokes
                TextField("", text: $inputBuffer)
                    .textFieldStyle(.plain)
                    .foregroundColor(.clear)
                    .tint(.clear)
                    .focused($isFocused)
                    .frame(width: 65, height: 30)
                    .onChange(of: inputBuffer) {
                        handleInput()
                    }
                    .onSubmit {
                        commitAndExit()
                    }

                // Visible display
                HStack(spacing: 1) {
                    Text(displayText)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(isEditing ? accentColor : .textPrimary)

                    if isEditing {
                        BlinkingCaret(color: accentColor)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .fill(Color.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(isEditing ? accentColor : Color.surfaceBorder, lineWidth: isEditing ? 2 : 1)
                    )
            )
            .shadow(color: isEditing ? accentColor.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 0)
            .contentShape(Rectangle())

            // AM/PM toggle
            HStack(spacing: 2) {
                Text("AM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(!isCurrentlyPM ? accentColor : .textMuted)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(!isCurrentlyPM ? accentColor.opacity(0.2) : Color.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(!isCurrentlyPM ? accentColor.opacity(0.5) : Color.surfaceBorder, lineWidth: 1)
                    )
                    .onTapGesture {
                        togglePeriod(toAM: true)
                    }

                Text("PM")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(isCurrentlyPM ? accentColor : .textMuted)
                    .frame(width: 32, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(isCurrentlyPM ? accentColor.opacity(0.2) : Color.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(isCurrentlyPM ? accentColor.opacity(0.5) : Color.surfaceBorder, lineWidth: 1)
                    )
                    .onTapGesture {
                        togglePeriod(toAM: false)
                    }
            }
            .fixedSize()

            // Optional clear button
            if showClearButton {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.textMuted)
                    .onTapGesture {
                        Haptics.impact(.light)
                        onClear?()
                    }
            }
        }
        .onChange(of: isFocused) {
            if isFocused {
                typedDigits = ""
                inputBuffer = ""
                isEditing = true
            } else {
                if typedDigits.count == 4 {
                    commitTimeFromDigits(typedDigits)
                }
                isEditing = false
                typedDigits = ""
                inputBuffer = ""
            }
        }
        .onTapGesture {
            if isFocused {
                typedDigits = ""
                inputBuffer = ""
            } else {
                isFocused = true
            }
        }
    }

    private func handleInput() {
        let newDigits = inputBuffer.filter { $0.isNumber }

        if !newDigits.isEmpty {
            typedDigits = String((typedDigits + newDigits).suffix(4))
            inputBuffer = ""

            if typedDigits.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.commitTimeFromDigits(self.typedDigits)
                    self.isFocused = false
                }
            }
        } else if !inputBuffer.isEmpty {
            inputBuffer = ""
        }
    }

    private func commitAndExit() {
        if typedDigits.count == 4 {
            commitTimeFromDigits(typedDigits)
        }
        isFocused = false
    }

    private func commitTimeFromDigits(_ digits: String) {
        guard digits.count == 4 else { return }

        let hourStr = String(digits.prefix(2))
        let minStr = String(digits.suffix(2))

        guard let hour = Int(hourStr), let minute = Int(minStr) else { return }

        let validMinute = min(max(minute, 0), 59)
        var hour24: Int

        if hour == 0 {
            hour24 = 0
        } else if hour >= 1 && hour <= 11 {
            hour24 = hour
        } else if hour == 12 {
            hour24 = 12
        } else if hour >= 13 && hour <= 23 {
            hour24 = hour
        } else {
            hour24 = 23
        }

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: time)
        components.hour = hour24
        components.minute = validMinute
        components.second = 0

        if let newDate = calendar.date(from: components) {
            withAnimation(.easeOut(duration: 0.2)) {
                time = newDate
            }
            Haptics.impact(.light)
        }

        isEditing = false
        typedDigits = ""
    }

    private func togglePeriod(toAM: Bool) {
        let calendar = Calendar.current
        var hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)

        if toAM && hour >= 12 {
            hour -= 12
        } else if !toAM && hour < 12 {
            hour += 12
        }

        var components = calendar.dateComponents([.year, .month, .day], from: time)
        components.hour = hour
        components.minute = minute
        components.second = 0

        if let newDate = calendar.date(from: components) {
            withAnimation(.easeOut(duration: 0.2)) {
                time = newDate
            }
            Haptics.impact(.light)
        }
    }
}

// MARK: - Blinking Caret (Static - No repeatForever animation)

struct BlinkingCaret: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 2, height: 16)
    }
}

// MARK: - Time Picker Row (for forms)

struct CustomTimeRow: View {
    let icon: String
    let glowColor: Color
    let label: String
    @Binding var time: Date
    var showClear: Bool = false
    var onClear: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .blur(radius: 10)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(glowColor)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(glowColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: glowColor.opacity(0.4), radius: 10, x: 0, y: 0)
            }

            Text(label)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)

            Spacer()

            CustomTimeInput(
                time: $time,
                accentColor: glowColor,
                showClearButton: showClear,
                onClear: onClear
            )
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .frame(height: 72)
        .clipped()
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

// MARK: - Preview

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()

        VStack(spacing: Spacing.xl) {
            CustomTimeRow(
                icon: "sunrise.fill",
                glowColor: .goldenGlow,
                label: "Wake up",
                time: .constant(Date())
            )

            CustomTimeRow(
                icon: "moon.fill",
                glowColor: .purpleGlow,
                label: "Go to sleep",
                time: .constant(Date())
            )

            CustomTimeInput(
                time: .constant(Date()),
                accentColor: .accentPrimary,
                showClearButton: true
            )
        }
        .padding(Spacing.xl)
        .frame(width: 420)
    }
}
