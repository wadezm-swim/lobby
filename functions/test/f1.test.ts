import { describe, expect, it } from "vitest";
import {
  isRaceWeekend,
  JolpicaResults,
  JolpicaSchedule,
  JolpicaStandings,
  latestResultSessionStart,
  shortName,
  standingsFrom,
  topThreeFrom,
  weekendsFromSchedule,
} from "../src/f1";
import { json } from "./helpers";

const schedule = json<JolpicaSchedule>("schedule.json");

describe("Jolpica schedule", () => {
  it("turns races into weekends with sorted sessions", () => {
    const weekends = weekendsFromSchedule(schedule);
    const austin = weekends.find((w) => w.round === 18)!;
    expect(austin.id).toBe("2026-18");
    expect(austin.name).toBe("United States Grand Prix");
    expect(austin.shortName).toBe("US Grand Prix");
    expect(austin.locality).toBe("Austin");
    expect(austin.sessions.map((s) => s.kind)).toEqual(["practice1", "practice2", "practice3", "qualifying", "race"]);
    expect(austin.sessions.at(-1)?.start).toBe("2026-10-25T20:00:00.000Z");
    for (let i = 1; i < austin.sessions.length; i++) {
      expect(austin.sessions[i].start >= austin.sessions[i - 1].start).toBe(true);
    }
  });

  it("reads a sprint weekend", () => {
    const singapore = weekendsFromSchedule(schedule).find((w) => w.round === 17)!;
    expect(singapore.sessions.map((s) => s.kind)).toContain("sprint");
    expect(singapore.sessions.map((s) => s.kind)).toContain("sprintQualifying");
  });

  it("shortens long names", () => {
    expect(shortName("United States Grand Prix")).toBe("US Grand Prix");
    expect(shortName("Emilia Romagna Grand Prix")).toBe("Emilia Romagna GP");
    expect(shortName("Monaco Grand Prix")).toBe("Monaco Grand Prix");
  });
});

describe("standings and results", () => {
  it("reads driver standings", () => {
    const standings = standingsFrom(json<JolpicaStandings>("standings-f1.json"));
    expect(standings.round).toBe(17);
    expect(standings.drivers[0]).toEqual({ position: 1, driver: "Antonelli", teamID: "mercedes", points: 340 });
  });

  it("takes the top three from a race result", () => {
    const latest = topThreeFrom(json<JolpicaResults>("results.json"))!;
    expect(latest.weekendID).toBe("2026-17");
    expect(latest.raceName).toBe("Singapore Grand Prix");
    expect(latest.topThree).toHaveLength(3);
  });

  it("takes the top three from qualifying", () => {
    const latest = topThreeFrom(json<JolpicaResults>("qualifying.json"))!;
    expect(latest.topThree).toHaveLength(3);
  });

  it("returns null when nothing has happened yet", () => {
    expect(topThreeFrom({ MRData: { RaceTable: { Races: [] } } })).toBeNull();
  });
});

describe("timing", () => {
  const weekends = weekendsFromSchedule(schedule);

  it("knows the latest session with a result", () => {
    // Before Austin qualifying: Singapore's race is the latest result.
    expect(latestResultSessionStart(weekends, new Date("2026-10-20T00:00:00Z"))?.toISOString()).toBe("2026-10-11T12:00:00.000Z");
    // After Austin qualifying has started, that's the latest.
    expect(latestResultSessionStart(weekends, new Date("2026-10-24T22:00:00Z"))?.toISOString()).toBe("2026-10-24T21:00:00.000Z");
    // Practice never counts.
    expect(latestResultSessionStart(weekends, new Date("2026-10-23T18:00:00Z"))?.toISOString()).toBe("2026-10-11T12:00:00.000Z");
  });

  it("knows a race weekend when it sees one", () => {
    expect(isRaceWeekend(weekends, new Date("2026-10-20T00:00:00Z"))).toBe(false);
    expect(isRaceWeekend(weekends, new Date("2026-10-23T16:00:00Z"))).toBe(true); // 90 min before FP1
    expect(isRaceWeekend(weekends, new Date("2026-10-25T23:00:00Z"))).toBe(true); // 3h after lights out
    expect(isRaceWeekend(weekends, new Date("2026-10-26T06:00:00Z"))).toBe(false);
  });
});
