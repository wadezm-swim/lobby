/**
 * One scheduled job every 15 minutes decides what to refresh. Google Cloud
 * Scheduler gives three free jobs per account and charges for more, so Lobby
 * uses one here and keeps the other two for the morning and Friday jobs later.
 */

export type Task = "f1" | "afl" | "aflTips" | "news";

/** When each task last ran, ISO 8601. */
export type SyncState = Partial<Record<Task, string>>;

export interface Conditions {
  /** From two hours before first practice to four hours after the race. */
  raceWeekend: boolean;
  /** An AFL game is on or about to start. */
  aflGameWindow: boolean;
}

const MINUTE = 60_000;

/** How stale each task may get before it runs again. */
export function intervalFor(task: Task, conditions: Conditions): number {
  switch (task) {
    case "f1":
      return conditions.raceWeekend ? 30 * MINUTE : 6 * 60 * MINUTE;
    case "afl":
      return conditions.aflGameWindow ? 10 * MINUTE : 6 * 60 * MINUTE;
    case "aflTips":
      return 24 * 60 * MINUTE;
    case "news":
      return conditions.raceWeekend ? 30 * MINUTE : 60 * MINUTE;
  }
}

/** The tasks to run this tick. A small grace stops a 15 minute tick skipping a 30 minute task. */
export function dueTasks(state: SyncState, now: Date, conditions: Conditions): Task[] {
  const grace = 2 * MINUTE;
  return (["f1", "afl", "aflTips", "news"] as Task[]).filter((task) => {
    const last = state[task] ? new Date(state[task] as string).getTime() : 0;
    return now.getTime() - last + grace >= intervalFor(task, conditions);
  });
}

/** The year as Adelaide sees it, which matters around New Year. */
export function adelaideYear(now: Date): number {
  return Number(new Intl.DateTimeFormat("en-AU", { timeZone: "Australia/Adelaide", year: "numeric" }).format(now));
}
