/**
 * Fetches and shapes each feed. No Firestore in here, so the smoke test can run
 * the same code against the live APIs.
 */

import { AFLDoc, buildAFLDoc, ModelScore, SQUIGGLE, SquiggleGame, SquiggleStanding, SquiggleTip } from "./afl";
import {
  DriverStanding,
  F1Weekend,
  JOLPICA,
  JolpicaResults,
  JolpicaSchedule,
  JolpicaStandings,
  LatestResult,
  standingsFrom,
  topThreeFrom,
  weekendsFromSchedule,
} from "./f1";
import { getJson, getText, squiggleUserAgent } from "./http";
import { AFL_FEEDS, F1_FEEDS, F1_TEAM_WORDS, Feed, mayContainResult, NewsItem, parseRss, tagAFL, tagsFor } from "./news";
import { adelaideYear } from "./schedule";

export interface F1Bundle {
  season: number;
  weekends: F1Weekend[];
  standings: { round: number; drivers: DriverStanding[] };
  latestRace: LatestResult | null;
  latestQualifying: LatestResult | null;
}

export async function fetchF1(now: Date): Promise<F1Bundle> {
  const schedule = await getJson<JolpicaSchedule>(`${JOLPICA}/current.json?limit=100`);
  const season = Number(schedule.MRData.RaceTable.season);
  let weekends = weekendsFromSchedule(schedule);

  // Once this season's last race is done, look for next season's calendar.
  const lastRace = weekends[weekends.length - 1]?.sessions.at(-1)?.start;
  if (!lastRace || new Date(lastRace) < now) {
    try {
      const next = await getJson<JolpicaSchedule>(`${JOLPICA}/${season + 1}.json?limit=100`);
      weekends = weekends.concat(weekendsFromSchedule(next));
    } catch {
      // Not published yet. The off-season card says so.
    }
  }

  const [standings, race, qualifying] = await Promise.all([
    getJson<JolpicaStandings>(`${JOLPICA}/current/driverStandings.json`),
    getJson<JolpicaResults>(`${JOLPICA}/current/last/results.json`),
    getJson<JolpicaResults>(`${JOLPICA}/current/last/qualifying.json`),
  ]);

  return {
    season,
    weekends,
    standings: standingsFrom(standings),
    latestRace: topThreeFrom(race),
    latestQualifying: topThreeFrom(qualifying),
  };
}

export async function fetchAFL(now: Date, contact: string, previousModels: ModelScore[] | null): Promise<AFLDoc> {
  const year = adelaideYear(now);
  const options = { userAgent: squiggleUserAgent(contact) };
  const [games, nextYearGames, standings] = await Promise.all([
    getJson<{ games: SquiggleGame[] }>(`${SQUIGGLE}?q=games;year=${year}`, options),
    getJson<{ games: SquiggleGame[] }>(`${SQUIGGLE}?q=games;year=${year + 1}`, options),
    getJson<{ standings: SquiggleStanding[] }>(`${SQUIGGLE}?q=standings;year=${year}`, options),
  ]);
  const doc = buildAFLDoc({ year, games: games.games, nextYearGames: nextYearGames.games, standings: standings.standings, tips: [] });
  doc.models = previousModels ?? [];
  return doc;
}

/** The season's computer tips are a big download, so this runs once a day. */
export async function fetchAFLModels(now: Date, contact: string): Promise<ModelScore[]> {
  const year = adelaideYear(now);
  const tips = await getJson<{ tips: SquiggleTip[] }>(`${SQUIGGLE}?q=tips;year=${year}`, {
    userAgent: squiggleUserAgent(contact),
    timeoutMs: 30_000,
  });
  return buildAFLDoc({ year, games: [], nextYearGames: [], standings: [], tips: tips.tips }).models;
}

export interface FeedReport {
  items: NewsItem[];
  failed: string[];
}

async function readFeeds(feeds: Feed[], now: Date) {
  const results = await Promise.allSettled(feeds.map(async (feed) => parseRss(await getText(feed.url), feed.source, now)));
  const failed = feeds.filter((_, i) => results[i].status === "rejected").map((feed) => feed.source);
  const items = results.flatMap((result) => (result.status === "fulfilled" ? result.value : []));
  return { items, failed };
}

/**
 * F1 headlines, tagged by team (and by driver, using the latest standings),
 * and flagged when they might spoil the latest result.
 */
export async function fetchF1News(now: Date, latestResultStart: Date | null, drivers: DriverStanding[]): Promise<FeedReport> {
  const driverWords: Record<string, string[]> = {};
  for (const d of drivers) (driverWords[d.teamID] ??= []).push(d.driver);
  const { items, failed } = await readFeeds(F1_FEEDS, now);
  return {
    failed,
    items: items.map((item) => ({
      ...item,
      tags: tagsFor(item.title, F1_TEAM_WORDS, driverWords),
      mayContainResult: mayContainResult(item.title, new Date(item.published), latestResultStart),
    })),
  };
}

/** AFL headlines, tagged by club so the app can put his club first. */
export async function fetchAFLNews(now: Date): Promise<FeedReport> {
  const { items, failed } = await readFeeds(AFL_FEEDS, now);
  return {
    failed,
    items: items.map((item) => ({ ...item, tags: tagAFL(item.title), mayContainResult: false })),
  };
}
