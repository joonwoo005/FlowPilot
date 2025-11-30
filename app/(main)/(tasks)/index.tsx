import React, { useCallback } from "react";
import { View, Text, StyleSheet, ScrollView, RefreshControl, Pressable } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { GradientBackground, EmptyState, Badge } from "@/components/ui";
import { TaskSection } from "@/components/tasks";
import { useTasks } from "@/hooks";
import { useTaskStore } from "@/stores";
import { colors, typography, spacing, borderRadius } from "@/theme";
import { Task } from "@/types";

export default function TasksScreen() {
  const router = useRouter();
  const {
    taskSections,
    isLoading,
    totalTasks,
    completedCount,
    activeCount,
    toggleComplete,
    updateTaskTitle,
  } = useTasks();
  const { recentlyCompletedIds } = useTaskStore();

  const handleAddTask = useCallback(() => {
    router.push("/(main)/(tasks)/add-task");
  }, [router]);

  const handleTaskPress = useCallback((task: Task) => {
    // Future: open task detail/edit modal
  }, []);

  const handleTaskLongPress = useCallback((task: Task) => {
    // Future: show action sheet (delete, link to block, etc.)
  }, []);

  const isEmpty = taskSections.length === 0 && !isLoading;

  return (
    <GradientBackground>
      <SafeAreaView style={styles.container} edges={["top"]}>
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.headerTop}>
            <View>
              <Text style={styles.title}>Tasks</Text>
              <Text style={styles.subtitle}>
                {activeCount} active, {completedCount} completed
              </Text>
            </View>
            <Pressable onPress={handleAddTask} style={styles.addButton}>
              <Ionicons name="add" size={24} color={colors.text.primary} />
            </Pressable>
          </View>

          {/* Stats row */}
          {totalTasks > 0 && (
            <View style={styles.statsRow}>
              <View style={styles.statItem}>
                <View style={[styles.statDot, { backgroundColor: colors.status.error }]} />
                <Text style={styles.statLabel}>Overdue</Text>
                <Badge count={taskSections.find(s => s.type === "overdue")?.tasks.length || 0} variant="error" size="sm" />
              </View>
              <View style={styles.statItem}>
                <View style={[styles.statDot, { backgroundColor: colors.primary.blue }]} />
                <Text style={styles.statLabel}>Scheduled</Text>
                <Badge count={taskSections.find(s => s.type === "scheduled")?.tasks.length || 0} variant="primary" size="sm" />
              </View>
              <View style={styles.statItem}>
                <View style={[styles.statDot, { backgroundColor: colors.status.warning }]} />
                <Text style={styles.statLabel}>Inbox</Text>
                <Badge count={taskSections.find(s => s.type === "unscheduled")?.tasks.length || 0} variant="warning" size="sm" />
              </View>
            </View>
          )}
        </View>

        {/* Task List */}
        <ScrollView
          style={styles.scrollView}
          contentContainerStyle={styles.scrollContent}
          showsVerticalScrollIndicator={false}
          refreshControl={
            <RefreshControl
              refreshing={isLoading}
              tintColor={colors.text.secondary}
            />
          }
        >
          {isEmpty ? (
            <EmptyState
              icon="checkbox-outline"
              title="No tasks yet"
              subtitle="Tap the + button to create your first task"
            />
          ) : (
            taskSections.map((section) => (
              <TaskSection
                key={section.type}
                section={section}
                recentlyCompletedIds={recentlyCompletedIds}
                onToggleComplete={toggleComplete}
                onUpdateTitle={updateTaskTitle}
                onTaskPress={handleTaskPress}
                onTaskLongPress={handleTaskLongPress}
                defaultExpanded={section.type !== "completed"}
              />
            ))
          )}
        </ScrollView>

        {/* Floating Add Button */}
        <Pressable onPress={handleAddTask} style={styles.fab}>
          <Ionicons name="add" size={28} color={colors.text.primary} />
        </Pressable>
      </SafeAreaView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: spacing.xl,
    paddingVertical: spacing.base,
    gap: spacing.md,
  },
  headerTop: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
  },
  title: {
    fontSize: typography.fontSize.xl,
    fontWeight: typography.fontWeight.bold,
    color: colors.text.primary,
  },
  subtitle: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
    marginTop: spacing.xs,
  },
  addButton: {
    width: 40,
    height: 40,
    borderRadius: borderRadius.full,
    backgroundColor: colors.surface.elevated,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: colors.surface.border,
  },
  statsRow: {
    flexDirection: "row",
    gap: spacing.lg,
    paddingTop: spacing.sm,
  },
  statItem: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.xs,
  },
  statDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  statLabel: {
    fontSize: typography.fontSize.sm,
    color: colors.text.secondary,
  },
  scrollView: {
    flex: 1,
  },
  scrollContent: {
    paddingTop: spacing.sm,
    paddingBottom: 100, // Space for FAB
  },
  fab: {
    position: "absolute",
    right: spacing.xl,
    bottom: spacing.xl,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.primary.blue,
    alignItems: "center",
    justifyContent: "center",
    shadowColor: colors.primary.blue,
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 8,
    elevation: 8,
  },
});
