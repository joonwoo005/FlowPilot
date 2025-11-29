import { create } from "zustand";
import { Priority, TimeBlock, ViewMode } from "@/types";

interface PlannerState {
  // Data
  priorities: Priority[];
  timeBlocks: TimeBlock[];

  // UI State
  viewMode: ViewMode;
  selectedDay: number | null;
  weekOffset: number; // 0 = current week, -1 = last week, 1 = next week

  // Actions
  setPriorities: (priorities: Priority[]) => void;
  setTimeBlocks: (timeBlocks: TimeBlock[]) => void;
  setViewMode: (mode: ViewMode) => void;
  setSelectedDay: (day: number | null) => void;
  setWeekOffset: (offset: number) => void;
  goToPreviousWeek: () => void;
  goToNextWeek: () => void;
  goToCurrentWeek: () => void;
}

export const usePlannerStore = create<PlannerState>((set) => ({
  priorities: [],
  timeBlocks: [],
  viewMode: "weekly",
  selectedDay: null,
  weekOffset: 0,

  setPriorities: (priorities) => set({ priorities }),
  setTimeBlocks: (timeBlocks) => set({ timeBlocks }),
  setViewMode: (viewMode) => set({ viewMode }),
  setSelectedDay: (selectedDay) => set({ selectedDay }),
  setWeekOffset: (weekOffset) => set({ weekOffset }),
  goToPreviousWeek: () => set((state) => ({ weekOffset: state.weekOffset - 1 })),
  goToNextWeek: () => set((state) => ({ weekOffset: state.weekOffset + 1 })),
  goToCurrentWeek: () => set({ weekOffset: 0 }),
}));
