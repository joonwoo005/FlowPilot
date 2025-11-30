import { create } from "zustand";
import { Task, TaskFilterType, TaskSortType, TaskSortDirection } from "@/types";

interface TaskState {
  // Data
  tasks: Task[];
  isLoading: boolean;

  // For 1.5s completion delay - track recently completed task IDs
  recentlyCompletedIds: Set<string>;

  // UI State
  selectedTaskId: string | null;
  filter: TaskFilterType;
  sortBy: TaskSortType;
  sortDirection: TaskSortDirection;

  // Actions
  setTasks: (tasks: Task[]) => void;
  setLoading: (loading: boolean) => void;
  setSelectedTask: (taskId: string | null) => void;
  setFilter: (filter: TaskFilterType) => void;
  setSortBy: (sortBy: TaskSortType) => void;
  setSortDirection: (direction: TaskSortDirection) => void;
  addRecentlyCompleted: (taskId: string) => void;
  removeRecentlyCompleted: (taskId: string) => void;
  clearRecentlyCompleted: () => void;
}

export const useTaskStore = create<TaskState>((set) => ({
  tasks: [],
  isLoading: true,
  recentlyCompletedIds: new Set(),
  selectedTaskId: null,
  filter: "all",
  sortBy: "date",
  sortDirection: "asc",

  setTasks: (tasks) => set({ tasks, isLoading: false }),
  setLoading: (isLoading) => set({ isLoading }),
  setSelectedTask: (selectedTaskId) => set({ selectedTaskId }),
  setFilter: (filter) => set({ filter }),
  setSortBy: (sortBy) => set({ sortBy }),
  setSortDirection: (sortDirection) => set({ sortDirection }),

  addRecentlyCompleted: (taskId) =>
    set((state) => ({
      recentlyCompletedIds: new Set([...state.recentlyCompletedIds, taskId]),
    })),

  removeRecentlyCompleted: (taskId) =>
    set((state) => {
      const newSet = new Set(state.recentlyCompletedIds);
      newSet.delete(taskId);
      return { recentlyCompletedIds: newSet };
    }),

  clearRecentlyCompleted: () =>
    set({ recentlyCompletedIds: new Set() }),
}));
