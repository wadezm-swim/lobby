# Lobby: build brief

This file is the handover from the planning chat (19 October 2026). Everything in it is signed off by Wade unless it sits under "Still open". Read it in full before writing code. The `design/` folder holds every agreed screen as HTML mock-ups: open them in a browser to see layout, copy and colours. They use sample data in [brackets].

## Who this is for

- **Owner:** Wade, Adelaide (Australia/Adelaide time zone). Manager of Sport Experience & Innovation at SwimmingSA. Not a developer, so explain steps in plain words, one at a time, and tell him exactly what to click.
- **Machine:** his personal Mac. Builds happen on that Mac with Xcode. Apple Developer Program (A$149/yr) is joined at the phone stage, not before.
- **Hard rules:**
  - No workarounds that break SwimmingSA IT policy: no forwarding work mail to Gmail, no scraping Outlook web, no copying work mail into personal apps.
  - Ask before anything that costs money or creates an account.
  - API keys live only in the cloud (Firebase secrets), never in the app.
  - No em dashes and no "not just X, but Y" phrasing in any app copy. Tone: grounded, observational, slightly cheeky.

## What Lobby is

A personal always-on app for Mac, iPhone and iPad. Work is up front in work hours, his interests up front after hours. It fills itself from his accounts so he almost never types. The only manual input is a quick capture (typed or voice).

## Stack (signed off)

| Part | Choice |
|---|---|
| App | Native SwiftUI multiplatform: macOS first, then iOS and iPadOS. MenuBarExtra for the menu bar glance. Global hotkey Option+Space opens the concierge. Note: Option+Space normally types a non-breaking space, so the hotkey overrides that. |
| Cloud | Firebase on the Blaze plan with a A$5 budget alert. Firestore for data, Firebase Auth (Sign in with Apple), Cloud Functions (TypeScript) on schedules for every external fetch, and FCM/APNs for notifications. |
| Health | HealthKit on iPhone only (not available on macOS). Health numbers stay with Apple: sync summaries via CloudKit private database, never Firebase. |
| AI | Anthropic API, called only from Cloud Functions. Use `claude-haiku-5-5` for classifying and short text, `claude-sonnet-5-5` for drafts. Expect about A$3–7 a month. |
| Widgets etc. | WidgetKit (home and lock screen), ActivityKit Live Activities (phone stage). |
| Look | Light by day, dark at night, switching on its own. The Sports room is always dark. |

## Design tokens (from the design files)

- **Day:** canvas `#ECECEC`, cards `#FFFFFF`, ink `#0E0E0E`, muted `#5F5F64`, accent lime `#D4FF3F`. Pastels: lilac `#E7D9FF`, sky `#CFE7FF`, mint `#CDF5DC`, peach `#FFE1CC`. Card radius 28, pills fully round. Font: Urbanist.
- **Night:** background `#000000`, cards `#141414`.
- **Room themes:**
  - F1: red `#E10600`, font Titillium Web. Team colour drives glows, for example McLaren `#FF8000`.
  - Port Adelaide teal: `#00A9C5` (approximate).
  - Fleet: Qantas red `#E40000` / `#B80000`, fonts Plus Jakarta Sans and JetBrains Mono for regos.

## Rooms and features (all signed off)

**Home.** Starts with "Looking forward to" (the nearest good thing coming up). Then:
- next meeting
- top three
- sports countdown
- fleet progress
- next trip
- body summary
- the daily three-question quiz from his own world (aviation, F1, Port), with a streak

Toggle: Work / Off duty only (no "Meet day" mode).

**Work.** Today's meetings, top three, waiting on, Notion projects, a Friday 3pm weekly log written for him. Work calendar access, in order of preference:
1. Microsoft 365 Graph delegated read, if IT approves (Calendars.Read, Mail.ReadBasic)
2. Apple Calendar via EventKit
3. A published ICS link
4. One-tap captures

**Sports** (dark):
- **F1:** pick any of the 11 teams (McLaren first). Race-week and off-season states. Sessions in Adelaide time with alarms. A news wire with his team first. His Notion Armchair Guide.
- **AFL:** pick any club (Port Adelaide first). Fixtures, live scores and ladder, plus Port news.
- **Spoiler shield:** hides race results, standings, widgets, notifications and result headlines everywhere in Lobby until he taps "I've watched it".
- **Tipping:** AFL "Beat the models" (his tips scored against Squiggle's computer models) and F1 qualifying top-three predictions, scored after the shield drops.

**Fleet** (Qantas red):
- Rego bingo for every Qantas aircraft, each marked not yet / spotted / flown.
- Wildcard airlines (Qatar, Emirates) can be imported.
- Rego lookup with photo, by typing or pointing the camera.
- "What's over Adelaide right now", with a ping when a watchlist rego is nearby.
- Rego on boarding: on flight day, show the aircraft rego and whether it's a new square.
- Flight log built from booking emails.
- No scanning his photo library for regos.

**Trips** (Tripsy plus Flighty):
- Bookings parsed from personal Gmail, with a trip timeline.
- Flight cards with gate and delays.
- Documents (passport expiry check).
- Ideas board: add a place or link, Lobby auto-fills hours, area and photos, then he drags it onto a day.
- **Today away** view on trip days, which replaces Home: weather, UV, sunrise and sunset, local and Adelaide time, next stop with a leave-by time and travel time, the exchange rate, and typical weather for planning ahead.
- No group expenses or spend tracking.

**Brand.** From Tim Duggan's books Cult Status, Killer Thinking and Work Backwards:
- **Superpower line:** toggle between Both / Sport delivery / Barefoot Luxury.
- **Your week in four slices:** work, relationships, mind and body, out of 112 waking hours, with 28 each as the ideal. Estimated from calendars, Apple Health and listening time.
- **After-hours work:** from the work calendar, with a segmenter/integrator setting.
- **Anchor values:** three of them, plus a Friday question.
- **Ideas lab:** every capture gets a "problem's therapist" step, a K.I.L.L.E.R. score out of 6 (Kind, Impactful, Loved, Lasting, Easy, Repeatable) and one next step. Buttons: "Make it a Notion project" or "Park it".
- **This week's story:** Friday suggestion from calendar, photos and Notion, saved to the story bank.
- **Also in Brand:**
  - habits that tick themselves
  - goals with progress
  - voice check
  - aesthetics
  - Mind, showing Spotify listening
  - body
  - story bank
  - presence (Instagram, Threads, LinkedIn monthly export)
  - proof and brand check

**Always on:**
- Menu bar glance: next up, top three, countdown, waiting on, Spotify now playing, capture box.
- Option+Space concierge for capture and search, saving to Notion.
- Widgets, plus Live Activities on race, match and travel days. F1 live timing is a later paid step.

## Out (do not build)

- NHL and the royal calendar
- Birthday reminders and playlist generation
- TV, trams, cocktails and LEGO
- Kindle and Readwise
- Trip offline pack, spend tracker, translation and packing list
- Group expenses, scanning photos for regos, and a Meet day mode
- Instagram "fans not followers" metrics

Reward seat alerts (seats.aero) are parked.

## Data sources

| Source | Use | Notes |
|---|---|---|
| Jolpica `https://api.jolpi.ca/ergast/f1/` | F1 calendar, results, standings | Free. Cache it. |
| OpenF1 `https://api.openf1.org/v1/` | Sessions, laps, positions, team radio (finished sessions) | Free tier for historical data. Live tier (€9.90/mo, about A$16) is a later decision. |
| F1 news RSS | News wire | Feeds: `formula1.com/en/latest/all.xml`, `fia.com/rss/press-release`, `motorsport.com/rss/f1/news/`, `autosport.com/rss/f1/news/`, `racefans.net/feed/`, `the-race.com/rss/`. Show headline and link only. |
| Squiggle `https://api.squiggle.com.au/` | AFL fixtures, ladder (`q=standings`), tips/models, live event stream | Free. Port Adelaide is team 13. Send a descriptive User-Agent with a contact email. Fetch server-side and cache. |
| AFL.com.au RSS | Port news | Filter to Port Adelaide. There is no club RSS feed. |
| adsbdb `api.adsbdb.com`, hexdb `hexdb.io` | Rego lookup | Free |
| Planespotters photo API | Aircraft photos | Free. Must credit the photographer. Cache 24h. |
| OpenSky states API | Live aircraft over Adelaide | Free, OAuth2, daily credit limits |
| FlightAware AeroAPI personal | Flight status, rego on boarding | US$5/mo free credit. Confirm it covers his trips. Rego often assigned close to departure. |
| WeatherKit | Weather, UV, sunrise | Comes with the Apple developer program |
| Frankfurter | Exchange rates | Free |
| Apple Maps Server API, Google Places (New) | Trip idea auto-fill | Free allowances. Use field masks on Google. |
| Spotify Web API | Now playing, recently played, top items, saved shows, playback control | Development mode, Premium owner. Recently played may be tracks only. No recommendations endpoint. |
| Notion API | Capture, projects, Armchair Guides | |
| Gmail and Google Calendar | Bookings, flight history | Publish the Google OAuth app to production (unverified, personal use) so refresh tokens don't expire after 7 days. |

## Build order

1. **Phase 1, Mac:**
   - Firebase project.
   - Mac app shell: Home, menu bar glance, Option+Space concierge saving to Notion.
   - Work room on whichever calendar route works.
   - Sports room with Jolpica, Squiggle and the news wire through scheduled Cloud Functions, plus the spoiler shield.
   - Start with sample data, then switch each card to real data one at a time.
   - Wade then uses it for a week and gives feedback.
2. **Phase 2:** join the Apple Developer Program, then iPhone and iPad apps, Apple Health, widgets, notifications, Live Activities.
3. **Phase 3:** Trips.
4. **Phase 4:** Fleet.
5. **Phase 5:** Brand.

## Costs (year one, AUD)

| Item | Cost |
|---|---|
| Apple Developer Program | A$149, at Phase 2 |
| Claude API | About A$3–7 a month |
| Firebase, feeds, Spotify (his Premium), Xcode | A$0 |

That comes to about A$185–235 a year in total. Card FX fees may add 2–3% on USD charges.

## Still open

- **Name:** keep "Lobby"? This is the working name.
- **Accent colour:** lime (current) or electric blue.
- **Work calendar:** the SwimmingSA IT request for read-only calendar and email headers.
- **Instagram:** is Barefoot Luxury a Creator or Business account? Needed for stats.
- **Flight data provider:** to confirm at Trips.

## Status (19 October 2026, after the second build session)

Read `docs/SETUP.md` for how Wade gets it running: browser and Finder only, no Xcode, no Terminal. Everything below is on branch `claude/new-session-x2y50h`; `main` stays empty until Wade says merge. Wade said yes to Blaze on 19 October.

### Built

- **`LobbyCore/`**: plain Swift, no UI, 41 tests, runs on Linux and Mac (`swift test --package-path LobbyCore`). Adelaide time and formatting, sunrise and sunset for day/night, work hours and the Work/Off duty override, meetings and next up, the weekly log timing, the spoiler shield, qualifying picks scoring, the daily three and streak, capture parsing, project matching, sample data, the F1 room's content, and `Cloud.*`: the shapes the functions write to Firestore plus their mapping into the app's models (including the AFL card written for his club: live score, next game, last result, off-season opener).
- **`Lobby/` + `Lobby.xcodeproj`**: the Mac app, macOS 14+, bundle id `com.wadezm.Lobby`. Home (card order flips with the mode), Work, Sports (11 F1 teams, 18 AFL clubs, shield, picks), menu bar glance, Option+Space concierge. Fleet, Trips and Brand are honest placeholders. Urbanist and Titillium Web bundled (SIL OFL). Firebase: `firebase-ios-sdk` 13.x (FirebaseFirestore only). The app reads `GoogleService-Info.plist` from `~/Library/Application Support/Lobby/`, never from the bundle or the repo. With it, Firestore listeners lay live data over the sample snapshot one document at a time, no sign-in needed. Captures queue on the Mac until Phase 2. A launch diary at `~/Library/Application Support/Lobby/launch.log` records each start.
- **`functions/`**: Cloud Functions in TypeScript, 34 tests on trimmed captures of the real feeds, `npm run smoke` against the live APIs. `sportsTick` every 15 minutes refreshes what's due (Jolpica, Squiggle, six F1 feeds plus AFL.com.au, headlines tagged and flagged for spoilers); `captureToNotion` files captures in his Notion inbox. Region `australia-southeast1`.
- **GitHub does the building and deploying.** `CI` builds the app on a Mac runner, ad-hoc signs it and publishes `Lobby.zip` at `https://github.com/wadezm-swim/lobby/releases/download/latest/Lobby.zip` on every push. `Deploy cloud` pushes functions and Firestore rules with the repo's secrets and stays quiet until they exist. `Set Notion token` copies `NOTION_TOKEN` into Secret Manager once.

### Live or sample, once Firebase is on

- **Live (as of 19 October, project `lobby-6b45c`, first fetch 06:15 UTC):** F1 calendar, countdowns and sessions in Adelaide time, standings and the latest top three (hidden behind the shield), the F1 news wire, the AFL card and news wire.
- **Parked until Phase 2 signs the app:** captures to Notion (`captureToNotion` is deployed and waiting).
- **Still sample:** meetings, top three, waiting on, projects, trips, body, fleet, now playing, the quiz bank. Each waits on its own source: the work calendar route, Notion projects, Gmail, HealthKit (Phase 2), Spotify.

### Firestore layout the cloud writes

`sports/f1Calendar` (season, weekends with UTC sessions), `sports/f1Standings`, `sports/f1Latest` (race and qualifying top three), `sports/afl` (ladder, live, upcoming, recent, models), `news/f1` and `news/afl` (up to 60 items each with `tags` and `mayContainResult`), `system/sync`. Once signed in (Phase 2) the app writes `users/{uid}/captures/{id}` and the cloud sets its `status` to `sent`, `kept` or `failed`.

### Secrets the workflows expect

Repo Settings > Secrets and variables > Actions: `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT` (the JSON key of an Editor service account), `NOTION_TOKEN`, `NOTION_INBOX_DATABASE_ID`, `SQUIGGLE_CONTACT`. The functions' two params land in `functions/.env` at deploy time, which git ignores.

### Decisions made during the build (not in the brief above; shout if any is wrong)

- No Xcode on Wade's Mac. CI builds the app and deploys the cloud; his side is browser clicks and one Finder drag.
- Sign-in for Phase 1 is email and password. Sign in with Apple needs the paid developer program (Phase 2); email link sign-in on Apple platforms depended on Firebase Dynamic Links, which shut down in 2025.
- The app is ad-hoc signed, so macOS wants Open Anyway once per download, and keychain entries don't carry across downloads: expect to sign in again after an update until the app is properly signed at Phase 2.
- Work hours for the automatic mode are weekdays 8:30am to 5:00pm. The toggle overrides until the next natural change.
- Day/night follows Adelaide sunrise and sunset, computed in the app.
- The spoiler shield goes up when a session with a result starts. "I've watched it" covers sessions that have started; when the race starts the shield goes back up.
- Result headlines are flagged in the cloud by a deliberately jumpy word list, only for headlines published after the latest result session began. A `claude-haiku-5-5` classifier can replace it later. The news wire shows the newest eight per sport.
- Qualifying picks lock when Q1 starts: 2 points for the right driver in the right slot, 1 for a top-three driver in the wrong slot.
- The daily three draws one aviation, one F1 and one Port question from a starter bank of nine. A day counts toward the streak only if every answer was right.
- "Looking forward to" prefers a trip within four months, otherwise the nearest thing.
- Captures save on the Mac (`~/Library/Application Support/Lobby/captures.json`) and upload when signed in. Reminders stay on the Mac and never go to Notion.
- One Cloud Scheduler job (the free tier allows three); the other two are kept for the morning top three and the Friday log.
- Firestore must be created in `australia-southeast1` to match the functions.

### Next steps, in order

1. Done on 19 October: Firebase project, Blaze (Google's 90-day trial credit applies), Firestore in Sydney, Notion integration, five secrets, both workflows green, first fetch landed. The app runs on Wade's personal Mac with the plist in place.
2. Wade lives with it for a week and gives feedback.
3. Work calendar on whichever route IT allows (EventKit is quickest if he subscribes to the work calendar in Apple Calendar). Spotify in the glance. Notion projects into the Work room. Morning top three and the Friday 3pm log as functions (`claude-sonnet-5-5` for the log).
4. Phase 2 after he's lived with it for a week.

### Still open

- From the brief: the name, the accent colour, the SwimmingSA IT request, the Instagram account type, the flight data provider.
- Merge to `main` when Wade is happy.
