import { Timestamp } from "firebase/firestore";

export interface User {
  id: string;
  name: string;
  sleepTime: string; // "22:00" format
  wakeTime: string; // "06:00" format
  awakeHoursPerDay: number;
  onboardingComplete: boolean;
  calendarSyncEnabled?: boolean; // Auto-sync to Apple Calendar
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface UserCreateInput {
  name: string;
}

export interface UserSleepScheduleInput {
  sleepTime: string;
  wakeTime: string;
  awakeHoursPerDay: number;
}

export type OnboardingStep = "name" | "priorities" | "sleep" | "allocate";
