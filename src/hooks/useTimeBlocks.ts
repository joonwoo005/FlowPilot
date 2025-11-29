import { useEffect, useMemo } from "react";
import { useAuthStore, usePlannerStore } from "@/stores";
import { timeBlockRepository } from "@/services/repositories";
import { getWeekInfo, getWeekDays, getWeekLabel } from "@/utils";
import { TimeBlockCreateInput, DaySchedule } from "@/types";
import { updateWidgetData } from "@/services/widget.service";

export function useTimeBlocks() {
  const { user } = useAuthStore();
  const { timeBlocks, priorities, weekOffset, setTimeBlocks } = usePlannerStore();
  const { weekNumber, year } = getWeekInfo(weekOffset);
  const weekLabel = getWeekLabel(weekOffset);

  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = timeBlockRepository.subscribeWeekWithOffset(
      user.uid,
      weekOffset,
      (data) => {
        setTimeBlocks(data);
      }
    );

    return () => unsubscribe();
  }, [user?.uid, weekOffset, setTimeBlocks]);

  // Update widget when time blocks change (current week only)
  useEffect(() => {
    if (weekOffset !== 0) return;

    // Update widget immediately
    updateWidgetData(timeBlocks);

    // Update widget every minute to keep time remaining accurate
    const intervalId = setInterval(() => {
      updateWidgetData(timeBlocks);
    }, 60000);

    return () => clearInterval(intervalId);
  }, [timeBlocks, weekOffset]);

  const weekSchedule: DaySchedule[] = useMemo(() => {
    return getWeekDays(weekOffset).map((day) => {
      const dayBlocks = timeBlocks
        .filter((block) => block.dayOfWeek === day.dayOfWeek)
        .map((block) => ({
          ...block,
          priority: priorities.find((p) => p.id === block.priorityId)!,
        }))
        .filter((block) => block.priority) // Filter out blocks without matching priority
        .sort((a, b) => a.startTime.localeCompare(b.startTime));

      const totalHours = dayBlocks.reduce(
        (sum, block) => sum + block.durationMinutes / 60,
        0
      );

      return {
        dayOfWeek: day.dayOfWeek,
        dayName: day.name,
        date: day.date,
        timeBlocks: dayBlocks,
        totalHours,
      };
    });
  }, [timeBlocks, priorities, weekOffset]);

  const addTimeBlock = async (input: TimeBlockCreateInput) => {
    if (!user?.uid) return;
    await timeBlockRepository.createForWeek(user.uid, input, weekOffset);
  };

  const deleteTimeBlock = async (id: string) => {
    if (!user?.uid) return;
    await timeBlockRepository.delete(user.uid, id);
  };

  return {
    timeBlocks,
    weekSchedule,
    addTimeBlock,
    deleteTimeBlock,
    weekLabel,
    weekOffset,
    currentWeek: { weekNumber, year },
  };
}
