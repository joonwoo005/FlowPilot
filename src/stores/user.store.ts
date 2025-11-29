import { create } from "zustand";
import { User } from "@/types";

interface UserState {
  profile: User | null;
  isLoading: boolean;
  setProfile: (profile: User | null) => void;
  setLoading: (loading: boolean) => void;
}

export const useUserStore = create<UserState>((set) => ({
  profile: null,
  isLoading: true,
  setProfile: (profile) => set({ profile, isLoading: false }),
  setLoading: (isLoading) => set({ isLoading }),
}));
