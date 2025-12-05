import SwiftUI

struct OnboardingPrioritiesView: View {
    @ObservedObject var state: OnboardingState
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var hasAppeared = false
    @State private var showAddSheet = false
    @State private var newPriorityName = ""
    @State private var selectedColor: Color = .priorityBlue
    @FocusState private var isAddingPriority: Bool

    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: Spacing.xl) {
                    // Back button and step indicator
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.surfaceBorder, lineWidth: 1)
                                        )
                                )
                        }

                        Spacer()

                        StepIndicator(step: 2, title: "Priorities")

                        Spacer()

                        // Invisible spacer for balance
                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)

                    // Progress
                    OnboardingProgressIndicator(currentStep: 1, totalSteps: 4)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xl)

                // Title section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("What matters most")
                        .font(Typography.displayMedium)
                        .foregroundColor(.textPrimary)

                    Text("to you?")
                        .font(Typography.displayMedium)
                        .foregroundColor(.accentPrimary)

                    Text("Add the priorities you want to make time for each week")
                        .font(Typography.bodyLarge)
                        .foregroundColor(.textSecondary)
                        .padding(.top, Spacing.sm)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.xxl)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)

                // Priority list
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        ForEach(Array(state.priorities.enumerated()), id: \.element.id) { index, priority in
                            PriorityRow(
                                priority: priority,
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        state.priorities.removeAll { $0.id == priority.id }
                                    }
                                },
                                onUpdate: { updated in
                                    if let idx = state.priorities.firstIndex(where: { $0.id == updated.id }) {
                                        state.priorities[idx] = updated
                                    }
                                }
                            )
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05), value: hasAppeared)
                        }

                        // Add priority button
                        AddPriorityButton {
                            showAddSheet = true
                        }
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                    .padding(.bottom, 120)
                }

                Spacer(minLength: 0)

                // Bottom button
                VStack(spacing: Spacing.base) {
                    PrimaryButton(
                        title: "Continue",
                        action: onContinue,
                        isEnabled: !state.priorities.isEmpty
                    )
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
                .background(
                    LinearGradient(
                        colors: [
                            Color.backgroundPrimary.opacity(0),
                            Color.backgroundPrimary
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .offset(y: -60)
                )
                .opacity(hasAppeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddPrioritySheet(
                name: $newPriorityName,
                selectedColor: $selectedColor,
                onAdd: {
                    let trimmedName = newPriorityName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedName.isEmpty {
                        let newPriority = Priority(
                            id: UUID(),
                            name: trimmedName,
                            color: selectedColor,
                            hoursPerWeek: 5
                        )
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            state.priorities.append(newPriority)
                        }
                        newPriorityName = ""
                        selectedColor = .priorityBlue
                        showAddSheet = false
                    }
                },
                onCancel: {
                    newPriorityName = ""
                    showAddSheet = false
                }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Priority Row
struct PriorityRow: View {
    let priority: Priority
    let onDelete: () -> Void
    let onUpdate: (Priority) -> Void

    @State private var isEditing = false
    @State private var editedName: String = ""

    var body: some View {
        HStack(spacing: Spacing.base) {
            // Color indicator
            Circle()
                .fill(priority.color)
                .frame(width: 12, height: 12)

            // Name
            if isEditing {
                TextField("Priority name", text: $editedName)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .onSubmit {
                        var updated = priority
                        updated.name = editedName
                        onUpdate(updated)
                        isEditing = false
                    }
            } else {
                Text(priority.name)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textPrimary)
                    .onTapGesture {
                        editedName = priority.name
                        isEditing = true
                    }
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.surfaceSecondary)
                    )
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.base)
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

// MARK: - Add Priority Button
struct AddPriorityButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentPrimary)

                Text("Add Priority")
                    .font(Typography.bodyLarge)
                    .foregroundColor(.accentPrimary)

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.base)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(Color.accentPrimary.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Color.accentPrimary.opacity(0.3), lineWidth: 1)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
            )
        }
    }
}

// MARK: - Add Priority Sheet
struct AddPrioritySheet: View {
    @Binding var name: String
    @Binding var selectedColor: Color
    let onAdd: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // Header
            HStack {
                Button("Cancel", action: onCancel)
                    .font(Typography.bodyLarge)
                    .foregroundColor(.textSecondary)

                Spacer()

                Text("New Priority")
                    .font(Typography.labelLarge)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button("Add", action: onAdd)
                    .font(Typography.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentPrimary)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, Spacing.lg)

            // Name input
            TextField("Priority name", text: $name)
                .font(Typography.headlineSmall)
                .foregroundColor(.textPrimary)
                .focused($isFocused)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.base)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .fill(Color.surfacePrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                .stroke(isFocused ? Color.accentPrimary : Color.surfaceBorder, lineWidth: 1)
                        )
                )

            // Color picker
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Color")
                    .font(Typography.labelMedium)
                    .foregroundColor(.textSecondary)

                HStack(spacing: Spacing.md) {
                    ForEach(Priority.availableColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                    .padding(2)
                            )
                            .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor)
                            .onTapGesture {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                selectedColor = color
                            }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .background(Color.backgroundSecondary)
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    OnboardingPrioritiesView(
        state: OnboardingState(),
        onContinue: {},
        onBack: {}
    )
}
