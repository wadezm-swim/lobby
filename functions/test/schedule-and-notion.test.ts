import { describe, expect, it } from "vitest";
import { inboxShape, pageFor } from "../src/notion";
import { adelaideYear, dueTasks, intervalFor } from "../src/schedule";

describe("scheduling", () => {
  const quiet = { raceWeekend: false, aflGameWindow: false };
  const busy = { raceWeekend: true, aflGameWindow: true };
  const now = new Date("2026-10-19T03:00:00Z");

  it("runs everything on a fresh project", () => {
    expect(dueTasks({}, now, quiet)).toEqual(["f1", "afl", "aflTips", "news"]);
  });

  it("waits six hours for F1 outside a race weekend, 30 minutes during one", () => {
    const state = { f1: new Date(now.getTime() - 45 * 60_000).toISOString() };
    expect(dueTasks(state, now, quiet)).not.toContain("f1");
    expect(dueTasks(state, now, busy)).toContain("f1");
  });

  it("gives a 15 minute tick enough grace to hit a 30 minute task", () => {
    const state = { f1: new Date(now.getTime() - 29 * 60_000).toISOString() };
    expect(dueTasks(state, now, busy)).toContain("f1");
  });

  it("refreshes AFL every 10 minutes during a game", () => {
    expect(intervalFor("afl", busy)).toBe(10 * 60_000);
    expect(intervalFor("aflTips", busy)).toBe(24 * 60 * 60_000);
  });

  it("knows the Adelaide year on New Year's Eve", () => {
    expect(adelaideYear(new Date("2026-12-31T14:00:00Z"))).toBe(2027);
    expect(adelaideYear(new Date("2026-12-31T12:00:00Z"))).toBe(2026);
  });
});

describe("Notion", () => {
  const database = {
    properties: { Task: { type: "title" }, "Due date": { type: "date" }, Tags: { type: "multi_select" } },
  };

  it("finds the title and due columns", () => {
    expect(inboxShape(database)).toEqual({ titleProperty: "Task", dueProperty: "Due date" });
    expect(inboxShape({ properties: { Name: { type: "title" } } })).toEqual({ titleProperty: "Name", dueProperty: null });
  });

  it("builds a page for a task with a due date", () => {
    const page = pageFor(
      { text: "chase officials roster thursday", title: "Chase officials roster", kind: "task", createdAt: "2026-10-19T00:00:00Z", due: "2026-10-21T13:30:00.000Z" },
      "db1",
      inboxShape(database),
    ) as { properties: Record<string, unknown>; children: unknown[] };
    expect(page.properties.Task).toEqual({ title: [{ text: { content: "Chase officials roster" } }] });
    expect(page.properties["Due date"]).toEqual({ date: { start: "2026-10-21" } });
    expect(page.children).toHaveLength(1);
  });

  it("prefixes waiting-on items and keeps reminders out of Notion", () => {
    const waiting = pageFor({ text: "lane booking", title: "Lane booking", kind: "waitingOn", createdAt: "x" }, "db1", { titleProperty: "Name", dueProperty: null }) as { properties: { Name: { title: { text: { content: string } }[] } } };
    expect(waiting.properties.Name.title[0].text.content).toBe("Waiting on: Lane booking");
    expect(pageFor({ text: "x", title: "X", kind: "reminder", createdAt: "x" }, "db1", { titleProperty: "Name", dueProperty: null })).toBeNull();
  });
});
