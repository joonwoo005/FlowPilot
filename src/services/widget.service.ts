import { Platform, NativeModules } from "react-native";
import { TimeBlock } from "../types/timeBlock.types";
import { timeToMinutes, calculateEndTime } from "../utils/time.utils";

const APP_GROUP_IDENTIFIER = "group.com.junyutoh.weekfill";

// Check if native module is available (not available in Expo Go)
const isNativeModuleAvailable = (): boolean => {
  return Platform.OS === "ios" && NativeModules.RNReactNativeSharedGroupPreferences != null;
};

// Lazy import to avoid errors in Expo Go
const getSharedGroupPreferences = async () => {
  if (!isNativeModuleAvailable()) return null;
  const module = await import("react-native-shared-group-preferences");
  return module.default;
};

export interface WidgetData {
  currentBlock: string | null;
  timeRemaining: string | null;
  blockEndTime: string | null;
  lastUpdated: number;
}

/**
 * Get the current day of week (0 = Monday, 6 = Sunday)
 */
const getCurrentDayOfWeek = (): number => {
  const now = new Date();
  const jsDay = now.getDay(); // 0 = Sunday, 6 = Saturday
  // Convert to Monday = 0, Sunday = 6
  return jsDay === 0 ? 6 : jsDay - 1;
};

/**
 * Get the current time in "HH:MM" format
 */
const getCurrentTime = (): string => {
  const now = new Date();
  const hours = now.getHours().toString().padStart(2, "0");
  const minutes = now.getMinutes().toString().padStart(2, "0");
  return `${hours}:${minutes}`;
};

/**
 * Format remaining minutes to a readable string
 */
const formatTimeRemaining = (minutes: number): string => {
  if (minutes <= 0) return "0m";

  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;

  if (hours === 0) {
    return `${mins}m`;
  } else if (mins === 0) {
    return `${hours}h`;
  } else {
    return `${hours}h ${mins}m`;
  }
};

/**
 * Find the current active time block based on current day and time
 */
export const findCurrentBlock = (
  timeBlocks: TimeBlock[]
): { block: TimeBlock | null; remainingMinutes: number } => {
  const currentDay = getCurrentDayOfWeek();
  const currentTime = getCurrentTime();
  const currentMinutes = timeToMinutes(currentTime);

  // Filter blocks for today
  const todaysBlocks = timeBlocks.filter((block) => block.dayOfWeek === currentDay);

  // Find the block that contains the current time
  for (const block of todaysBlocks) {
    const blockStart = timeToMinutes(block.startTime);
    const blockEnd = blockStart + block.durationMinutes;

    if (currentMinutes >= blockStart && currentMinutes < blockEnd) {
      const remainingMinutes = blockEnd - currentMinutes;
      return { block, remainingMinutes };
    }
  }

  return { block: null, remainingMinutes: 0 };
};

/**
 * Update widget data with current block information
 */
export const updateWidgetData = async (timeBlocks: TimeBlock[]): Promise<void> => {
  if (!isNativeModuleAvailable()) return;

  try {
    const SharedGroupPreferences = await getSharedGroupPreferences();
    if (!SharedGroupPreferences) return;

    const { block, remainingMinutes } = findCurrentBlock(timeBlocks);

    const widgetData: WidgetData = {
      currentBlock: block?.priorityName || null,
      timeRemaining: block ? formatTimeRemaining(remainingMinutes) : null,
      blockEndTime: block ? calculateEndTime(block.startTime, block.durationMinutes) : null,
      lastUpdated: Date.now(),
    };

    // Save to shared App Group storage
    await SharedGroupPreferences.setItem(
      "widgetData",
      widgetData,
      APP_GROUP_IDENTIFIER
    );
  } catch (error) {
    console.error("Failed to update widget data:", error);
  }
};

/**
 * Clear widget data (e.g., when user logs out)
 */
export const clearWidgetData = async (): Promise<void> => {
  if (!isNativeModuleAvailable()) return;

  try {
    const SharedGroupPreferences = await getSharedGroupPreferences();
    if (!SharedGroupPreferences) return;

    const emptyData: WidgetData = {
      currentBlock: null,
      timeRemaining: null,
      blockEndTime: null,
      lastUpdated: Date.now(),
    };

    await SharedGroupPreferences.setItem(
      "widgetData",
      emptyData,
      APP_GROUP_IDENTIFIER
    );
  } catch (error) {
    console.error("Failed to clear widget data:", error);
  }
};
