import { getISOWeek, getYear, startOfWeek, addDays, addWeeks, format } from "date-fns";
import { DayOfWeek } from "@/types";

export const DAY_NAMES = [
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
  "Sunday",
] as const;

/**
 * Get ISO week number and year for a given week offset
 */
export const getWeekInfo = (weekOffset: number = 0): { weekNumber: number; year: number } => {
  const targetDate = addWeeks(new Date(), weekOffset);
  return {
    weekNumber: getISOWeek(targetDate),
    year: getYear(targetDate),
  };
};

/**
 * Get current ISO week number and year (shorthand for getWeekInfo(0))
 */
export const getCurrentWeek = (): { weekNumber: number; year: number } => {
  return getWeekInfo(0);
};

/**
 * Get all days of a week with their dates
 */
export const getWeekDays = (weekOffset: number = 0): Array<{
  dayOfWeek: DayOfWeek;
  name: string;
  date: string;
}> => {
  const targetDate = addWeeks(new Date(), weekOffset);
  const weekStart = startOfWeek(targetDate, { weekStartsOn: 1 }); // Monday

  return DAY_NAMES.map((name, index) => ({
    dayOfWeek: index as DayOfWeek,
    name,
    date: format(addDays(weekStart, index), "yyyy-MM-dd"),
  }));
};

/**
 * Get week date range label (e.g., "Nov 25 - Dec 1")
 */
export const getWeekLabel = (weekOffset: number = 0): string => {
  const targetDate = addWeeks(new Date(), weekOffset);
  const weekStart = startOfWeek(targetDate, { weekStartsOn: 1 });
  const weekEnd = addDays(weekStart, 6);
  return `${format(weekStart, "MMM d")} - ${format(weekEnd, "MMM d")}`;
};

/**
 * Get date for a specific day of the current week
 */
export const getDateForDay = (dayOfWeek: DayOfWeek): string => {
  const now = new Date();
  const weekStart = startOfWeek(now, { weekStartsOn: 1 });
  return format(addDays(weekStart, dayOfWeek), "yyyy-MM-dd");
};

/**
 * Format date for display (e.g., "Nov 28")
 */
export const formatDateShort = (dateString: string): string => {
  return format(new Date(dateString), "MMM d");
};
