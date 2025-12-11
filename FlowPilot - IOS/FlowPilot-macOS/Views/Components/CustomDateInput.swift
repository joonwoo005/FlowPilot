import SwiftUI

// MARK: - Custom Date Input (macOS)
/// An inline date display that opens a calendar picker popover

struct CustomDateInput: View {
    @Binding var date: Date?
    var placeholder: String = "Select date"
    var accentColor: Color = .accentPrimary
    var allowClear: Bool = true
    var minDate: Date? = nil
    var maxDate: Date? = nil
    var onDateSelected: ((Date?) -> Void)? = nil

    @State private var showCalendar: Bool = false
    @State private var isHovered: Bool = false
    @State private var tempDate: Date = Date()

    private var formattedDate: String {
        guard let date = date else { return placeholder }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var hasDate: Bool {
        date != nil
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Calendar icon
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(hasDate ? accentColor : .textMuted)

            // Date text
            Text(formattedDate)
                .font(Typography.bodyMedium)
                .foregroundColor(hasDate ? .textPrimary : .textMuted)

            Spacer()

            // Clear button
            if allowClear && hasDate {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.textMuted)
                    .onTapGesture {
                        Haptics.impact(.light)
                        date = nil
                        onDateSelected?(nil)
                    }
            }
        }
        .padding(.horizontal, Spacing.base)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(showCalendar ? accentColor : (isHovered ? Color.surfaceBorder.opacity(1.5) : Color.surfaceBorder), lineWidth: showCalendar ? 2 : 1)
                )
        )
        .shadow(color: showCalendar ? accentColor.opacity(0.2) : Color.clear, radius: 8, x: 0, y: 0)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            Haptics.impact(.light)
            tempDate = date ?? Date()
            showCalendar = true
        }
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            calendarPopover
        }
        .animation(.easeOut(duration: 0.2), value: showCalendar)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Calendar Popover

    private var calendarPopover: some View {
        VStack(spacing: Spacing.md) {
            CustomCalendarPicker(
                selectedDate: $tempDate,
                accentColor: accentColor,
                minDate: minDate,
                maxDate: maxDate,
                onDateSelected: { selectedDate in
                    date = selectedDate
                    onDateSelected?(selectedDate)
                    showCalendar = false
                }
            )

            // Quick actions
            HStack(spacing: Spacing.md) {
                // Today button
                Text("Today")
                    .font(Typography.labelMedium)
                    .foregroundColor(.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.accentPrimary.opacity(0.15))
                    )
                    .onTapGesture {
                        Haptics.impact(.light)
                        date = Date()
                        onDateSelected?(Date())
                        showCalendar = false
                    }

                // Tomorrow button
                Text("Tomorrow")
                    .font(Typography.labelMedium)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(Color.surfaceSecondary)
                    )
                    .onTapGesture {
                        Haptics.impact(.light)
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                        date = tomorrow
                        onDateSelected?(tomorrow)
                        showCalendar = false
                    }
            }
        }
        .padding(Spacing.md)
        .background(Color.backgroundSecondary)
        .frame(width: 300)
    }
}

// MARK: - Date Input Row (for forms)

struct CustomDateRow: View {
    let icon: String
    let glowColor: Color
    let label: String
    @Binding var date: Date?
    var placeholder: String = "Select date"
    var allowClear: Bool = true
    var onDateSelected: ((Date?) -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .blur(radius: 8)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(glowColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .fill(Color.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(glowColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: glowColor.opacity(0.3), radius: 6, x: 0, y: 0)
            }

            Text(label)
                .font(Typography.bodyLarge)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            Spacer()

            CustomDateInput(
                date: $date,
                placeholder: placeholder,
                accentColor: glowColor,
                allowClear: allowClear,
                onDateSelected: onDateSelected
            )
            .frame(maxWidth: 180)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
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
            CustomDateInput(
                date: .constant(Date()),
                accentColor: .accentPrimary
            )
            .frame(width: 200)

            CustomDateInput(
                date: .constant(nil),
                placeholder: "No date selected",
                accentColor: .accentPrimary
            )
            .frame(width: 200)

            CustomDateRow(
                icon: "calendar.badge.clock",
                glowColor: .accentPrimary,
                label: "Due Date",
                date: .constant(Date())
            )
            .frame(width: 400)
        }
        .padding(Spacing.xl)
    }
}
