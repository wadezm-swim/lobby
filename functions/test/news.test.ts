import { describe, expect, it } from "vitest";
import { cleanLink, cleanText, F1_TEAM_WORDS, mayContainResult, mergeItems, NewsItem, parseRss, tagAFL, tagsFor } from "../src/news";
import { fixture } from "./helpers";

const now = new Date("2026-10-19T03:00:00Z");

describe("RSS", () => {
  it("reads formula1.com, which has no dates", () => {
    const items = parseRss(fixture("formula1.xml"), "Formula1.com", now);
    expect(items.length).toBe(10);
    expect(items[0].title.length).toBeGreaterThan(10);
    expect(items[0].url).toMatch(/^https:\/\/www\.formula1\.com\//);
    expect(items[0].published).toBe(now.toISOString());
    expect(items[0].id).toHaveLength(16);
  });

  it("reads RaceFans, which has dates and CDATA", () => {
    const items = parseRss(fixture("racefans.xml"), "RaceFans", now);
    expect(items.length).toBe(20);
    expect(items[0].published).not.toBe(now.toISOString());
    expect(items[0].title).not.toContain("CDATA");
  });

  it("reads AFL.com.au and drops its media tags", () => {
    const items = parseRss(fixture("afl.xml"), "AFL.com.au", now);
    expect(items.length).toBe(20);
    expect(items.every((item) => item.url?.startsWith("https://www.afl.com.au/"))).toBe(true);
  });

  it("cleans text and links", () => {
    expect(cleanText("Norris &amp; Piastri &#039;chat&#039; <b>live</b>")).toBe("Norris & Piastri 'chat' live");
    expect(cleanLink("https://x.com/a?utm_source=rss&id=1")).toBe("https://x.com/a?id=1");
    expect(cleanLink("not a url")).toBeNull();
  });
});

describe("spoilers", () => {
  const raceStart = new Date("2026-10-25T20:00:00Z");

  it("flags result-shaped headlines after a session has started", () => {
    const after = new Date("2026-10-25T22:30:00Z");
    expect(mayContainResult("Norris wins thrilling US Grand Prix", after, raceStart)).toBe(true);
    expect(mayContainResult("Verstappen takes pole in Austin", after, raceStart)).toBe(true);
    expect(mayContainResult("Driver ratings from the US GP", after, raceStart)).toBe(true);
    expect(mayContainResult("McLaren explains new front wing", after, raceStart)).toBe(false);
  });

  it("leaves old headlines alone", () => {
    const before = new Date("2026-10-23T10:00:00Z");
    expect(mayContainResult("Hamilton wins award", before, raceStart)).toBe(false);
    expect(mayContainResult("Hamilton wins award", before, null)).toBe(false);
  });
});

describe("tags", () => {
  it("tags F1 teams and drivers", () => {
    expect(tagsFor("McLaren and Ferrari clash over flexi-wings", F1_TEAM_WORDS)).toEqual(["ferrari", "mclaren"]);
    expect(tagsFor("Norris: we had the pace", F1_TEAM_WORDS, { mclaren: ["Norris", "Piastri"] })).toEqual(["mclaren"]);
    expect(tagsFor("Red Bull Racing update", F1_TEAM_WORDS)).toEqual(["red_bull"]);
    expect(tagsFor("Williamson joins the paddock", F1_TEAM_WORDS)).toEqual([]);
  });

  it("tags AFL clubs without confusing Port and North", () => {
    expect(tagAFL("Port Adelaide re-sign young gun")).toEqual(["13"]);
    expect(tagAFL("Power to the people")).toEqual(["13"]);
    expect(tagAFL("North Melbourne land top pick")).toEqual(["12"]);
    expect(tagAFL("Port Melbourne reserves win")).toEqual([]);
    expect(tagAFL("Crows and Power: Showdown date set")).toEqual(["1", "13"]);
  });
});

describe("merging", () => {
  const item = (id: string, published: string): NewsItem => ({
    id, source: "X", title: id, url: null, published, mayContainResult: false, tags: [],
  });

  it("keeps first-seen dates and caps the list", () => {
    const previous = [item("a", "2026-10-18T00:00:00.000Z")];
    const fresh = [item("a", "2026-10-19T00:00:00.000Z"), item("b", "2026-10-19T01:00:00.000Z"), item("c", "2026-10-17T00:00:00.000Z")];
    const merged = mergeItems(previous, fresh, 2);
    expect(merged.map((i) => i.id)).toEqual(["b", "a"]);
    expect(merged[1].published).toBe("2026-10-18T00:00:00.000Z");
  });
});
