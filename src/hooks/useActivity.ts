import { useEffect, useMemo, useCallback } from "react";
import { useAuthStore, useActivityStore } from "@/stores";
import { activityRepository } from "@/services/repositories";
import { Activity, ActivityGroup, ActivityActionType } from "@/types";
import {
  startOfDay,
  isToday,
  isYesterday,
  format,
  isSameDay,
} from "date-fns";
import { colors } from "@/theme";

export function useActivity() {
  const { user } = useAuthStore();
  const { activities, isLoading, setActivities } = useActivityStore();

  // Subscribe to activities
  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = activityRepository.subscribeRecent(user.uid, (data) => {
      setActivities(data);
    }, 100);

    return () => unsubscribe();
  }, [user?.uid, setActivities]);

  // Group activities by date
  const activityGroups: ActivityGroup[] = useMemo(() => {
    const groups: Map<string, Activity[]> = new Map();

    activities.forEach((activity) => {
      const date = activity.timestamp.toDate();
      const dayStart = startOfDay(date);
      const key = dayStart.toISOString();

      if (!groups.has(key)) {
        groups.set(key, []);
      }
      groups.get(key)!.push(activity);
    });

    return Array.from(groups.entries())
      .map(([key, acts]) => {
        const date = new Date(key);
        let dateLabel: string;

        if (isToday(date)) {
          dateLabel = "Today";
        } else if (isYesterday(date)) {
          dateLabel = "Yesterday";
        } else {
          dateLabel = format(date, "MMMM d");
        }

        return {
          date,
          dateLabel,
          activities: acts.sort((a, b) =>
            b.timestamp.toMillis() - a.timestamp.toMillis()
          ),
        };
      })
      .sort((a, b) => b.date.getTime() - a.date.getTime());
  }, [activities]);

  // Log activity helper (called from task operations)
  const logActivity = useCallback(
    async (taskId: string, taskTitle: string, action: ActivityActionType) => {
      if (!user?.uid) return;
      await activityRepository.logActivity(user.uid, { taskId, taskTitle, action });
    },
    [user?.uid]
  );

  // Get action display info
  const getActionInfo = useCallback((action: ActivityActionType) => {
    const actionMap: Record<
      ActivityActionType,
      { label: string; icon: string; color: string }
    > = {
      CREATED: {
        label: "Created",
        icon: "add-circle",
        color: colors.activity.created,
      },
      COMPLETED: {
        label: "Completed",
        icon: "checkmark-circle",
        color: colors.activity.completed,
      },
      UNCOMPLETED: {
        label: "Uncompleted",
        icon: "arrow-undo",
        color: colors.activity.uncompleted,
      },
      DELETED: {
        label: "Deleted",
        icon: "trash",
        color: colors.activity.deleted,
      },
    };
    return actionMap[action];
  }, []);

  // Get today's activity count
  const todayCount = useMemo(() => {
    return activities.filter((a) => isToday(a.timestamp.toDate())).length;
  }, [activities]);

  return {
    activities,
    activityGroups,
    isLoading,
    logActivity,
    getActionInfo,
    todayCount,
  };
}
