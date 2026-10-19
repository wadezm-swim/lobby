/**
 * Lobby's cloud. Two functions:
 *
 * - sportsTick: every 15 minutes, refreshes whatever is due (F1 from Jolpica,
 *   AFL from Squiggle, the news wire) and writes it to Firestore for the app.
 * - captureToNotion: when the app saves a capture, files it in his Notion inbox.
 *
 * API keys live here as Firebase secrets and never reach the app.
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { AFLDoc, gameWindow } from "./afl";
import { F1Weekend, isRaceWeekend, latestResultSessionStart } from "./f1";
import { mergeItems, NewsItem } from "./news";
import { CaptureDoc, sendToNotion } from "./notion";
import { dueTasks, SyncState, Task } from "./schedule";
import { fetchAFL, fetchAFLModels, fetchAFLNews, fetchF1, fetchF1News } from "./sync";

initializeApp();

// Sydney is the closest region to Adelaide. Firestore must be created there too.
setGlobalOptions({ region: "australia-southeast1", maxInstances: 2, memory: "256MiB" });

const NOTION_TOKEN = defineSecret("NOTION_TOKEN");
const NOTION_INBOX_DATABASE_ID = defineString("NOTION_INBOX_DATABASE_ID", {
  description: "The Notion database captures land in (the 32 characters in its link)",
});
const SQUIGGLE_CONTACT = defineString("SQUIGGLE_CONTACT", {
  description: "An email address Squiggle can reach you on. It goes in the User-Agent, as Squiggle asks.",
});

const NEWS_LIMIT = 60;

export const sportsTick = onSchedule(
  { schedule: "every 15 minutes", timeZone: "Australia/Adelaide", timeoutSeconds: 120 },
  async () => {
    const db = getFirestore();
    const now = new Date();
    const stateRef = db.doc("system/sync");
    const state = ((await stateRef.get()).data() ?? {}) as SyncState;

    const calendar = (await db.doc("sports/f1Calendar").get()).data() as { weekends: F1Weekend[] } | undefined;
    const afl = (await db.doc("sports/afl").get()).data() as AFLDoc | undefined;
    const due = dueTasks(state, now, {
      // With nothing cached yet, assume the busy case so the first run fills everything.
      raceWeekend: calendar ? isRaceWeekend(calendar.weekends, now) : true,
      aflGameWindow: afl ? gameWindow(afl, now) : true,
    });

    const run: Record<Task, () => Promise<void>> = {
      f1: async () => {
        const f1 = await fetchF1(now);
        const updatedAt = now.toISOString();
        await Promise.all([
          db.doc("sports/f1Calendar").set({ season: f1.season, weekends: f1.weekends, updatedAt }),
          // Standings and results are spoilers: the app hides them until he's watched.
          db.doc("sports/f1Standings").set({ ...f1.standings, updatedAt }),
          db.doc("sports/f1Latest").set({ race: f1.latestRace, qualifying: f1.latestQualifying, updatedAt }),
        ]);
      },
      afl: async () => {
        const doc = await fetchAFL(now, SQUIGGLE_CONTACT.value(), afl?.models ?? null);
        await db.doc("sports/afl").set({ ...doc, updatedAt: now.toISOString() });
      },
      aflTips: async () => {
        const models = await fetchAFLModels(now, SQUIGGLE_CONTACT.value());
        await db.doc("sports/afl").set({ models, modelsUpdatedAt: now.toISOString() }, { merge: true });
      },
      news: async () => {
        const [weekendsDoc, standingsDoc] = await Promise.all([
          db.doc("sports/f1Calendar").get(),
          db.doc("sports/f1Standings").get(),
        ]);
        const weekends = (weekendsDoc.data()?.weekends ?? []) as F1Weekend[];
        const drivers = standingsDoc.data()?.drivers ?? [];
        const [f1News, aflNews] = await Promise.all([
          fetchF1News(now, latestResultSessionStart(weekends, now), drivers),
          fetchAFLNews(now),
        ]);
        for (const [path, report] of [["news/f1", f1News], ["news/afl", aflNews]] as const) {
          const ref = db.doc(path);
          const previous = ((await ref.get()).data()?.items ?? []) as NewsItem[];
          await ref.set({ items: mergeItems(previous, report.items, NEWS_LIMIT), failedFeeds: report.failed, updatedAt: now.toISOString() });
          if (report.failed.length) logger.warn(`Feeds that didn't answer: ${report.failed.join(", ")}`);
        }
      },
    };

    for (const task of due) {
      try {
        await run[task]();
        state[task] = now.toISOString();
      } catch (error) {
        // One feed failing shouldn't stop the others. It retries next tick.
        logger.error(`${task} refresh failed`, error);
      }
    }
    await stateRef.set(state, { merge: true });
    logger.info(`Refreshed: ${due.join(", ") || "nothing due"}`);
  },
);

export const captureToNotion = onDocumentCreated(
  { document: "users/{uid}/captures/{captureID}", secrets: [NOTION_TOKEN] },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    const capture = snapshot.data() as CaptureDoc;
    try {
      const pageID = await sendToNotion(capture, NOTION_TOKEN.value(), NOTION_INBOX_DATABASE_ID.value());
      await snapshot.ref.update(pageID ? { status: "sent", notionPageID: pageID } : { status: "kept" });
    } catch (error) {
      logger.error("Capture didn't reach Notion", error);
      await snapshot.ref.update({ status: "failed", error: String(error).slice(0, 300) });
    }
  },
);
