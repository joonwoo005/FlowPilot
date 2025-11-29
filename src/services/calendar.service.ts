import * as Calendar from "expo-calendar";
import { DaySchedule, TimeBlockWithPriority } from "@/types";
import { addDays, parse } from "date-fns";

const CALENDAR_NAME = "WeekFill";

/**
 * Request calendar permissions from the user
 */
async function requestPermissions(): Promise<boolean> {
  const { status } = await Calendar.requestCalendarPermissionsAsync();
  return status === "granted";
}

/**
 * Get existing WeekFill calendar or create a new one on iCloud
 */
async function getOrCreateCalendar(): Promise<string> {
  const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);

  // Check if WeekFill calendar already exists
  const existingCalendar = calendars.find((cal) => cal.title === CALENDAR_NAME);
  if (existingCalendar) {
    return existingCalendar.id;
  }

  // Find iCloud calendar source specifically
  // iCloud calendars are CalDAV type and source name contains "iCloud"
  const iCloudCalendar = calendars.find(
    (cal) =>
      cal.source.type === Calendar.SourceType.CALDAV &&
      cal.source.name.toLowerCase().includes("icloud")
  );

  if (!iCloudCalendar) {
    throw new Error("iCloud calendar not found. Please ensure iCloud Calendar is enabled in Settings.");
  }

  const source = iCloudCalendar.source;

  const newCalendarId = await Calendar.createCalendarAsync({
    title: CALENDAR_NAME,
    color: "#2563eb",
    entityType: Calendar.EntityTypes.EVENT,
    sourceId: source.id,
    source: source,
    name: CALENDAR_NAME,
    ownerAccount: source.name,
    accessLevel: Calendar.CalendarAccessLevel.OWNER,
  });

  return newCalendarId;
}

/**
 * Delete all events in the WeekFill calendar for a specific date range
 */
async function deleteWeekEvents(
  calendarId: string,
  weekStartDate: Date,
  weekEndDate: Date
): Promise<void> {
  const events = await Calendar.getEventsAsync(
    [calendarId],
    weekStartDate,
    weekEndDate
  );

  for (const event of events) {
    await Calendar.deleteEventAsync(event.id);
  }
}

/**
 * Create a calendar event from a time block
 */
async function createEventFromBlock(
  calendarId: string,
  block: TimeBlockWithPriority,
  dateString: string
): Promise<string> {
  // Parse date and time
  const [hours, minutes] = block.startTime.split(":").map(Number);
  const startDate = parse(dateString, "yyyy-MM-dd", new Date());
  startDate.setHours(hours, minutes, 0, 0);

  // Calculate end time
  const endDate = new Date(startDate.getTime() + block.durationMinutes * 60 * 1000);

  const eventId = await Calendar.createEventAsync(calendarId, {
    title: block.priority.name,
    startDate,
    endDate,
    timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  });

  return eventId;
}

/**
 * Get week date range from the schedule
 */
function getWeekDateRange(weekSchedule: DaySchedule[]): { start: Date; end: Date } {
  if (weekSchedule.length === 0) {
    throw new Error("Week schedule is empty");
  }

  const firstDay = weekSchedule[0];
  const lastDay = weekSchedule[weekSchedule.length - 1];

  const start = parse(firstDay.date, "yyyy-MM-dd", new Date());
  start.setHours(0, 0, 0, 0);

  const end = parse(lastDay.date, "yyyy-MM-dd", new Date());
  end.setHours(23, 59, 59, 999);

  return { start, end };
}

export interface ExportResult {
  success: boolean;
  eventsCreated: number;
  error?: string;
}

/**
 * Main export function - exports all time blocks for the week to Apple Calendar
 */
export async function exportWeekToCalendar(
  weekSchedule: DaySchedule[]
): Promise<ExportResult> {
  try {
    // Request permissions
    const hasPermission = await requestPermissions();
    if (!hasPermission) {
      return {
        success: false,
        eventsCreated: 0,
        error: "Calendar permission denied",
      };
    }

    // Get or create calendar
    const calendarId = await getOrCreateCalendar();

    // Get week date range
    const { start, end } = getWeekDateRange(weekSchedule);

    // Delete existing events for this week
    await deleteWeekEvents(calendarId, start, end);

    // Create events for each time block
    let eventsCreated = 0;

    for (const day of weekSchedule) {
      for (const block of day.timeBlocks) {
        await createEventFromBlock(calendarId, block, day.date);
        eventsCreated++;
      }
    }

    return {
      success: true,
      eventsCreated,
    };
  } catch (error) {
    return {
      success: false,
      eventsCreated: 0,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}
