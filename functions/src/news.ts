/**
 * The news wire: RSS from F1 sites and AFL.com.au. Headline and link only, as
 * the brief says. Each item is tagged with the teams or clubs it mentions and
 * flagged if it might give a result away, so the spoiler shield can hold it.
 */

import { XMLParser } from "fast-xml-parser";
import { createHash } from "node:crypto";

export interface Feed {
  source: string;
  url: string;
}

export const F1_FEEDS: Feed[] = [
  { source: "Formula1.com", url: "https://www.formula1.com/en/latest/all.xml" },
  { source: "FIA", url: "https://www.fia.com/rss/press-release" },
  { source: "Motorsport.com", url: "https://www.motorsport.com/rss/f1/news/" },
  { source: "Autosport", url: "https://www.autosport.com/rss/f1/news/" },
  { source: "RaceFans", url: "https://www.racefans.net/feed/" },
  { source: "The Race", url: "https://www.the-race.com/rss/" },
];

/** There's no club feed, so this is filtered to his club by tags in the app. */
export const AFL_FEEDS: Feed[] = [{ source: "AFL.com.au", url: "https://www.afl.com.au/rss" }];

export interface NewsItem {
  id: string;
  source: string;
  title: string;
  url: string | null;
  /** ISO 8601. Feeds without dates get the time Lobby first saw the item. */
  published: string;
  mayContainResult: boolean;
  tags: string[];
}

const parser = new XMLParser({
  ignoreAttributes: true,
  processEntities: true,
  htmlEntities: true,
  trimValues: true,
});

/** Turns the odd leftover entity or tag into plain text. */
export function cleanText(text: unknown): string {
  return String(text ?? "")
    .replace(/<[^>]+>/g, "")
    .replace(/&#(\d+);/g, (_, code: string) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code: string) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&apos;|&#039;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

/** Drops tracking parameters so the same story from two fetches matches. */
export function cleanLink(link: unknown): string | null {
  const text = cleanText(link);
  if (!text) return null;
  try {
    const url = new URL(text);
    for (const key of [...url.searchParams.keys()]) {
      if (key.startsWith("utm_")) url.searchParams.delete(key);
    }
    return url.toString();
  } catch {
    return null;
  }
}

export function itemID(source: string, link: string | null, title: string): string {
  return createHash("sha1").update(`${source}|${link ?? title}`).digest("hex").slice(0, 16);
}

/** Reads an RSS 2.0 feed. `now` stamps items that come without a date. */
export function parseRss(xml: string, source: string, now: Date): Omit<NewsItem, "mayContainResult" | "tags">[] {
  const doc = parser.parse(xml);
  const raw = doc?.rss?.channel?.item;
  const items: Record<string, unknown>[] = Array.isArray(raw) ? raw : raw ? [raw] : [];
  return items
    .map((item) => {
      const title = cleanText(item.title);
      const url = cleanLink(item.link);
      const date = item.pubDate ? new Date(cleanText(item.pubDate)) : null;
      const published = date && !Number.isNaN(date.getTime()) ? date : now;
      return { id: itemID(source, url, title), source, title, url, published: published.toISOString() };
    })
    .filter((item) => item.title.length > 0);
}

// MARK: Spoilers

const RESULT_WORDS = [
  /\bwins?\b/i, /\bwon\b/i, /\bvictor(y|ious)\b/i, /\bpodium\b/i, /\bpole\b/i, /\bP[1-9]\b/,
  /\bfastest\b/i, /\btops?\b/i, /\bleads?\b/i, /\bchampion(s|ship)?\b/i, /\bcrowned\b/i,
  /\bclinch(es|ed)?\b/i, /\bbeats?\b/i, /\btriumph/i, /\bone-two\b/i, /\b1-2\b/, /\bdisqualif/i,
  /\bresults?\b/i, /\bstandings\b/i, /\bgrid\b/i, /\bretire[sd]?\b/i, /\bcrash(es|ed)?\b/i,
  /\bDNF\b/, /\bpenalt(y|ies)\b/i, /\bas it happened\b/i, /\bratings?\b/i, /\bwinners and losers\b/i,
  /\btakeaways\b/i, /\bwhat we learned\b/i, /\breport\b/i, /\bverdict\b/i, /\bheartbreak\b/i,
  /\bdominan(t|ce)\b/i, /\bstuns?\b/i, /\bshock\b/i,
];

/**
 * Could this headline give a result away? Deliberately jumpy: a few safe
 * headlines held back is better than one result slipping through. Only
 * headlines published after the latest qualifying, sprint or race started
 * can spoil it. A Haiku classifier can replace the word list later.
 */
export function mayContainResult(title: string, published: Date, latestResultStart: Date | null): boolean {
  if (!latestResultStart || published.getTime() < latestResultStart.getTime() - 3600_000) return false;
  return RESULT_WORDS.some((pattern) => pattern.test(title));
}

// MARK: Tags

/** Team ids match Jolpica's constructorId and the app's picker. */
export const F1_TEAM_WORDS: Record<string, string[]> = {
  alpine: ["Alpine"],
  aston_martin: ["Aston Martin"],
  audi: ["Audi", "Sauber"],
  cadillac: ["Cadillac"],
  ferrari: ["Ferrari"],
  haas: ["Haas"],
  mclaren: ["McLaren"],
  mercedes: ["Mercedes"],
  rb: ["Racing Bulls", "VCARB"],
  red_bull: ["Red Bull"],
  williams: ["Williams"],
};

/** Club ids are Squiggle's. */
export const AFL_CLUB_WORDS: Record<string, string[]> = {
  "1": ["Adelaide Crows", "Crows"],
  "2": ["Brisbane", "Lions"],
  "3": ["Carlton", "Blues"],
  "4": ["Collingwood", "Magpies", "Pies"],
  "5": ["Essendon", "Bombers"],
  "6": ["Fremantle", "Dockers"],
  "7": ["Geelong", "Cats"],
  "8": ["Gold Coast", "Suns"],
  "9": ["GWS", "Giants"],
  "10": ["Hawthorn", "Hawks"],
  "11": ["Melbourne", "Demons", "Dees"],
  "12": ["North Melbourne", "Kangaroos", "Roos"],
  "13": ["Port Adelaide", "Power", "Port"],
  "14": ["Richmond", "Tigers"],
  "15": ["St Kilda", "Saints"],
  "16": ["Sydney", "Swans"],
  "17": ["West Coast", "Eagles"],
  "18": ["Western Bulldogs", "Bulldogs", "Dogs"],
};

function escape(word: string): string {
  return word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Tags by whole-word match. `extra` adds words per tag, like driver surnames. */
export function tagsFor(title: string, words: Record<string, string[]>, extra: Record<string, string[]> = {}): string[] {
  const tags: string[] = [];
  for (const [tag, list] of Object.entries(words)) {
    const all = [...list, ...(extra[tag] ?? [])];
    if (all.some((word) => new RegExp(`(^|[^\\p{L}])${escape(word)}($|[^\\p{L}])`, "u").test(title))) {
      tags.push(tag);
    }
  }
  return tags;
}

/** "Melbourne" inside "North Melbourne" isn't Melbourne; "Port" in "Port Melbourne" isn't Port. */
export function tagAFL(title: string): string[] {
  const cleaned = title.replace(/North Melbourne/g, "NorthMelb").replace(/Port Melbourne/g, "PortMelb");
  return tagsFor(cleaned, { ...AFL_CLUB_WORDS, "12": ["NorthMelb", "Kangaroos", "Roos"] });
}

/** Keeps items from earlier fetches, newest first, so first-seen dates hold. */
export function mergeItems(previous: NewsItem[], fresh: NewsItem[], limit: number): NewsItem[] {
  const byID = new Map(previous.map((item) => [item.id, item]));
  for (const item of fresh) {
    const old = byID.get(item.id);
    byID.set(item.id, old ? { ...item, published: old.published } : item);
  }
  return [...byID.values()].sort((a, b) => b.published.localeCompare(a.published)).slice(0, limit);
}
