/**
 * Runs the real fetches against the live APIs, no Firebase needed, and prints
 * what the app would see. Run with `npm run smoke`.
 */

import { latestResultSessionStart } from "./f1";
import { fetchAFL, fetchAFLModels, fetchAFLNews, fetchF1, fetchF1News } from "./sync";

async function main() {
  const now = new Date();
  const contact = process.env.SQUIGGLE_CONTACT ?? "lobby-smoke-test@example.invalid";

  console.log("F1 from Jolpica");
  const f1 = await fetchF1(now);
  const next = f1.weekends.find((w) => new Date(w.sessions.at(-1)?.start ?? 0) > now);
  console.log(`  season ${f1.season}, ${f1.weekends.length} weekends, next: ${next?.name ?? "none"} (${next?.sessions.at(-1)?.start})`);
  console.log(`  standings round ${f1.standings.round}, leader ${f1.standings.drivers[0]?.driver} ${f1.standings.drivers[0]?.points} pts`);
  console.log(`  latest race: ${f1.latestRace?.raceName}, qualifying top three hidden by the app until watched`);

  console.log("AFL from Squiggle");
  const afl = await fetchAFL(now, contact, null);
  console.log(`  ${afl.year} ${afl.phase}, ladder ${afl.ladder.length} rows, Port rank ${afl.ladder.find((r) => r.teamID === 13)?.rank}`);
  console.log(`  live ${afl.live.length}, upcoming ${afl.upcoming.length}, recent ${afl.recent.length} (${afl.recent[0]?.roundName ?? "none"})`);
  const models = await fetchAFLModels(now, contact);
  console.log(`  ${models.length} computer models, best: ${models[0]?.source} ${models[0]?.correct}/${models[0]?.tipped}`);

  console.log("News wire");
  const f1News = await fetchF1News(now, latestResultSessionStart(f1.weekends, now), f1.standings.drivers);
  console.log(`  F1: ${f1News.items.length} headlines, ${f1News.items.filter((i) => i.mayContainResult).length} held by the shield, failed feeds: ${f1News.failed.join(", ") || "none"}`);
  for (const item of f1News.items.filter((i) => i.tags.includes("mclaren")).slice(0, 3)) {
    console.log(`    McLaren · ${item.source}: ${item.title}`);
  }
  const aflNews = await fetchAFLNews(now);
  console.log(`  AFL: ${aflNews.items.length} headlines, ${aflNews.items.filter((i) => i.tags.includes("13")).length} about Port, failed feeds: ${aflNews.failed.join(", ") || "none"}`);
  for (const item of aflNews.items.filter((i) => i.tags.includes("13")).slice(0, 3)) {
    console.log(`    Port · ${item.title}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
