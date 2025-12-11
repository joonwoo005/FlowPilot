import SwiftUI

/// Day selector component for recurring time blocks
/// Displays M T W T F S S (Monday first) as circular buttons
struct DaySelector: View {
    @Binding var selectedDays: Set<Int>

    // Days ordered Monday to Sunday with their weekday numbers
    // Swift Calendar: 1=Sunday, 2=Monday, ..., 7=Saturday
    private let days: [(label: String, weekday: Int)] = [
        ("M", 2),  // Monday
        ("T", 3),  // Tuesday
        ("W", 4),  // Wednesday
        ("T", 5),  // Thursday
        ("F", 6),  // Friday
        ("S", 7),  // Saturday
        ("S", 1)   // Sunday
    ]

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(days, id: \.weekday) { day in
                DayButton(
                    label: day.label,
                    isSelected: selectedDays.contains(day.weekday),
                    onTap: {
                        Haptics.impact(.light)
                        if selectedDays.contains(day.weekday) {
                            selectedDays.remove(day.weekday)
                        } else {
                            selectedDays.insert(day.weekday)
                        }
                    }
                )
            }
        }
    }
}

private struct DayButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    private let buttonSize: CGFloat = 32
    private let fontSize: CGFloat = 13

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentPrimary : Color.clear)

            Circle()
                .strokeBorder(isSelected ? Color.accentPrimary : Color.textMuted.opacity(0.4), lineWidth: 1.5)

            Text(label)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .textMuted)
        }
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(Circle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        DaySelector(selectedDays: .constant([]))
        DaySelector(selectedDays: .constant([2, 4, 6])) // Mon, Wed, Fri
        DaySelector(selectedDays: .constant([2, 3, 4, 5, 6])) // Weekdays
    }
    .padding()
    .background(Color.backgroundPrimary)
}
