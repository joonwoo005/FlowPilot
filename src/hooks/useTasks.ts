import { useEffect, useMemo, useCallback, useRef } from "react";
import { useAuthStore, useTaskStore, usePlannerStore } from "@/stores";
import { taskRepository, activityRepository } from "@/services/repositories";
import {
  Task,
  TaskCreateInput,
  TaskSection,
  TaskSectionType,
  TimeBlock,
} from "@/types";
import { startOfDay, isBefore, isToday, isSameDay, format } from "date-fns";
import { colors } from "@/theme";

// Debounce time for toggle completion (2s)
const TOGGLE_DEBOUNCE_MS = 2000;
// Delay before moving task to completed section (1.5s)
const COMPLETION_DELAY_MS = 1500;

export function useTasks() {
  const { user } = useAuthStore();
  const {
    tasks,
    isLoading,
    recentlyCompletedIds,
    filter,
    sortBy,
    sortDirection,
    setTasks,
    addRecentlyCompleted,
    removeRecentlyCompleted,
  } = useTaskStore();
  const { priorities, timeBlocks } = usePlannerStore();

  // Track last toggle time per task for debounce
  const lastToggleTimeRef = useRef<Map<string, number>>(new Map());
  // Track completion timers
  const completionTimersRef = useRef<Map<string, NodeJS.Timeout>>(new Map());

  // Subscribe to tasks
  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = taskRepository.subscribeAll(user.uid, (data) => {
      setTasks(data);
    });

    return () => {
      unsubscribe();
      // Clear all timers on unmount
      completionTimersRef.current.forEach((timer) => clearTimeout(timer));
      completionTimersRef.current.clear();
    };
  }, [user?.uid, setTasks]);

  // Group tasks into sections
  const taskSections: TaskSection[] = useMemo(() => {
    const now = new Date();
    const todayStart = startOfDay(now);

    const overdue: Task[] = [];
    const scheduled: Task[] = [];
    const unscheduled: Task[] = [];
    const completed: Task[] = [];

    tasks.forEach((task) => {
      // Skip tasks in recently completed set (still animating)
      if (recentlyCompletedIds.has(task.id) && !task.isCompleted) {
        // Task was just completed but Firestore hasn't updated yet
        return;
      }

      if (task.isCompleted) {
        // Only show in completed if not in recentlyCompleted delay
        if (!recentlyCompletedIds.has(task.id)) {
          completed.push(task);
        }
      } else if (!task.timeBlockId || !task.timeBlockDate) {
        unscheduled.push(task);
      } else {
        const taskDate = task.timeBlockDate.toDate();
        if (isBefore(taskDate, todayStart) && !isToday(taskDate)) {
          overdue.push(task);
        } else {
          scheduled.push(task);
        }
      }
    });

    // Also include tasks in recentlyCompletedIds that are still showing
    tasks.forEach((task) => {
      if (recentlyCompletedIds.has(task.id)) {
        if (task.isCompleted) {
          // Task is completed in DB, still in delay period
          // Keep in original section for animation
        }
      }
    });

    // Sort scheduled by date
    scheduled.sort((a, b) => {
      const dateA = a.timeBlockDate?.toDate() || new Date(0);
      const dateB = b.timeBlockDate?.toDate() || new Date(0);
      const dateDiff = dateA.getTime() - dateB.getTime();
      if (dateDiff !== 0) return dateDiff;
      // Same date, sort by start time
      const timeA = a.timeBlockStartTime || "00:00";
      const timeB = b.timeBlockStartTime || "00:00";
      return timeA.localeCompare(timeB);
    });

    // Sort overdue by date (oldest first)
    overdue.sort((a, b) => {
      const dateA = a.timeBlockDate?.toDate() || new Date(0);
      const dateB = b.timeBlockDate?.toDate() || new Date(0);
      return dateA.getTime() - dateB.getTime();
    });

    // Sort completed by most recent first
    completed.sort((a, b) => {
      const timeA = a.updatedAt?.toMillis() || 0;
      const timeB = b.updatedAt?.toMillis() || 0;
      return timeB - timeA;
    });

    // Sort unscheduled by creation date
    unscheduled.sort((a, b) => {
      const timeA = a.createdAt?.toMillis() || 0;
      const timeB = b.createdAt?.toMillis() || 0;
      return timeB - timeA;
    });

    const sections: TaskSection[] = [];

    if (overdue.length > 0) {
      sections.push({
        type: "overdue",
        title: "Overdue",
        subtitle: "Tasks from past blocks",
        icon: "alert-circle",
        iconColor: colors.status.error,
        tasks: overdue,
      });
    }

    if (scheduled.length > 0) {
      sections.push({
        type: "scheduled",
        title: "Scheduled",
        subtitle: "Tasks linked to time blocks",
        icon: "calendar",
        iconColor: colors.primary.blue,
        tasks: scheduled,
      });
    }

    if (unscheduled.length > 0) {
      sections.push({
        type: "unscheduled",
        title: "Inbox",
        subtitle: "Unscheduled tasks",
        icon: "filing",
        iconColor: colors.status.warning,
        tasks: unscheduled,
      });
    }

    if (completed.length > 0) {
      sections.push({
        type: "completed",
        title: "Completed",
        subtitle: "Finished tasks",
        icon: "checkmark-circle",
        iconColor: colors.status.success,
        tasks: completed,
      });
    }

    return sections;
  }, [tasks, recentlyCompletedIds]);

  // Get priority info by ID
  const getPriorityById = useCallback(
    (priorityId?: string) => {
      if (!priorityId) return undefined;
      return priorities.find((p) => p.id === priorityId);
    },
    [priorities]
  );

  // Get time block info by ID
  const getTimeBlockById = useCallback(
    (timeBlockId?: string) => {
      if (!timeBlockId) return undefined;
      return timeBlocks.find((b) => b.id === timeBlockId);
    },
    [timeBlocks]
  );

  // Add a new task
  const addTask = useCallback(
    async (input: TaskCreateInput) => {
      if (!user?.uid) return;
      const taskId = await taskRepository.createTask(user.uid, input);

      // Log activity
      if (taskId) {
        await activityRepository.logActivity(user.uid, {
          taskId,
          taskTitle: input.title,
          action: "CREATED",
        });
      }

      return taskId;
    },
    [user?.uid]
  );

  // Toggle task completion with debounce and delay
  const toggleComplete = useCallback(
    async (task: Task) => {
      if (!user?.uid) return;

      // Check debounce
      const lastToggle = lastToggleTimeRef.current.get(task.id) || 0;
      const now = Date.now();
      if (now - lastToggle < TOGGLE_DEBOUNCE_MS) {
        return; // Debounced
      }
      lastToggleTimeRef.current.set(task.id, now);

      const willComplete = !task.isCompleted;

      if (willComplete) {
        // Add to recently completed immediately for visual feedback
        addRecentlyCompleted(task.id);

        // Set timer to remove from recently completed after delay
        const timer = setTimeout(() => {
          removeRecentlyCompleted(task.id);
          completionTimersRef.current.delete(task.id);
        }, COMPLETION_DELAY_MS);

        completionTimersRef.current.set(task.id, timer);

        // Update in Firestore
        await taskRepository.completeTask(user.uid, task.id);

        // Log activity
        await activityRepository.logActivity(user.uid, {
          taskId: task.id,
          taskTitle: task.title,
          action: "COMPLETED",
        });
      } else {
        // Uncompleting - cancel any pending timer
        const existingTimer = completionTimersRef.current.get(task.id);
        if (existingTimer) {
          clearTimeout(existingTimer);
          completionTimersRef.current.delete(task.id);
        }
        removeRecentlyCompleted(task.id);

        // Update in Firestore
        await taskRepository.uncompleteTask(user.uid, task.id);

        // Log activity
        await activityRepository.logActivity(user.uid, {
          taskId: task.id,
          taskTitle: task.title,
          action: "UNCOMPLETED",
        });
      }
    },
    [user?.uid, addRecentlyCompleted, removeRecentlyCompleted]
  );

  // Delete a task
  const deleteTask = useCallback(
    async (task: Task) => {
      if (!user?.uid) return;

      // Log activity before deleting
      await activityRepository.logActivity(user.uid, {
        taskId: task.id,
        taskTitle: task.title,
        action: "DELETED",
      });

      await taskRepository.delete(user.uid, task.id);
    },
    [user?.uid]
  );

  // Link task to time block
  const linkToTimeBlock = useCallback(
    async (task: Task, timeBlock: TimeBlock) => {
      if (!user?.uid) return;

      // Calculate the actual date from the time block's week and day info
      const { getISOWeek, getYear, startOfWeek, addWeeks, addDays } = await import("date-fns");
      const { dayOfWeek, weekNumber, year } = timeBlock;

      // Find the week that matches the week number and year
      let targetDate = new Date();
      const currentWeekNum = getISOWeek(targetDate);
      const currentYear = getYear(targetDate);

      // Calculate offset from current week
      let weekOffset = 0;
      if (year === currentYear) {
        weekOffset = weekNumber - currentWeekNum;
      } else if (year > currentYear) {
        // Future year
        weekOffset = (52 - currentWeekNum) + weekNumber;
      } else {
        // Past year
        weekOffset = -(currentWeekNum + (52 - weekNumber));
      }

      targetDate = addWeeks(targetDate, weekOffset);
      const weekStart = startOfWeek(targetDate, { weekStartsOn: 1 });
      const blockDate = addDays(weekStart, dayOfWeek);

      await taskRepository.linkToTimeBlock(
        user.uid,
        task.id,
        timeBlock.id,
        blockDate,
        timeBlock.startTime,
        timeBlock.durationMinutes,
        timeBlock.priorityId,
        timeBlock.priorityName,
        timeBlock.priorityId ? (getPriorityById(timeBlock.priorityId)?.color || "#94a3b8") : "#94a3b8"
      );
    },
    [user?.uid, getPriorityById]
  );

  // Unlink task from time block
  const unlinkFromTimeBlock = useCallback(
    async (task: Task) => {
      if (!user?.uid) return;
      await taskRepository.unlinkFromTimeBlock(user.uid, task.id);
    },
    [user?.uid]
  );

  // Update task title
  const updateTaskTitle = useCallback(
    async (taskId: string, newTitle: string) => {
      if (!user?.uid) return;
      await taskRepository.update(user.uid, taskId, { title: newTitle });
    },
    [user?.uid]
  );

  // Get count of tasks by section type
  const getTaskCount = useCallback(
    (sectionType: TaskSectionType) => {
      const section = taskSections.find((s) => s.type === sectionType);
      return section?.tasks.length || 0;
    },
    [taskSections]
  );

  // Total task counts
  const totalTasks = tasks.length;
  const completedCount = tasks.filter((t) => t.isCompleted).length;
  const activeCount = totalTasks - completedCount;

  return {
    tasks,
    taskSections,
    isLoading,
    totalTasks,
    completedCount,
    activeCount,
    addTask,
    toggleComplete,
    deleteTask,
    linkToTimeBlock,
    unlinkFromTimeBlock,
    updateTaskTitle,
    getPriorityById,
    getTimeBlockById,
    getTaskCount,
  };
}
