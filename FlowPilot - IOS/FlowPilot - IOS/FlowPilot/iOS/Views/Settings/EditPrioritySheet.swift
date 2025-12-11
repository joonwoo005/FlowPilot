import SwiftUI

struct EditPrioritySheet: View {
    let priority: Priority
    @ObservedObject var state: OnboardingState
    let onSave: (Priority) -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedColorIndex: Int = 0
    @State private var hoursPerWeek: Double = 10
    @State private var showDeleteConfirmation = false
    @State private var isEditingHours = false
    @State private var hoursText = ""
    @State private var hoursError: String? = nil
    @FocusState private var isNameFocused: Bool
    @FocusState private var isHoursFocused: Bool

    private var remainingHours: Double {
        let otherPrioritiesHours = state.priorities
            .filter { $0.id != priority.id }
            .reduce(0) { $0 + $1.hoursPerWeek }
        return state.sleepSchedule.availableHoursPerWeek - otherPrioritiesHours
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName != priority.name ||
               Priority.availableColors[selectedColorIndex] != priority.color ||
               hoursPerWeek != priority.hoursPerWeek
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Preview Card
                        HStack(spacing: Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Priority.availableColors[selectedColorIndex].opacity(0.3))
                                    .frame(width: 48, height: 48)
                                    .blur(radius: 8)

                                Circle()
                                    .fill(Priority.availableColors[selectedColorIndex])
                                    .frame(width: 24, height: 24)
                            }
                            .shadow(color: Priority.availableColors[selectedColorIndex].opacity(0.5), radius: 8, x: 0, y: 0)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name.isEmpty ? "Priority Name" : name)
                                    .font(Typography.bodyLarge)
                                    .fontWeight(.semibold)
                                    .foregroundColor(name.isEmpty ? .textMuted : .textPrimary)

                                Text("\(Int(hoursPerWeek)) hours per week")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(Spacing.base)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .fill(Color.surfacePrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .stroke(Priority.availableColors[selectedColorIndex].opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: Priority.availableColors[selectedColorIndex].opacity(0.15), radius: 12, x: 0, y: 4)

                        // Name Input
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Name")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            TextField("Priority name", text: $name)
                                .font(Typography.bodyLarge)
                                .foregroundColor(.textPrimary)
                                .padding(Spacing.base)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .stroke(isNameFocused ? Color.accentPrimary : Color.surfaceBorder, lineWidth: isNameFocused ? 2 : 1)
                                        )
                                )
                                .focused($isNameFocused)
                        }

                        // Color Selection
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Color")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            SettingsPriorityColorPicker(
                                selectedIndex: $selectedColorIndex,
                                usedColors: state.priorities.map { $0.color },
                                currentColor: priority.color
                            )
                        }

                        // Hours Input
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            HStack {
                                Text("Hours per week")
                                    .font(Typography.labelMedium)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                Text("\(Int(remainingHours))h available")
                                    .font(Typography.labelSmall)
                                    .foregroundColor(.textMuted)
                            }

                            if isEditingHours {
                                HStack {
                                    TextField("", text: $hoursText)
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundColor(hoursError != nil ? .accentError : Priority.availableColors[selectedColorIndex])
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.center)
                                        .focused($isHoursFocused)
                                        .onChange(of: hoursText) { _, newValue in
                                            validateHoursInput(newValue)
                                        }

                                    Text("h")
                                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                                .stroke(hoursError != nil ? Color.accentError : Priority.availableColors[selectedColorIndex], lineWidth: 2)
                                        )
                                )

                                // Error message
                                if let error = hoursError {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.system(size: 12))
                                        Text(error)
                                            .font(Typography.labelSmall)
                                    }
                                    .foregroundColor(.accentError)
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Text("\(Int(hoursPerWeek))")
                                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                                        .foregroundColor(Priority.availableColors[selectedColorIndex])
                                    Text("h")
                                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(Spacing.lg)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                                .stroke(Color.surfaceBorder, lineWidth: 1)
                                        )
                                )
                                .onTapGesture {
                                    Haptics.impact(.light)
                                    hoursText = "\(Int(hoursPerWeek))"
                                    isEditingHours = true
                                    isHoursFocused = true
                                }
                            }
                        }

                        Spacer(minLength: Spacing.xxl)

                        // Delete Button
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                            Text("Delete Priority")
                                .font(Typography.bodyMedium)
                        }
                        .foregroundColor(.accentError)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.base)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.lg)
                                .fill(Color.accentError.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                                        .stroke(Color.accentError.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .onTapGesture {
                            Haptics.impact(.medium)
                            showDeleteConfirmation = true
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationTitle("Edit Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .onTapGesture {
                            Haptics.impact(.light)
                            dismiss()
                        }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Text("Save")
                        .font(Typography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(isValid && hasChanges ? .accentPrimary : .textMuted)
                        .onTapGesture {
                            guard isValid && hasChanges else { return }
                            Haptics.impact(.medium)
                            let updatedPriority = Priority(
                                id: priority.id,
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                color: Priority.availableColors[selectedColorIndex],
                                hoursPerWeek: hoursPerWeek
                            )
                            onSave(updatedPriority)
                        }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Text("Done")
                            .font(Typography.labelLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.accentPrimary)
                            .onTapGesture {
                                if isHoursFocused {
                                    commitHoursEdit()
                                }
                                isNameFocused = false
                                isHoursFocused = false
                            }
                    }
                }
            }
            .onAppear {
                name = priority.name
                hoursPerWeek = priority.hoursPerWeek
                if let colorIndex = Priority.availableColors.firstIndex(of: priority.color) {
                    selectedColorIndex = colorIndex
                }
            }
            .confirmationDialog("Delete Priority", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(priority.name)\"? This cannot be undone.")
            }
        }
    }

    private func validateHoursInput(_ input: String) {
        guard let value = Double(input) else {
            hoursError = input.isEmpty ? nil : "Enter a valid number"
            return
        }

        if value < 1 {
            hoursError = "Minimum 1 hour required"
        } else if value > remainingHours {
            hoursError = "Exceeds available hours (\(Int(remainingHours))h max)"
        } else {
            hoursError = nil
        }
    }

    private func commitHoursEdit() {
        if let value = Double(hoursText) {
            if value < 1 {
                hoursPerWeek = 1
            } else if value > remainingHours {
                hoursPerWeek = remainingHours
            } else {
                hoursPerWeek = value
            }
        }
        hoursError = nil
        isEditingHours = false
        isHoursFocused = false
    }
}

#Preview {
    EditPrioritySheet(
        priority: Priority(id: UUID(), name: "Work", color: .priorityBlue, hoursPerWeek: 40),
        state: OnboardingState(),
        onSave: { _ in },
        onDelete: {}
    )
}
