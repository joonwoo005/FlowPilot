import { useEffect, useMemo, useCallback } from "react";
import { useAuthStore, usePlannerStore } from "@/stores";
import { priorityRepository } from "@/services/repositories";
import { PriorityCreateInput, PriorityWithStats } from "@/types";

export function usePriorities() {
  const { user } = useAuthStore();
  const { priorities, timeBlocks, setPriorities } = usePlannerStore();

  useEffect(() => {
    if (!user?.uid) return;

    const unsubscribe = priorityRepository.subscribeAll(user.uid, (data) => {
      setPriorities(data);
    });

    return () => unsubscribe();
  }, [user?.uid, setPriorities]);

  const getHoursUsedByPriority = useCallback(
    (priorityId: string): number => {
      return timeBlocks
        .filter((block) => block.priorityId === priorityId)
        .reduce((total, block) => total + block.durationMinutes / 60, 0);
    },
    [timeBlocks]
  );

  const prioritiesWithStats: PriorityWithStats[] = useMemo(() => {
    return priorities.map((priority) => {
      const hoursUsed = getHoursUsedByPriority(priority.id);
      const hoursRemaining = priority.weeklyHoursTarget - hoursUsed;
      const percentageUsed =
        priority.weeklyHoursTarget > 0
          ? (hoursUsed / priority.weeklyHoursTarget) * 100
          : 0;

      return {
        ...priority,
        hoursUsed,
        hoursRemaining,
        percentageUsed,
        isUnderAllocated: hoursRemaining > 0,
      };
    });
  }, [priorities, getHoursUsedByPriority]);

  const addPriority = async (input: PriorityCreateInput) => {
    if (!user?.uid) return;
    await priorityRepository.createWithOrder(user.uid, input, priorities.length);
  };

  const deletePriority = async (id: string) => {
    if (!user?.uid) return;
    await priorityRepository.delete(user.uid, id);
  };

  const hasUnderAllocatedPriorities = prioritiesWithStats.some(
    (p) => p.isUnderAllocated
  );

  return {
    priorities,
    prioritiesWithStats,
    addPriority,
    deletePriority,
    getHoursUsedByPriority,
    hasUnderAllocatedPriorities,
  };
}
