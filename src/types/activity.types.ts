import { Timestamp } from "firebase/firestore";

/**
 * Activity action types - matches FlowPilot macOS
 */
export type ActivityActionType = "CREATED" | "COMPLETED" | "UNCOMPLETED" | "DELETED";

/**
 * Activity log entry - matches FlowPilot macOS Firestore structure
 */
export interface Activity {
  id: string;
  taskId: string;
  taskTitle: string;
  action: ActivityActionType;
  timestamp: Timestamp;
}

/**
 * Input for creating a new activity log entry
 */
export interface ActivityCreateInput {
  taskId: string;
  taskTitle: string;
  action: ActivityActionType;
}

/**
 * Activity grouped by date for display
 */
export interface ActivityGroup {
  date: Date;
  dateLabel: string; // "Today", "Yesterday", "Dec 1", etc.
  activities: Activity[];
}
