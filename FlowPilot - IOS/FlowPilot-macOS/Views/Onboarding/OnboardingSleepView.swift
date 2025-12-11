import SwiftUI

// MARK: - Glow Colors
extension Color {
    static let goldenGlow = Color(hex: "FFB800")
    static let goldenGlowLight = Color(hex: "FFD54F")
    static let purpleGlow = Color(hex: "A855F7")
    static let purpleGlowLight = Color(hex: "C084FC")
}

struct OnboardingSleepView: View {
    @ObservedObject var state: OnboardingState
    let step: OnboardingStep
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false

    private var awakeHours: Double {
        state.sleepSchedule.availableHoursPerDay
    }

    private var sleepHours: Double {
        24.0 - awakeHours
    }

    private var weeklyAwakeHours: Double {
        state.sleepSchedule.availableHoursPerWeek
    }

    private var awakeHoursText: String {
        let wholeHours = Int(awakeHours)
        let minutes = Int((awakeHours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours)h"
    }

    private var sleepHoursText: String {
        let wholeHours = Int(sleepHours)
        let minutes = Int((sleepHours - Double(wholeHours)) * 60)
        if minutes > 0 {
            return "\(wholeHours)h \(minutes)m"
        }
        return "\(wholeHours)h"
    }

    private var weeklyHoursText: String {
        let wholeHours = Int(weeklyAwakeHours)
        return "\(wholeHours)"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Two-column layout
            HStack(alignment: .center, spacing: Spacing.xxxl) {
                // Left column - Circular visualization
                circularVisualization
                    .frame(maxWidth: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.9)

                // Right column - Controls and stats
                controlsColumn
                    .frame(maxWidth: .infinity)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(x: hasAppeared ? 0 : 30)
            }
            .padding(.horizontal, Spacing.xxxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Circular Visualization (Left Column)

    private var circularVisualization: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                // Glow background effects
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.goldenGlow.opacity(0.12), Color.clear],
                            center: .center,
                            startRadius: 80,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 30)

                // Hour tick marks
                ForEach(0..<24) { hour in
                    let isMajor = hour % 6 == 0
                    Rectangle()
                        .fill(Color.surfaceBorder.opacity(isMajor ? 0.6 : 0.3))
                        .frame(width: isMajor ? 2 : 1, height: isMajor ? 12 : 6)
                        .offset(y: -130)
                        .rotationEffect(.degrees(Double(hour) * 15))
                }

                // Sleep arc (purple) - background
                Circle()
                    .stroke(
                        Color.purpleGlow.opacity(0.15),
                        lineWidth: 28
                    )
                    .frame(width: 260, height: 260)

                // Awake arc (golden)
                Circle()
                    .trim(from: 0, to: awakeHours / 24.0)
                    .stroke(
                        LinearGradient(
                            colors: [.goldenGlow, .goldenGlowLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .goldenGlow.opacity(0.6), radius: 15, x: 0, y: 0)
                    .shadow(color: .goldenGlow.opacity(0.3), radius: 30, x: 0, y: 0)

                // Sleep arc (purple) - visible portion
                Circle()
                    .trim(from: awakeHours / 24.0, to: 1.0)
                    .stroke(
                        LinearGradient(
                            colors: [.purpleGlow, .purpleGlowLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round)
                    )
                    .frame(width: 260, height: 260)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .purpleGlow.opacity(0.5), radius: 15, x: 0, y: 0)
                    .shadow(color: .purpleGlow.opacity(0.25), radius: 30, x: 0, y: 0)

                // Center content
                VStack(spacing: Spacing.md) {
                    // Awake hours
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.goldenGlow)
                        Text(awakeHoursText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.goldenGlow, .goldenGlowLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .shadow(color: .goldenGlow.opacity(0.5), radius: 10, x: 0, y: 0)

                    // Divider
                    Rectangle()
                        .fill(Color.surfaceBorder)
                        .frame(width: 60, height: 1)

                    // Sleep hours
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purpleGlow)
                        Text(sleepHoursText)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purpleGlow, .purpleGlowLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .shadow(color: .purpleGlow.opacity(0.5), radius: 10, x: 0, y: 0)
                }
            }
        }
    }

    // MARK: - Controls Column (Right Column)

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            // Title
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("When are you")
                    .font(Typography.headlineLarge)
                    .foregroundColor(.textPrimary)

                Text("awake?")
                    .font(Typography.headlineLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.goldenGlow, .goldenGlowLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            Spacer()
                .frame(height: Spacing.md)

            // Time pickers
            VStack(spacing: Spacing.md) {
                TimePickerRow(
                    icon: "sunrise.fill",
                    glowColor: .goldenGlow,
                    label: "Wake up",
                    time: $state.sleepSchedule.wakeTime
                )

                TimePickerRow(
                    icon: "moon.fill",
                    glowColor: .purpleGlow,
                    label: "Go to sleep",
                    time: $state.sleepSchedule.sleepTime
                )
            }
            .frame(maxWidth: .infinity)

            Spacer()
                .frame(height: Spacing.lg)

            // Stat cards
            HStack(spacing: Spacing.md) {
                StatCard(
                    icon: "sun.max.fill",
                    iconColor: .goldenGlow,
                    title: "Daily",
                    value: awakeHoursText,
                    valueColor: .goldenGlow
                )

                StatCard(
                    icon: "calendar",
                    iconColor: .goldenGlow,
                    title: "Weekly",
                    value: "\(weeklyHoursText)h",
                    valueColor: .goldenGlow
                )
            }
            .frame(maxWidth: .infinity)

            Spacer()
                .frame(height: Spacing.xl)

            // Continue button
            PrimaryButton(title: "Continue", action: onContinue)
                .frame(maxWidth: .infinity)
        }
        .frame(width: 420)
    }
}

// MARK: - Time Picker Row (macOS Enhanced)

struct TimePickerRow: View {
    let icon: String
    let glowColor: Color
    let label: String
    @Binding var time: Date

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

            // Custom digit-based time input
            TimeDigitInput(time: $time, accentColor: glowColor)
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

// MARK: - Custom Digit Time Input

struct TimeDigitInput: View {
    @Binding var time: Date
    let accentColor: Color

    @State private var inputBuffer: String = ""  // Raw input capture
    @State private var typedDigits: String = ""  // Actual digits user typed
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

    // Format display with left-shift: 00:00 -> 00:01 -> 00:14 -> 01:43 -> 14:30
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
        }
        .onChange(of: isFocused) {
            if isFocused {
                // Entering edit mode - always clear to 00:00
                typedDigits = ""
                inputBuffer = ""
                isEditing = true
            } else {
                // Exiting - commit if we have 4 digits
                if typedDigits.count == 4 {
                    commitTimeFromDigits(typedDigits)
                }
                isEditing = false
                typedDigits = ""
                inputBuffer = ""
            }
        }
        .onTapGesture {
            // Ensure tap always resets and focuses
            if isFocused {
                // Already focused, just reset
                typedDigits = ""
                inputBuffer = ""
            } else {
                isFocused = true
            }
        }
    }

    private func handleInput() {
        // Extract only new digits from the input buffer
        let newDigits = inputBuffer.filter { $0.isNumber }

        if !newDigits.isEmpty {
            // Append new digits to typedDigits (max 4)
            typedDigits = String((typedDigits + newDigits).suffix(4))

            // Clear input buffer for next input
            inputBuffer = ""

            // Auto-commit when 4 digits typed
            if typedDigits.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.commitTimeFromDigits(self.typedDigits)
                    self.isFocused = false
                }
            }
        } else if inputBuffer.isEmpty {
            // Buffer was cleared, nothing to do
        } else {
            // Non-digit input, just clear it
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
            // 00:XX -> 12:XX AM (midnight)
            hour24 = 0
        } else if hour >= 1 && hour <= 11 {
            // 01-11 -> AM
            hour24 = hour
        } else if hour == 12 {
            // 12:XX -> 12:XX PM (noon)
            hour24 = 12
        } else if hour >= 13 && hour <= 23 {
            // 13-23 -> PM (already 24-hour format)
            hour24 = hour
        } else {
            // 24+ invalid, cap at 11 PM
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

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor.opacity(0.8))

                Text(title)
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [valueColor, valueColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: valueColor.opacity(0.3), radius: 6, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(Color.surfaceBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    ZStack {
        Color.backgroundPrimary.ignoresSafeArea()
        OnboardingSleepView(
            state: OnboardingState(),
            step: .sleep,
            onContinue: {},
            onBack: {}
        )
    }
    .frame(width: 900, height: 700)
}
