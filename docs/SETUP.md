# Running Lobby on your Mac

Plain steps, one at a time. Nothing here costs money until the Firebase part, and that section says so before you get there.

## Part 1: See it running (about 20 minutes, A$0)

### 1. Install Xcode

1. Open the **App Store** on your Mac.
2. Search for **Xcode** and click **Get**, then **Install**. It's free and large (about 12 GB), so give it time.
3. When it's done, open **Xcode** once. Click **Agree** on the licence. If it offers to install extra components, click **Install** and let it finish.

### 2. Get the code

1. In Xcode, from the welcome window, click **Clone Git Repository...** (or the menu **Integrate > Clone...**).
2. Paste this into the search box at the top: `https://github.com/wadezm-swim/lobby`
3. Click **Clone**.
4. When it asks which branch, pick **claude/new-session-x2y50h**. (If you'd rather it live on `main`, say so and I'll open a pull request and merge it.)
5. Choose a folder to keep it in, for example **Documents**, and click **Clone**.

Xcode opens the project. On the left you'll see folders called **Lobby** and **LobbyCore**.

### 3. Press Play

1. At the top of the window, next to the Play button, check it says **Lobby** and **My Mac**. If it says anything else, click it and choose those.
2. Press the **Play** button (or hold **Command** and press **R**).
3. The first build takes a minute or two. The Lobby window opens on its own.

**If Xcode shows a red error about signing:** click **Lobby** at the top of the left-hand list (the blue icon), then the **Signing & Capabilities** tab. Next to **Team**, choose **Add an Account...**, sign in with your Apple ID, then pick the entry that says **(Personal Team)**. Press Play again. A free Apple ID is enough to run it on your own Mac.

### 4. What you'll see

- **The window.** Home, Work and Sports down the left. Fleet, Trips and Brand say what's coming in their phase.
- **The menu bar.** A small dot up near the clock with the next thing on it. Click it for the glance.
- **Option+Space** from anywhere opens the concierge. Type something like `chase officials roster thursday` and press Return. Up and down arrows choose, Esc closes.
- **Light and dark** switch on their own at Adelaide sunrise and sunset. Sports is always dark.
- **Work / Off duty** picks itself (weekdays 8:30 to 5). Tap the toggle to override it until the next change.

Everything says **sample data** because it is. The meetings, top three, trips and body numbers are the ones from the mock-ups, with times built around today so the countdowns tick. The F1 and AFL teams, the spoiler shield, the qualifying picks, the daily three and captures all work for real; they just don't have live feeds behind them yet.

### 5. Things that are real already

- Captures (concierge, menu bar, Work room) are saved on your Mac in `~/Library/Application Support/Lobby/captures.json`. Once the cloud is on they'll go to Notion from there.
- Your F1 team, AFL club, spoiler shield state, quiz answers and qualifying picks are remembered between launches.
- Closing the window leaves Lobby in the menu bar. To quit properly: click the Lobby window, then **Lobby > Quit Lobby** in the top menu (or Command-Q).

## Part 2: The cloud (ask before this: it creates a Google Cloud project and needs a card on file)

The cloud is what fills Sports with real F1, AFL and news, and files captures in Notion. It runs on Firebase. At Lobby's usage it should sit at A$0 a month, but the Blaze plan is pay-as-you-go, so step 2 sets a A$5 alert.

**Don't start this part until you've said yes to it.** When you do, here are the steps.

### 1. Create the Firebase project (A$0)

1. Go to **console.firebase.google.com** and sign in with your personal Google account.
2. Click **Create a project**. Name it **Lobby**. Turn **off** Google Analytics. Click **Create**.

### 2. Blaze plan and the budget alert

1. In the project, bottom left, click **Upgrade** (or the **Spark** label) and choose **Blaze**.
2. It asks for a billing account and a card. Set up billing.
3. When it offers a **budget**, set it to **5 AUD**. If it doesn't offer one, go to **console.cloud.google.com**, open **Billing > Budgets & alerts**, and create one for A$5 with email alerts.

### 3. Firestore

1. Left menu: **Build > Firestore Database**, then **Create database**.
2. Location: **australia-southeast1 (Sydney)**. This can't be changed later and the functions are set to that region.
3. Choose **Production mode**. Click **Create**. (The rules in this repo replace the defaults when you deploy.)

### 4. Tell the app about the project

1. Click the **gear** next to Project Overview, then **Project settings**.
2. Under **Your apps**, click the **Apple** icon (it may say iOS+).
3. Bundle ID: `com.wadezm.Lobby`. Nickname: **Lobby Mac**. Click **Register app**.
4. Click **Download GoogleService-Info.plist**.
5. In Finder, drag that file into the **Lobby** folder inside the project (the one with `App`, `Design`, `Rooms` in it). Git ignores this file on purpose; it's yours and stays on your Mac.
6. Skip the "Add Firebase SDK" steps on that page. I'll wire the app to the cloud as the next build step once the project exists.

### 5. Install the command-line tools (A$0)

1. Go to **nodejs.org** and download the **LTS** version (22). Open the installer and click through it.
2. Open **Terminal** (Spotlight: press Command-Space, type Terminal, press Return).
3. Paste this line and press Return: `npm install -g firebase-tools`
4. Then: `firebase login`. A browser window opens; sign in with the same Google account.

### 6. Notion

1. Go to **notion.so/my-integrations** (signed in to Notion).
2. Click **New integration**. Name: **Lobby**. Pick your workspace. Click **Submit**.
3. On the next page click **Show** next to **Internal Integration Secret**, then **Copy**. Keep it somewhere safe for a minute. Never paste it into the app or into a file in the project.
4. In Notion, open the database you want captures to land in (your inbox). Click the **...** in the top right, then **Connections**, then **Connect to** and choose **Lobby**.
5. Copy the database's ID from your browser's address bar: it's the 32 letters and numbers after the last `/` and before the `?`.

The database needs a title column (every database has one). If it also has a date column called **Due** (or anything with "due" or "date" in the name), captures with a day in them fill it. Lobby works either way.

### 7. Deploy

In Terminal, one line at a time:

```
cd ~/Documents/lobby
firebase use --add
```

Pick the **Lobby** project and press Return for the alias. Then:

```
firebase functions:secrets:set NOTION_TOKEN
```

Paste the Notion secret from step 6 and press Return. Then:

```
cd functions
npm install
npm run deploy
```

The first time, it asks two questions: the Notion database ID (paste it) and an email address for Squiggle's User-Agent (they ask for a contact; your personal email is fine). It remembers both in `functions/.env`, which git ignores.

Deploying takes a few minutes. When it finishes, the sports feed refreshes every 15 minutes on its own and you can watch the data arrive in **Firestore Database** in the console.

## If something goes wrong

- **Xcode says "No such module LobbyCore".** Click **File > Packages > Resolve Package Versions**, then build again.
- **Option+Space does nothing.** Another app holds that shortcut (Spotlight if you've changed it, or Raycast or Alfred). Lobby shows a note at the bottom of the window when that happens. The search box on Home still opens the concierge.
- **The build fails after you've changed nothing.** Clean it: hold **Shift** and press **Command-K**, then press Play again.
- **Anything else.** Copy the red text and send it to me.
