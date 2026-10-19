/**
 * AFL from Squiggle: fixtures, live scores, the ladder and how the computer
 * tipsters are going. Pure transforms so they can be tested with fixtures.
 */

export const SQUIGGLE = "https://api.squiggle.com.au/";

export interface SquiggleGame {
  id: number;
  year: number;
  round: number;
  roundname: string;
  hteamid: number | null;
  ateamid: number | null;
  hteam: string | null;
  ateam: string | null;
  hscore: number | null;
  ascore: number | null;
  /** 0 to 100. */
  complete: number;
  /** Seconds since 1970, UTC. */
  unixtime: number;
  venue: string;
  timestr?: string | null;
  is_final?: number;
}

export interface SquiggleStanding {
  id: number;
  name: string;
  rank: number;
  played: number;
  wins: number;
  losses: number;
  draws: number;
  pts: number;
  percentage: number;
}

export interface SquiggleTip {
  gameid: number;
  source: string;
  sourceid: number;
  /** 1 right, 0 wrong, null not played yet. */
  correct: number | null;
  tipteamid: number | null;
}

export interface Game {
  id: number;
  round: number;
  roundName: string;
  homeID: number | null;
  awayID: number | null;
  home: string;
  away: string;
  /** ISO 8601, UTC. */
  start: string;
  venue: string;
  homeScore: number | null;
  awayScore: number | null;
  complete: number;
  status: string | null;
}

export interface LadderRow {
  rank: number;
  teamID: number;
  name: string;
  played: number;
  wins: number;
  losses: number;
  draws: number;
  points: number;
  percentage: number;
}

export interface ModelScore {
  source: string;
  correct: number;
  tipped: number;
}

export interface AFLDoc {
  year: number;
  phase: "season" | "offSeason";
  ladder: LadderRow[];
  /** Games in progress right now. */
  live: Game[];
  /** The next two rounds still to be played (or next season's opener). */
  upcoming: Game[];
  /** The most recent completed round. */
  recent: Game[];
  models: ModelScore[];
}

export function toGame(g: SquiggleGame): Game {
  return {
    id: g.id,
    round: g.round,
    roundName: g.roundname,
    homeID: g.hteamid,
    awayID: g.ateamid,
    home: g.hteam ?? "TBC",
    away: g.ateam ?? "TBC",
    start: new Date(g.unixtime * 1000).toISOString(),
    venue: g.venue,
    homeScore: g.hscore,
    awayScore: g.ascore,
    complete: g.complete,
    status: g.timestr ?? null,
  };
}

export function ladderFrom(standings: SquiggleStanding[]): LadderRow[] {
  return [...standings]
    .sort((a, b) => a.rank - b.rank)
    .map((s) => ({
      rank: s.rank,
      teamID: s.id,
      name: s.name,
      played: s.played,
      wins: s.wins,
      losses: s.losses,
      draws: s.draws,
      points: s.pts,
      percentage: Math.round(s.percentage * 10) / 10,
    }));
}

/** Correct tips per computer model across the season, best first. */
export function modelScores(tips: SquiggleTip[]): ModelScore[] {
  const scores = new Map<string, ModelScore>();
  for (const tip of tips) {
    if (tip.correct === null || tip.correct === undefined) continue;
    const score = scores.get(tip.source) ?? { source: tip.source, correct: 0, tipped: 0 };
    score.tipped += 1;
    score.correct += tip.correct ? 1 : 0;
    scores.set(tip.source, score);
  }
  return [...scores.values()].sort((a, b) => b.correct - a.correct || a.source.localeCompare(b.source));
}

/**
 * Puts a season together. `nextYearGames` is next season's fixture, which
 * shows up once the AFL releases it (usually late in the year).
 */
export function buildAFLDoc(input: {
  year: number;
  games: SquiggleGame[];
  nextYearGames: SquiggleGame[];
  standings: SquiggleStanding[];
  tips: SquiggleTip[];
}): AFLDoc {
  const games = input.games.map(toGame);
  const unfinished = games.filter((g) => g.complete < 100);
  const phase = unfinished.length > 0 ? "season" : "offSeason";

  const live = games.filter((g) => g.complete > 0 && g.complete < 100);
  const notStarted = (phase === "season" ? games : input.nextYearGames.map(toGame))
    .filter((g) => g.complete === 0)
    .sort((a, b) => a.start.localeCompare(b.start));
  const nextRounds = [...new Set(notStarted.map((g) => g.round))].slice(0, 2);
  const upcoming = notStarted.filter((g) => nextRounds.includes(g.round));

  const finished = games.filter((g) => g.complete === 100);
  const lastRound = finished.reduce<Game | null>((latest, g) => (!latest || g.start > latest.start ? g : latest), null);
  const recent = lastRound ? finished.filter((g) => g.round === lastRound.round) : [];

  return {
    year: input.year,
    phase,
    ladder: ladderFrom(input.standings),
    live,
    upcoming,
    recent,
    models: modelScores(input.tips),
  };
}

/** Is any game on, or about to start? Then it's worth refreshing often. */
export function gameWindow(doc: AFLDoc, now: Date): boolean {
  if (doc.live.length > 0) return true;
  return doc.upcoming.some((g) => {
    const start = new Date(g.start).getTime();
    return now.getTime() >= start - 30 * 60_000 && now.getTime() <= start + 3 * 3600_000;
  });
}
