import React, { useState, useCallback, useRef } from "react";
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
  InputAccessoryView,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { GradientBackground, GlassCard } from "@/components/ui";
import { useTasks, usePriorities } from "@/hooks";
import { colors, typography, spacing, borderRadius } from "@/theme";
import { Priority } from "@/types";

const INPUT_ACCESSORY_ID = "add-task-input";

export default function AddTaskScreen() {
  const router = useRouter();
  const { addTask } = useTasks();
  const { priorities } = usePriorities();

  const [title, setTitle] = useState("");
  const [selectedPriority, setSelectedPriority] = useState<Priority | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const inputRef = useRef<TextInput>(null);

  const handleClose = useCallback(() => {
    router.back();
  }, [router]);

  const handleSubmit = useCallback(async () => {
    const trimmedTitle = title.trim();
    if (!trimmedTitle || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await addTask({
        title: trimmedTitle,
        priorityId: selectedPriority?.id,
        priorityName: selectedPriority?.name,
        priorityColor: selectedPriority?.color,
      });
      router.back();
    } catch (error) {
      console.error("Failed to create task:", error);
      setIsSubmitting(false);
    }
  }, [title, selectedPriority, addTask, router, isSubmitting]);

  const handlePrioritySelect = useCallback((priority: Priority) => {
    setSelectedPriority((prev) => (prev?.id === priority.id ? null : priority));
  }, []);

  const isValid = title.trim().length > 0;

  return (
    <GradientBackground>
      <KeyboardAvoidingView
        style={styles.keyboardAvoid}
        behavior={Platform.OS === "ios" ? "padding" : "height"}
      >
        <SafeAreaView style={styles.container} edges={["top"]}>
          {/* Header */}
          <View style={styles.header}>
            <Pressable onPress={handleClose} style={styles.closeButton}>
              <Ionicons name="close" size={24} color={colors.text.secondary} />
            </Pressable>
            <Text style={styles.headerTitle}>New Task</Text>
            <Pressable
              onPress={handleSubmit}
              style={[styles.submitButton, !isValid && styles.submitButtonDisabled]}
              disabled={!isValid || isSubmitting}
            >
              <Text
                style={[
                  styles.submitButtonText,
                  !isValid && styles.submitButtonTextDisabled,
                ]}
              >
                {isSubmitting ? "Adding..." : "Add"}
              </Text>
            </Pressable>
          </View>

          <ScrollView
            style={styles.scrollView}
            contentContainerStyle={styles.scrollContent}
            keyboardShouldPersistTaps="handled"
          >
            {/* Title Input */}
            <GlassCard style={styles.inputCard}>
              <TextInput
                ref={inputRef}
                style={styles.titleInput}
                value={title}
                onChangeText={setTitle}
                placeholder="What needs to be done?"
                placeholderTextColor={colors.text.muted}
                multiline
                autoFocus
                returnKeyType="done"
                blurOnSubmit
                onSubmitEditing={handleSubmit}
                inputAccessoryViewID={INPUT_ACCESSORY_ID}
              />
            </GlassCard>

            {/* Priority Selection */}
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>PRIORITY (OPTIONAL)</Text>
              <View style={styles.priorityList}>
                {priorities.map((priority) => {
                  const isSelected = selectedPriority?.id === priority.id;
                  return (
                    <Pressable
                      key={priority.id}
                      onPress={() => handlePrioritySelect(priority)}
                      style={[
                        styles.priorityItem,
                        isSelected && styles.priorityItemSelected,
                        isSelected && { borderColor: priority.color },
                      ]}
                    >
                      <View
                        style={[
                          styles.priorityDot,
                          { backgroundColor: priority.color },
                        ]}
                      />
                      <Text
                        style={[
                          styles.priorityText,
                          isSelected && { color: colors.text.primary },
                        ]}
                      >
                        {priority.name}
                      </Text>
                      {isSelected && (
                        <Ionicons
                          name="checkmark"
                          size={16}
                          color={priority.color}
                          style={styles.priorityCheck}
                        />
                      )}
                    </Pressable>
                  );
                })}
              </View>
              <Text style={styles.helperText}>
                Tasks can be linked to time blocks later
              </Text>
            </View>
          </ScrollView>

          {/* Input Accessory View for Done button */}
          <InputAccessoryView nativeID={INPUT_ACCESSORY_ID}>
            <View style={styles.accessoryView}>
              <Pressable onPress={() => inputRef.current?.blur()} style={styles.doneButton}>
                <Text style={styles.doneButtonText}>Done</Text>
              </Pressable>
            </View>
          </InputAccessoryView>
        </SafeAreaView>
      </KeyboardAvoidingView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  keyboardAvoid: {
    flex: 1,
  },
  container: {
    flex: 1,
  },
  header: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: spacing.base,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: colors.surface.border,
  },
  closeButton: {
    width: 40,
    height: 40,
    alignItems: "center",
    justifyContent: "center",
  },
  headerTitle: {
    fontSize: typography.fontSize.md,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  submitButton: {
    backgroundColor: colors.primary.blue,
    paddingHorizontal: spacing.base,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
  },
  submitButtonDisabled: {
    backgroundColor: colors.surface.secondary,
  },
  submitButtonText: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.primary,
  },
  submitButtonTextDisabled: {
    color: colors.text.muted,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    padding: spacing.xl,
    gap: spacing.xl,
  },
  inputCard: {
    padding: spacing.base,
  },
  titleInput: {
    fontSize: typography.fontSize.lg,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
    minHeight: 60,
    textAlignVertical: "top",
  },
  section: {
    gap: spacing.md,
  },
  sectionTitle: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.semibold,
    color: colors.text.muted,
    letterSpacing: 1,
    marginLeft: spacing.xs,
  },
  priorityList: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
  },
  priorityItem: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: colors.surface.primary,
    borderWidth: 1,
    borderColor: colors.surface.border,
    borderRadius: borderRadius.lg,
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    gap: spacing.sm,
  },
  priorityItemSelected: {
    backgroundColor: colors.surface.elevated,
    borderWidth: 2,
  },
  priorityDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  priorityText: {
    fontSize: typography.fontSize.base,
    color: colors.text.secondary,
    fontWeight: typography.fontWeight.medium,
  },
  priorityCheck: {
    marginLeft: spacing.xs,
  },
  helperText: {
    fontSize: typography.fontSize.sm,
    color: colors.text.muted,
    marginLeft: spacing.xs,
  },
  accessoryView: {
    backgroundColor: colors.surface.elevated,
    borderTopWidth: 1,
    borderTopColor: colors.surface.border,
    paddingHorizontal: spacing.base,
    paddingVertical: spacing.sm,
    flexDirection: "row",
    justifyContent: "flex-end",
  },
  doneButton: {
    paddingHorizontal: spacing.base,
    paddingVertical: spacing.xs,
  },
  doneButtonText: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.semibold,
    color: colors.primary.blue,
  },
});
