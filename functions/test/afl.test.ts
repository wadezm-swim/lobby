import { describe, expect, it } from "vitest";
import { buildAFLDoc, gameWindow, ladderFrom, modelScores, SquiggleGame, SquiggleStanding, SquiggleTip, toGame } from "../src/afl";
import { json } from "./helpers";

const games = json<{ games: SquiggleGame[] }>("games.json").games;
const standings = json<{ standings: SquiggleStanding[] }>("standings.json").standings;
const tips = json<{ tips: SquiggleTip[] }>("tips.json").tips;

describe("Squiggle games", () => {
  it("converts a game with UTC start", () => {
    const game = toGame(games[0]);
    expect(game.start).toBe(new Date(games[0].unixtime * 1000).toISOString());
    expect(game.home).toBe(games[0].hteam);
    expect(game.complete).toBe(100);
  });

  it("sorts the ladder by rank and rounds percentage", () => {
    const ladder = ladderFrom(standings);
    expect(ladder[0].rank).toBe(1);
    expect(ladder).toHaveLength(18);
    expect(ladder.find((row) => row.teamID === 13)?.name).toBe("Port Adelaide");
    expect(String(ladder[0].percentage).split(".")[1]?.length ?? 0).toBeLessThanOrEqual(1);
  });

  it("scores the computer models", () => {
    const scores = modelScores(tips);
    expect(scores.length).toBeGreaterThan(1);
    expect(scores[0].correct).toBeGreaterThanOrEqual(scores[1].correct);
    for (const score of scores) expect(score.correct).toBeLessThanOrEqual(score.tipped);
  });

  it("ignores tips for games not played yet", () => {
    expect(modelScores([{ gameid: 1, source: "X", sourceid: 1, correct: null, tipteamid: 13 }])).toEqual([]);
  });
});

describe("season doc", () => {
  it("is the off-season once every game is complete", () => {
    const doc = buildAFLDoc({ year: 2026, games, nextYearGames: [], standings, tips });
    expect(doc.phase).toBe("offSeason");
    expect(doc.live).toEqual([]);
    expect(doc.upcoming).toEqual([]);
    expect(doc.recent.length).toBeGreaterThan(0);
    expect(new Set(doc.recent.map((g) => g.round)).size).toBe(1);
  });

  it("shows next season's opener once the fixture is out", () => {
    const nextYear = [{ ...games[0], id: 99_001, year: 2027, round: 1, roundname: "Round 1", complete: 0, hscore: null, ascore: null, unixtime: 1_773_000_000 }];
    const doc = buildAFLDoc({ year: 2026, games, nextYearGames: nextYear, standings, tips });
    expect(doc.phase).toBe("offSeason");
    expect(doc.upcoming.map((g) => g.id)).toEqual([99_001]);
  });

  it("mid-season: live games, the next two rounds, the last complete round", () => {
    const season = games.map((g, i) => {
      if (g.round <= 24) return g;
      if (g.round === 25 && i % 2 === 0) return { ...g, complete: 55, hscore: 40, ascore: 38, timestr: "Q3 12:00" };
      return { ...g, complete: 0, hscore: null, ascore: null };
    });
    const doc = buildAFLDoc({ year: 2026, games: season, nextYearGames: [], standings, tips });
    expect(doc.phase).toBe("season");
    expect(doc.live.length).toBeGreaterThan(0);
    expect(doc.live.every((g) => g.status === "Q3 12:00")).toBe(true);
    expect(new Set(doc.upcoming.map((g) => g.round)).size).toBeLessThanOrEqual(2);
    expect(doc.recent.every((g) => g.round === 24)).toBe(true);
  });

  it("knows when a game window is open", () => {
    const base = buildAFLDoc({ year: 2026, games, nextYearGames: [], standings, tips });
    expect(gameWindow(base, new Date())).toBe(false);
    const soon = new Date(Date.now() + 10 * 60_000).toISOString();
    expect(gameWindow({ ...base, upcoming: [{ ...base.recent[0], complete: 0, start: soon }] }, new Date())).toBe(true);
    expect(gameWindow({ ...base, live: [base.recent[0]] }, new Date())).toBe(true);
  });
});
