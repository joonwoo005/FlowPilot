import SwiftUI

// MARK: - Add Project Sheet
struct AddProjectSheet: View {
    @ObservedObject var projectStore: ProjectStore
    var editingProject: Project? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var projectName = ""
    @State private var selectedColor: Color = .priorityBlue
    @State private var selectedIcon: String = "folder.fill"
    @FocusState private var isNameFocused: Bool

    private var isEditing: Bool { editingProject != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Preview card
                        projectPreview

                        // Name input
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Project Name")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            TextField("Enter project name", text: $projectName)
                                .font(Typography.bodyLarge)
                                .foregroundColor(.textPrimary)
                                .padding(Spacing.base)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md)
                                        .fill(Color.surfacePrimary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.md)
                                                .stroke(Color.surfaceBorder, lineWidth: 1)
                                        )
                                )
                                .focused($isNameFocused)
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Color")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 6), spacing: Spacing.md) {
                                ForEach(Project.availableColors, id: \.self) { color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                                .padding(2)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(color.opacity(0.3), lineWidth: selectedColor == color ? 2 : 0)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.1 : 1)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedColor)
                                        .onTapGesture {
                                            Haptics.impact(.light)
                                            selectedColor = color
                                        }
                                }
                            }
                            .padding(Spacing.base)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .fill(Color.surfacePrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.md)
                                            .stroke(Color.surfaceBorder, lineWidth: 1)
                                    )
                            )
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Icon")
                                .font(Typography.labelMedium)
                                .foregroundColor(.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 4), spacing: Spacing.md) {
                                ForEach(Project.availableIcons, id: \.self) { icon in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .fill(selectedIcon == icon ? selectedColor.opacity(0.15) : Color.surfaceSecondary)
                                            .frame(width: 56, height: 56)

                                        Image(systemName: icon)
                                            .font(.system(size: 22))
                                            .foregroundColor(selectedIcon == icon ? selectedColor : .textMuted)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                                            .stroke(selectedIcon == icon ? selectedColor : Color.clear, lineWidth: 2)
                                    )
                                    .scaleEffect(selectedIcon == icon ? 1.05 : 1)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIcon)
                                    .onTapGesture {
                                        Haptics.impact(.light)
                                        selectedIcon = icon
                                    }
                                }
                            }
                            .padding(Spacing.base)
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
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
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
                    Text(isEditing ? "Save" : "Create")
                        .font(Typography.labelLarge)
                        .foregroundColor(projectName.isEmpty ? .textMuted : .accentPrimary)
                        .onTapGesture {
                            guard !projectName.isEmpty else { return }
                            Haptics.impact(.medium)
                            saveProject()
                        }
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            isNameFocused = false
                        }
                        .font(Typography.labelLarge)
                        .foregroundColor(.accentPrimary)
                    }
                }
            }
            .onAppear {
                if let project = editingProject {
                    projectName = project.name
                    selectedColor = project.color
                    selectedIcon = project.icon
                } else {
                    // Set next color for new projects
                    selectedColor = Project.nextColor(forIndex: projectStore.projects.count)
                    isNameFocused = true
                }
            }
        }
    }

    // MARK: - Project Preview
    private var projectPreview: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(selectedColor.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: selectedIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selectedColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(projectName.isEmpty ? "Project Name" : projectName)
                    .font(Typography.headlineSmall)
                    .foregroundColor(projectName.isEmpty ? .textMuted : .textPrimary)

                Text("0 tasks")
                    .font(Typography.labelSmall)
                    .foregroundColor(.textMuted)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(Color.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(selectedColor.opacity(0.3), lineWidth: 2)
                )
        )
    }

    private func saveProject() {
        if let existingProject = editingProject {
            var updatedProject = existingProject
            updatedProject.name = projectName
            updatedProject.color = selectedColor
            updatedProject.icon = selectedIcon
            projectStore.updateProject(updatedProject)
        } else {
            projectStore.addProject(name: projectName, color: selectedColor, icon: selectedIcon)
        }
        dismiss()
    }
}

#Preview("New Project") {
    AddProjectSheet(projectStore: ProjectStore())
}

#Preview("Edit Project") {
    AddProjectSheet(
        projectStore: ProjectStore(),
        editingProject: Project(name: "Side Project", color: .priorityOrange, icon: "briefcase.fill")
    )
}
