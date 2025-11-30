import * as Calendar from "expo-calendar";
import { DaySchedule, TimeBlockWithPriority, Task, Priority } from "@/types";
import { addDays, parse } from "date-fns";

// Calendar prefix to match macOS FlowPilot app for cross-device sync
const CALENDAR_PREFIX = "FlowPilot - ";

/**
 * Request calendar permissions from the user
 */
export async function requestCalendarPermissions(): Promise<boolean> {
  const { status } = await Calendar.requestCalendarPermissionsAsync();
  return status === "granted";
}

/**
 * Check if calendar permissions are granted
 */
export async function hasCalendarPermissions(): Promise<boolean> {
  const { status } = await Calendar.getCalendarPermissionsAsync();
  return status === "granted";
}

/**
 * Find the best calendar source for creating new calendars
 * Priority: Local > iCloud (CalDAV) > Default
 */
async function findBestCalendarSource(): Promise<Calendar.Source | null> {
  const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);

  // Try to find Local source
  const localCal = calendars.find((cal) => cal.source.type === Calendar.SourceType.LOCAL);
  if (localCal) return localCal.source;

  // Try iCloud
  const iCloudCal = calendars.find(
    (cal) =>
      cal.source.type === Calendar.SourceType.CALDAV &&
      cal.source.name.toLowerCase().includes("icloud")
  );
  if (iCloudCal) return iCloudCal.source;

  // Try any CalDAV source
  const caldavCal = calendars.find((cal) => cal.source.type === Calendar.SourceType.CALDAV);
  if (caldavCal) return caldavCal.source;

  // Fallback to any available source
  if (calendars.length > 0) return calendars[0].source;

  return null;
}

/**
 * Get or create a calendar for a specific priority
 * Calendar name format: "FlowPilot - {Priority Name}"
 */
async function getOrCreateCalendarForPriority(
  priority: Priority,
  source: Calendar.Source
): Promise<string> {
  const calendarTitle = `${CALENDAR_PREFIX}${priority.name}`;
  const calendars = await Calendar.getCalendarsAsync(Calendar.EntityTypes.EVENT);

  // Check if calendar already exists
  const existingCalendar = calendars.find((cal) => cal.title === calendarTitle);
  if (existingCalendar) {
    return existingCalendar.id;
  }

  // Create new calendar with priority color
  const newCalendarId = await Calendar.createCalendarAsync({
    title: calendarTitle,
    color: priority.color,
    entityType: Calendar.EntityTypes.EVENT,
    sourceId: source.id,
    source: source,
    name: calendarTitle,
    ownerAccount: source.name,
    accessLevel: Calendar.CalendarAccessLevel.OWNER,
  });

  return newCalendarId;
}

/**
 * Delete all events in a calendar for a specific date range
 */
async function deleteEventsInRange(
  calendarId: string,
  startDate: Date,
  endDate: Date
): Promise<void> {
  try {
    const events = await Calendar.getEventsAsync([calendarId], startDate, endDate);
    for (const event of events) {
      await Calendar.deleteEventAsync(event.id);
    }
  } catch (error) {
    console.log("Error deleting events:", error);
  }
}

/**
 * Create a calendar event from a time block
 * Includes linked tasks in the event notes
 */
async function createEventFromBlock(
  calendarId: string,
  block: TimeBlockWithPriority,
  dateString: string,
  linkedTasks: Task[] = []
): Promise<string> {
  // Parse date and time
  const [hours, minutes] = block.startTime.split(":").map(Number);
  const startDate = parse(dateString, "yyyy-MM-dd", new Date());
  startDate.setHours(hours, minutes, 0, 0);

  // Calculate end time
  const endDate = new Date(startDate.getTime() + block.durationMinutes * 60 * 1000);

  // Build notes with linked tasks
  let notes = "";
  if (linkedTasks.length > 0) {
    const taskLines = linkedTasks.map((task) => {
      const checkbox = task.isCompleted ? "☑" : "☐";
      return `${checkbox} ${task.title}`;
    });
    notes = "Tasks:\n" + taskLines.join("\n");
  }

  const eventId = await Calendar.createEventAsync(calendarId, {
    title: block.priority.name,
    startDate,
    endDate,
    notes: notes || undefined,
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

export interface ExportOptions {
  silent?: boolean; // If true, don't show any alerts (for auto-sync)
  tasks?: Task[]; // Tasks to include in event notes
}

/**
 * Main export function - exports all time blocks for the week to Apple Calendar
 * Creates one calendar per priority with "FlowPilot - {Priority}" naming
 * Includes linked tasks in event notes
 * @param weekSchedule - The week's schedule to export
 * @param options - Optional settings (silent mode for auto-sync, tasks for notes)
 */
export async function exportWeekToCalendar(
  weekSchedule: DaySchedule[],
  options: ExportOptions = {}
): Promise<ExportResult> {
  try {
    // Request permissions
    const hasPermission = await requestCalendarPermissions();
    if (!hasPermission) {
      return {
        success: false,
        eventsCreated: 0,
        error: "Calendar permission denied",
      };
    }

    // Find best calendar source
    const source = await findBestCalendarSource();
    if (!source) {
      return {
        success: false,
        eventsCreated: 0,
        error: "No calendar source available. Please ensure Calendar is set up.",
      };
    }

    // Get week date range
    const { start, end } = getWeekDateRange(weekSchedule);

    // Build task lookup by block ID
    const tasksByBlockId: Record<string, Task[]> = {};
    if (options.tasks) {
      for (const task of options.tasks) {
        if (task.timeBlockId) {
          if (!tasksByBlockId[task.timeBlockId]) {
            tasksByBlockId[task.timeBlockId] = [];
          }
          tasksByBlockId[task.timeBlockId].push(task);
        }
      }
    }

    // Get unique priorities from the schedule
    const priorityMap = new Map<string, Priority>();
    for (const day of weekSchedule) {
      for (const block of day.timeBlocks) {
        if (block.priority && !priorityMap.has(block.priority.id)) {
          priorityMap.set(block.priority.id, block.priority);
        }
      }
    }

    // Create/find calendars for each priority and clear their events
    const calendarMap = new Map<string, string>(); // priorityId -> calendarId
    for (const [priorityId, priority] of priorityMap) {
      const calendarId = await getOrCreateCalendarForPriority(priority, source);
      calendarMap.set(priorityId, calendarId);
      // Clear existing events for this week in this calendar
      await deleteEventsInRange(calendarId, start, end);
    }

    // Create events for each time block
    let eventsCreated = 0;

    for (const day of weekSchedule) {
      for (const block of day.timeBlocks) {
        const calendarId = calendarMap.get(block.priority.id);
        if (!calendarId) continue;

        const linkedTasks = tasksByBlockId[block.id] || [];
        await createEventFromBlock(calendarId, block, day.date, linkedTasks);
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
