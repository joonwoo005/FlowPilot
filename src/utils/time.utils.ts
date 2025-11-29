/**
 * Calculate hours between two times (e.g., sleep to wake)
 * Handles overnight periods (e.g., 22:00 to 06:00)
 */
export const calculateAwakeHours = (
  sleepTime: string,
  wakeTime: string
): number => {
  const [sleepH, sleepM] = sleepTime.split(":").map(Number);
  const [wakeH, wakeM] = wakeTime.split(":").map(Number);

  const sleepMinutes = sleepH * 60 + sleepM;
  const wakeMinutes = wakeH * 60 + wakeM;

  // Calculate sleep duration
  let sleepDuration: number;
  if (sleepMinutes > wakeMinutes) {
    // Overnight sleep (e.g., 22:00 to 06:00)
    sleepDuration = 24 * 60 - sleepMinutes + wakeMinutes;
  } else {
    // Same day sleep (unusual but handle it)
    sleepDuration = wakeMinutes - sleepMinutes;
  }

  const sleepHours = sleepDuration / 60;
  const awakeHours = 24 - sleepHours;

  return Math.round(awakeHours * 10) / 10; // Round to 1 decimal
};

/**
 * Format minutes to hours display (e.g., 90 -> "1.5h")
 */
export const formatMinutesToHours = (minutes: number): string => {
  const hours = minutes / 60;
  return `${Math.round(hours * 10) / 10}h`;
};

/**
 * Parse time string to minutes since midnight
 */
export const timeToMinutes = (time: string): number => {
  const [hours, minutes] = time.split(":").map(Number);
  return hours * 60 + minutes;
};

/**
 * Format minutes since midnight to time string
 */
export const minutesToTime = (minutes: number): string => {
  const hours = Math.floor(minutes / 60) % 24;
  const mins = minutes % 60;
  return `${hours.toString().padStart(2, "0")}:${mins.toString().padStart(2, "0")}`;
};

/**
 * Calculate end time given start time and duration
 */
export const calculateEndTime = (
  startTime: string,
  durationMinutes: number
): string => {
  const startMinutes = timeToMinutes(startTime);
  const endMinutes = startMinutes + durationMinutes;
  return minutesToTime(endMinutes);
};

/**
 * Format hours to display with minutes only when needed
 * Examples: 24.0 → "24h", 24.5 → "24h 30m", 2.25 → "2h 15m"
 */
export const formatHoursAndMinutes = (hours: number): string => {
  const wholeHours = Math.floor(hours);
  const fractionalHours = hours - wholeHours;
  const minutes = Math.round(fractionalHours * 60);

  if (minutes === 0) {
    return `${wholeHours}h`;
  }
  return `${wholeHours}h ${minutes}m`;
};

/**
 * Format 24-hour time string to 12-hour format
 * Examples: "14:30" → "02:30PM", "09:00" → "09:00AM"
 */
export const formatTime12Hour = (time: string): string => {
  const [hours, minutes] = time.split(":").map(Number);
  const period = hours >= 12 ? "PM" : "AM";
  const hour12 = hours % 12 || 12;
  return `${hour12.toString().padStart(2, "0")}:${minutes.toString().padStart(2, "0")}${period}`;
};
