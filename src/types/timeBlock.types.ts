import { Timestamp } from "firebase/firestore";
import { Priority } from "./priority.types";

export type DayOfWeek = 0 | 1 | 2 | 3 | 4 | 5 | 6; // Mon=0, Sun=6

export interface TimeBlock {
  id: string;
  priorityId: string;
  priorityName: string; // Denormalized for easy display
  dayOfWeek: DayOfWeek;
  startTime: string; // "09:00" format
  durationMinutes: number;
  weekNumber: number; // ISO week number
  year: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface TimeBlockCreateInput {
  priorityId: string;
  priorityName: string;
  dayOfWeek: DayOfWeek;
  startTime: string;
  durationMinutes: number;
}

export interface TimeBlockWithPriority extends TimeBlock {
  priority: Priority;
}

export interface DaySchedule {
  dayOfWeek: DayOfWeek;
  dayName: string;
  date: string;
  timeBlocks: TimeBlockWithPriority[];
  totalHours: number;
}

export type ViewMode = "weekly" | "daily";
