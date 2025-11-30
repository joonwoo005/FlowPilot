import { Timestamp } from "firebase/firestore";

/**
 * Task model - matches FlowPilot macOS Firestore structure
 */
export interface Task {
  id: string;
  title: string;
  isCompleted: boolean;

  // Time block link (optional - denormalized data)
  timeBlockId?: string;
  timeBlockDate?: Timestamp;
  timeBlockStartTime?: string; // "HH:mm" format
  timeBlockDurationMinutes?: number;

  // Priority link (optional - denormalized data)
  priorityId?: string;
  priorityName?: string;
  priorityColor?: string;

  // Timestamps
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

/**
 * Input for creating a new task
 */
export interface TaskCreateInput {
  title: string;
  priorityId?: string;
  priorityName?: string;
  priorityColor?: string;
  timeBlockId?: string;
  timeBlockDate?: Date;
  timeBlockStartTime?: string;
  timeBlockDurationMinutes?: number;
}

/**
 * Input for updating a task
 */
export interface TaskUpdateInput {
  title?: string;
  isCompleted?: boolean;
  priorityId?: string | null;
  priorityName?: string | null;
  priorityColor?: string | null;
  timeBlockId?: string | null;
  timeBlockDate?: Date | null;
  timeBlockStartTime?: string | null;
  timeBlockDurationMinutes?: number | null;
}

/**
 * Task with priority info for display
 */
export interface TaskWithPriority extends Task {
  priority?: {
    id: string;
    name: string;
    color: string;
  };
}

/**
 * Task section types for grouping
 */
export type TaskSectionType = "overdue" | "scheduled" | "unscheduled" | "completed";

/**
 * Section with tasks grouped by type
 */
export interface TaskSection {
  type: TaskSectionType;
  title: string;
  subtitle?: string;
  icon: string;
  iconColor: string;
  tasks: Task[];
}

/**
 * Filter options for tasks
 */
export type TaskFilterType = "all" | "today" | "thisWeek" | "overdue" | "unscheduled";

/**
 * Sort options for tasks
 */
export type TaskSortType = "date" | "priority" | "title" | "created";

/**
 * Sort direction
 */
export type TaskSortDirection = "asc" | "desc";
