import { Timestamp } from "firebase/firestore";

export interface Priority {
  id: string;
  name: string;
  color: string; // "#FF5733"
  weeklyHoursTarget: number;
  order: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface PriorityCreateInput {
  name: string;
  color: string;
  order?: number;
}

export interface PriorityUpdateInput {
  name?: string;
  color?: string;
  weeklyHoursTarget?: number;
  order?: number;
}

export interface PriorityWithStats extends Priority {
  hoursUsed: number;
  hoursRemaining: number;
  percentageUsed: number;
  isUnderAllocated: boolean;
}
