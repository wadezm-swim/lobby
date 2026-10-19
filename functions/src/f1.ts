/**
 * F1 from Jolpica (the Ergast successor). Turns its JSON into the shapes the
 * app reads. Everything here is pure so it can be tested with fixtures.
 */

export type SessionKind =
  | "practice1"
  | "practice2"
  | "practice3"
  | "sprintQualifying"
  | "sprint"
  | "qualifying"
  | "race";

export interface F1Session {
  kind: SessionKind;
  /** ISO 8601, UTC. */
  start: string;
}

export interface F1Weekend {
  /** "2026-18": season and round. */
  id: string;
  season: number;
  round: number;
  name: string;
  shortName: string;
  locality: string;
  country: string;
  sessions: F1Session[];
}

export interface DriverStanding {
  position: number;
  driver: string;
  teamID: string;
  points: number;
}

export interface LatestResult {
  weekendID: string;
  raceName: string;
  /** Surnames, P1 to P3. */
  topThree: string[];
}

interface JolpicaTime {
  date: string;
  time?: string;
}

interface JolpicaRace {
  season: string;
  round: string;
  raceName: string;
  Circuit: { Location: { locality: string; country: string } };
  date: string;
  time?: string;
  FirstPractice?: JolpicaTime;
  SecondPractice?: JolpicaTime;
  ThirdPractice?: JolpicaTime;
  SprintQualifying?: JolpicaTime;
  SprintShootout?: JolpicaTime;
  Sprint?: JolpicaTime;
  Qualifying?: JolpicaTime;
}

export interface JolpicaSchedule {
  MRData: { RaceTable: { season: string; Races: JolpicaRace[] } };
}

export interface JolpicaStandings {
  MRData: {
    StandingsTable: {
      season: string;
      StandingsLists: {
        round: string;
        DriverStandings: {
          position?: string;
          positionText?: string;
          points: string;
          Driver: { familyName: string };
          Constructors: { constructorId: string }[];
        }[];
      }[];
    };
  };
}

export interface JolpicaResults {
  MRData: {
    RaceTable: {
      Races: {
        season: string;
        round: string;
        raceName: string;
        Results?: { position: string; Driver: { familyName: string } }[];
        QualifyingResults?: { position: string; Driver: { familyName: string } }[];
      }[];
    };
  };
}

export const JOLPICA = "https://api.jolpi.ca/ergast/f1";

/** Jolpica leaves the time off sessions it doesn't know yet; assume midday UTC. */
function iso(when: JolpicaTime): string {
  return new Date(`${when.date}T${when.time ?? "12:00:00Z"}`).toISOString();
}

/** "United States Grand Prix" becomes "US Grand Prix"; long names get "GP". */
export function shortName(raceName: string): string {
  const short = raceName.replace(/^United States /, "US ");
  return short.length > 18 ? short.replace(/Grand Prix/, "GP") : short;
}

export function weekendsFromSchedule(json: JolpicaSchedule): F1Weekend[] {
  return json.MRData.RaceTable.Races.map((race) => {
    const sessions: F1Session[] = [];
    const add = (kind: SessionKind, when?: JolpicaTime) => {
      if (when) sessions.push({ kind, start: iso(when) });
    };
    add("practice1", race.FirstPractice);
    add("practice2", race.SecondPractice);
    add("practice3", race.ThirdPractice);
    add("sprintQualifying", race.SprintQualifying ?? race.SprintShootout);
    add("sprint", race.Sprint);
    add("qualifying", race.Qualifying);
    add("race", { date: race.date, time: race.time });
    sessions.sort((a, b) => a.start.localeCompare(b.start));
    return {
      id: `${race.season}-${race.round}`,
      season: Number(race.season),
      round: Number(race.round),
      name: race.raceName,
      shortName: shortName(race.raceName),
      locality: race.Circuit.Location.locality,
      country: race.Circuit.Location.country,
      sessions,
    };
  });
}

export function standingsFrom(json: JolpicaStandings): { round: number; drivers: DriverStanding[] } {
  const list = json.MRData.StandingsTable.StandingsLists[0];
  if (!list) return { round: 0, drivers: [] };
  return {
    round: Number(list.round),
    drivers: list.DriverStandings.map((row, index) => ({
      position: Number(row.position ?? row.positionText ?? index + 1) || index + 1,
      driver: row.Driver.familyName,
      teamID: row.Constructors[0]?.constructorId ?? "",
      points: Number(row.points),
    })),
  };
}

/** Top three from a race or qualifying result. Null when there isn't one yet. */
export function topThreeFrom(json: JolpicaResults): LatestResult | null {
  const race = json.MRData.RaceTable.Races[0];
  const rows = race?.Results ?? race?.QualifyingResults;
  if (!race || !rows?.length) return null;
  return {
    weekendID: `${race.season}-${race.round}`,
    raceName: race.raceName,
    topThree: [...rows]
      .sort((a, b) => Number(a.position) - Number(b.position))
      .slice(0, 3)
      .map((row) => row.Driver.familyName),
  };
}

/** The latest session with a result that had started by `now`. */
export function latestResultSessionStart(weekends: F1Weekend[], now: Date): Date | null {
  let latest: Date | null = null;
  for (const weekend of weekends) {
    for (const session of weekend.sessions) {
      if (session.kind.startsWith("practice")) continue;
      const start = new Date(session.start);
      if (start <= now && (!latest || start > latest)) latest = start;
    }
  }
  return latest;
}

/** True from two hours before the first session to four hours after the race. */
export function isRaceWeekend(weekends: F1Weekend[], now: Date): boolean {
  return weekends.some((weekend) => {
    const first = new Date(weekend.sessions[0]?.start ?? 0).getTime();
    const last = new Date(weekend.sessions[weekend.sessions.length - 1]?.start ?? 0).getTime();
    return now.getTime() >= first - 2 * 3600_000 && now.getTime() <= last + 4 * 3600_000;
  });
}
