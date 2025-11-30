import { create } from "zustand";
import { Activity } from "@/types";

interface ActivityState {
  // Data
  activities: Activity[];
  isLoading: boolean;

  // Actions
  setActivities: (activities: Activity[]) => void;
  setLoading: (loading: boolean) => void;
}

export const useActivityStore = create<ActivityState>((set) => ({
  activities: [],
  isLoading: true,

  setActivities: (activities) => set({ activities, isLoading: false }),
  setLoading: (isLoading) => set({ isLoading }),
}));
