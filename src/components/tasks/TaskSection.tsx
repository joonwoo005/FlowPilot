import React, { useState, useCallback, useRef, useEffect } from "react";
import {
  View,
  StyleSheet,
  LayoutAnimation,
  Platform,
  UIManager,
  Animated,
} from "react-native";
import { SectionHeader } from "@/components/ui";
import { TaskRow } from "./TaskRow";
import { Task, TaskSection as TaskSectionType } from "@/types";
import { spacing } from "@/theme";
import { Ionicons } from "@expo/vector-icons";

// Enable LayoutAnimation for Android
if (Platform.OS === "android" && UIManager.setLayoutAnimationEnabledExperimental) {
  UIManager.setLayoutAnimationEnabledExperimental(true);
}

interface TaskSectionProps {
  section: TaskSectionType;
  recentlyCompletedIds: Set<string>;
  onToggleComplete: (task: Task) => void;
  onUpdateTitle?: (taskId: string, newTitle: string) => void;
  onTaskPress?: (task: Task) => void;
  onTaskLongPress?: (task: Task) => void;
  defaultExpanded?: boolean;
}

export function TaskSection({
  section,
  recentlyCompletedIds,
  onToggleComplete,
  onUpdateTitle,
  onTaskPress,
  onTaskLongPress,
  defaultExpanded = true,
}: TaskSectionProps) {
  const [isExpanded, setIsExpanded] = useState(defaultExpanded);
  const opacityAnim = useRef(new Animated.Value(defaultExpanded ? 1 : 0)).current;

  useEffect(() => {
    Animated.timing(opacityAnim, {
      toValue: isExpanded ? 1 : 0,
      duration: 250,
      useNativeDriver: true,
    }).start();
  }, [isExpanded]);

  const handleToggle = useCallback(() => {
    LayoutAnimation.configureNext(LayoutAnimation.Presets.easeInEaseOut);
    setIsExpanded((prev) => !prev);
  }, []);

  return (
    <View style={styles.container}>
      <SectionHeader
        icon={section.icon as keyof typeof Ionicons.glyphMap}
        title={section.title}
        subtitle={section.subtitle}
        count={section.tasks.length}
        isExpanded={isExpanded}
        onToggle={handleToggle}
        iconColor={section.iconColor}
      />

      {isExpanded && (
        <Animated.View style={[styles.taskList, { opacity: opacityAnim }]}>
          {section.tasks.map((task) => (
            <TaskRow
              key={task.id}
              task={task}
              onToggleComplete={onToggleComplete}
              onUpdateTitle={onUpdateTitle}
              onPress={onTaskPress}
              onLongPress={onTaskLongPress}
              isRecentlyCompleted={recentlyCompletedIds.has(task.id)}
            />
          ))}
        </Animated.View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginBottom: spacing.md,
  },
  taskList: {
    paddingBottom: spacing.xs,
  },
});
