import React, { useEffect, useState, useRef } from "react";
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  TextInput,
  Animated,
} from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { colors, typography, spacing, borderRadius } from "@/theme";
import { Task } from "@/types";
import { format } from "date-fns";

interface TaskRowProps {
  task: Task;
  onToggleComplete: (task: Task) => void;
  onUpdateTitle?: (taskId: string, newTitle: string) => void;
  onPress?: (task: Task) => void;
  onLongPress?: (task: Task) => void;
  isRecentlyCompleted?: boolean;
}

export function TaskRow({
  task,
  onToggleComplete,
  onUpdateTitle,
  onPress,
  onLongPress,
  isRecentlyCompleted = false,
}: TaskRowProps) {
  const scaleAnim = useRef(new Animated.Value(1)).current;
  const checkScaleAnim = useRef(new Animated.Value(task.isCompleted || isRecentlyCompleted ? 1 : 0)).current;
  const strikeAnim = useRef(new Animated.Value(task.isCompleted || isRecentlyCompleted ? 1 : 0)).current;
  const opacityAnim = useRef(new Animated.Value(task.isCompleted || isRecentlyCompleted ? 0.6 : 1)).current;

  // Inline editing state
  const [isEditing, setIsEditing] = useState(false);
  const [editedTitle, setEditedTitle] = useState(task.title);
  const inputRef = useRef<TextInput>(null);

  // Sync editedTitle when task.title changes externally
  useEffect(() => {
    if (!isEditing) {
      setEditedTitle(task.title);
    }
  }, [task.title, isEditing]);

  const handleTitlePress = () => {
    if (task.isCompleted || isRecentlyCompleted) return; // Don't allow editing completed tasks
    setIsEditing(true);
    setEditedTitle(task.title);
  };

  const handleSave = () => {
    const trimmed = editedTitle.trim();
    if (trimmed && trimmed !== task.title && onUpdateTitle) {
      onUpdateTitle(task.id, trimmed);
    } else if (!trimmed) {
      // Revert if empty
      setEditedTitle(task.title);
    }
    setIsEditing(false);
  };

  // Handle completion animation
  useEffect(() => {
    if (isRecentlyCompleted || task.isCompleted) {
      // Animate checkbox pop
      Animated.sequence([
        Animated.spring(checkScaleAnim, {
          toValue: 1.3,
          friction: 5,
          tension: 400,
          useNativeDriver: true,
        }),
        Animated.spring(checkScaleAnim, {
          toValue: 1,
          friction: 5,
          tension: 300,
          useNativeDriver: true,
        }),
      ]).start();

      // Animate strikethrough
      Animated.timing(strikeAnim, {
        toValue: 1,
        duration: 300,
        useNativeDriver: false,
      }).start();

      // Dim the row
      Animated.timing(opacityAnim, {
        toValue: 0.6,
        duration: 300,
        delay: 200,
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(checkScaleAnim, {
        toValue: 0,
        duration: 150,
        useNativeDriver: true,
      }).start();

      Animated.timing(strikeAnim, {
        toValue: 0,
        duration: 200,
        useNativeDriver: false,
      }).start();

      Animated.timing(opacityAnim, {
        toValue: 1,
        duration: 200,
        useNativeDriver: true,
      }).start();
    }
  }, [isRecentlyCompleted, task.isCompleted]);

  const handleToggle = () => {
    // Scale animation on tap
    Animated.sequence([
      Animated.spring(scaleAnim, {
        toValue: 0.95,
        friction: 8,
        tension: 400,
        useNativeDriver: true,
      }),
      Animated.spring(scaleAnim, {
        toValue: 1,
        friction: 5,
        tension: 300,
        useNativeDriver: true,
      }),
    ]).start();

    onToggleComplete(task);
  };

  const isCompleted = task.isCompleted || isRecentlyCompleted;
  const priorityColor = task.priorityColor || colors.text.muted;

  // Format schedule info
  const getScheduleText = () => {
    if (!task.timeBlockDate || !task.timeBlockStartTime) return null;
    const date = task.timeBlockDate.toDate();
    const dateStr = format(date, "MMM d");
    return `${dateStr} at ${task.timeBlockStartTime}`;
  };

  const scheduleText = getScheduleText();

  const strikeWidth = strikeAnim.interpolate({
    inputRange: [0, 1],
    outputRange: ["0%", "100%"],
  });

  return (
    <Animated.View
      style={[
        styles.container,
        {
          transform: [{ scale: scaleAnim }],
          opacity: opacityAnim,
        },
      ]}
    >
      <Pressable
        style={styles.pressableContent}
        onPress={() => onPress?.(task)}
        onLongPress={() => onLongPress?.(task)}
      >
        {/* Priority indicator line */}
        <View style={[styles.priorityLine, { backgroundColor: priorityColor }]} />

        {/* Checkbox */}
        <Pressable onPress={handleToggle} hitSlop={12} style={styles.checkboxContainer}>
          <View
            style={[
              styles.checkbox,
              isCompleted && styles.checkboxCompleted,
              { borderColor: priorityColor },
              isCompleted && { backgroundColor: priorityColor },
            ]}
          >
            <Animated.View style={{ transform: [{ scale: checkScaleAnim }] }}>
              {isCompleted && (
                <Ionicons name="checkmark" size={14} color={colors.text.primary} />
              )}
            </Animated.View>
          </View>
        </Pressable>

        {/* Content */}
        <View style={styles.content}>
          <View style={styles.titleRow}>
            {isEditing ? (
              <TextInput
                ref={inputRef}
                value={editedTitle}
                onChangeText={setEditedTitle}
                onSubmitEditing={handleSave}
                onBlur={handleSave}
                autoFocus
                selectTextOnFocus
                style={styles.titleInput}
                returnKeyType="done"
                placeholder="Task title"
                placeholderTextColor={colors.text.muted}
                blurOnSubmit
              />
            ) : (
              <Pressable onPress={handleTitlePress} style={styles.titlePressable}>
                <Text
                  style={[styles.title, isCompleted && styles.titleCompleted]}
                  numberOfLines={2}
                >
                  {task.title}
                </Text>
                <Animated.View style={[styles.strikethrough, { width: strikeWidth }]} />
              </Pressable>
            )}
          </View>

          {/* Meta info row */}
          <View style={styles.metaRow}>
            {task.priorityName && (
              <View style={[styles.priorityBadge, { backgroundColor: priorityColor + "20" }]}>
                <View style={[styles.priorityDot, { backgroundColor: priorityColor }]} />
                <Text style={[styles.priorityText, { color: priorityColor }]}>
                  {task.priorityName}
                </Text>
              </View>
            )}

            {scheduleText && (
              <View style={styles.scheduleContainer}>
                <Ionicons name="time-outline" size={12} color={colors.text.muted} />
                <Text style={styles.scheduleText}>{scheduleText}</Text>
              </View>
            )}
          </View>
        </View>

        {/* Chevron */}
        {onPress && (
          <Ionicons
            name="chevron-forward"
            size={16}
            color={colors.text.muted}
            style={styles.chevron}
          />
        )}
      </Pressable>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: colors.surface.primary,
    borderWidth: 1,
    borderColor: colors.surface.border,
    borderRadius: borderRadius.lg,
    marginHorizontal: spacing.base,
    marginVertical: spacing.xs,
    overflow: "hidden",
  },
  pressableContent: {
    flexDirection: "row",
    alignItems: "center",
    padding: spacing.md,
  },
  priorityLine: {
    position: "absolute",
    left: 0,
    top: 0,
    bottom: 0,
    width: 3,
    borderTopLeftRadius: borderRadius.lg,
    borderBottomLeftRadius: borderRadius.lg,
  },
  checkboxContainer: {
    marginRight: spacing.md,
    marginLeft: spacing.xs,
  },
  checkbox: {
    width: 22,
    height: 22,
    borderRadius: borderRadius.sm,
    borderWidth: 2,
    alignItems: "center",
    justifyContent: "center",
  },
  checkboxCompleted: {
    borderWidth: 0,
  },
  content: {
    flex: 1,
    gap: spacing.xs,
  },
  titleRow: {
    position: "relative",
    flex: 1,
  },
  titlePressable: {
    position: "relative",
  },
  title: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
    lineHeight: 20,
  },
  titleCompleted: {
    color: colors.text.muted,
  },
  titleInput: {
    fontSize: typography.fontSize.base,
    fontWeight: typography.fontWeight.medium,
    color: colors.text.primary,
    lineHeight: 20,
    borderWidth: 1.5,
    borderColor: colors.primary.blue,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    backgroundColor: colors.surface.elevated,
    marginVertical: -spacing.xs,
    marginHorizontal: -spacing.sm,
  },
  strikethrough: {
    position: "absolute",
    left: 0,
    top: "50%",
    height: 1.5,
    backgroundColor: colors.text.muted,
    borderRadius: 1,
  },
  metaRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    flexWrap: "wrap",
  },
  priorityBadge: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: spacing.sm,
    paddingVertical: 3,
    borderRadius: borderRadius.sm,
    gap: 4,
  },
  priorityDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  priorityText: {
    fontSize: typography.fontSize.xs,
    fontWeight: typography.fontWeight.medium,
  },
  scheduleContainer: {
    flexDirection: "row",
    alignItems: "center",
    gap: 4,
  },
  scheduleText: {
    fontSize: typography.fontSize.xs,
    color: colors.text.muted,
  },
  chevron: {
    marginLeft: spacing.sm,
  },
});
