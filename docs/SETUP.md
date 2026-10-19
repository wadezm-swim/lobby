# Setting up Lobby

Everything here happens in a browser or Finder. No Xcode, no Terminal. Do the parts in order; each one says what it costs before you start.

## Part 1: Get the app on your Mac (5 minutes, A$0)

GitHub builds Lobby every time the code changes and keeps the latest copy at one link.

1. Download **https://github.com/wadezm-swim/lobby/releases/download/latest/Lobby.zip**
2. In Finder, open **Downloads**, double-click **Lobby.zip**. You get **Lobby.app**.
3. Drag **Lobby** into your **Applications** folder.
4. Double-click it. macOS will say it can't open it because it's from an unidentified developer. Click **Done** (or **OK**).
5. Open **System Settings > Privacy & Security**. Scroll down. Next to the line about Lobby being blocked, click **Open Anyway**. Confirm with your password or Touch ID.
6. Lobby opens. That's the only time you'll see that prompt for this copy.

**To update later:** download the same link again, unzip, drag the new Lobby over the old one in Applications and choose **Replace**. The Open Anyway step repeats because it's a new file.

### What you'll see

- **The window.** Home, Work and Sports down the left. Fleet, Trips and Brand say what's coming in their phase.
- **The menu bar.** A dot near the clock with the next thing on it. Click it for the glance.
- **Option+Space** from anywhere opens the concierge. Type `chase officials roster thursday` and press Return. Arrows choose, Esc closes.
- **Light and dark** switch at Adelaide sunrise and sunset. Sports is always dark.
- **Work / Off duty** picks itself (weekdays 8:30 to 5). Tap the toggle to override until the next change.

Until Part 2 is done, everything says **sample data**. The teams, spoiler shield, picks, daily three and captures are real; the feeds behind them aren't yet.

Closing the window leaves Lobby in the menu bar. To quit: click the window, then **Lobby > Quit Lobby** (Command-Q).

## Part 2: Firebase (30 minutes, needs a card, expect A$0 a month)

Firebase is the cloud that fills Sports with live F1, AFL and news and files captures in Notion. The **Blaze** plan is pay-as-you-go above a free allowance Lobby stays well inside. Step 2 sets a A$5 alert so nothing can run up quietly.

### 1. Create the project

1. Go to **console.firebase.google.com** and sign in with your personal Google account.
2. Click **Create a project** (it may say **Get started with a Firebase project**).
3. Name: **Lobby**. Click **Continue**.
4. If it offers **Gemini in Firebase**, leave it off. Turn **off** Google Analytics. Click **Create project**, then **Continue** when it's ready.
5. Write down the **project ID**. It's in the browser's address bar after `/project/`, something like `lobby-6b45c`, and also on **Settings > Project settings** in the left list. You'll paste it into GitHub later.

### 2. Blaze and the budget alert

1. Bottom left of the console, click **Upgrade** (or the word **Spark**).
2. Choose **Blaze (Pay as you go)**. Create a billing account when asked and add your card.
3. When it offers to set a **budget**, enter **5** AUD and turn alerts on. If it doesn't offer, finish the upgrade, then open **console.cloud.google.com**, choose the Lobby project at the top, menu **Billing > Budgets & alerts > Create budget**, amount 5, and leave the email alerts ticked.

### 3. Firestore (the database)

1. Back in the Firebase console, left list under **Product categories**, click **Databases & Storage**, then **Firestore Database**. (The search box at the top, "Search for products", also finds anything by name.)
2. Click **Create database**.
3. If it asks **Standard** or **Enterprise** edition, choose **Standard**. Leave the database ID as **(default)**.
4. Location: **australia-southeast1 (Sydney)**. This can't be changed later and the cloud code is set to it. Click **Next**.
5. Choose **Start in production mode**. Click **Create**.

### 4. Sign-in

1. Left list under **Product categories**, click **Security**, then **Authentication**. Click **Get started**.
2. Under **Sign-in method**, click **Email/Password**, switch the first toggle **on**, click **Save**.
3. Click the **Users** tab, then **Add user**. Enter your email and make up a password. This is the password you'll type into Lobby once. Click **Add user**.

### 5. Tell the app about the project

1. Left list, **Settings** (the gear), then **Project settings**. Scroll to **Your apps**, click the **Apple** icon (it may say **iOS+**).
2. Apple bundle ID: `com.wadezm.Lobby`. App nickname: **Lobby Mac**. Click **Register app**.
3. Click **Download GoogleService-Info.plist**. Click **Next** through the rest, then **Continue to console**. Skip the SDK steps; that's done.
4. In Finder, click the **Go** menu, hold **Option** and click **Library**. Open **Application Support**. If there's no **Lobby** folder, make one (**File > New Folder**, name it `Lobby`).
5. Drag **GoogleService-Info.plist** from Downloads into that **Lobby** folder.

Next time Lobby opens, it finds that file and asks you to sign in with the email and password from step 4.

### 6. A key for GitHub to deploy with

GitHub needs permission to put the cloud code into your project. This makes a key for that.

1. Go to **console.cloud.google.com**. Make sure **Lobby** is the project selected at the top.
2. Menu (three lines, top left) **IAM & Admin > Service Accounts**.
3. Click **Create service account**. Name: `lobby-deploy`. Click **Create and continue**.
4. Under **Select a role**, type `Editor` and choose **Basic > Editor**. Click **Continue**, then **Done**.
5. In the list, click **lobby-deploy**. Open the **Keys** tab. Click **Add key > Create new key**. Leave **JSON** selected, click **Create**. A file downloads. Click **Close**.
6. Keep that file for step 8, then delete it from Downloads. It gives full access to the project, so it should live in GitHub's secrets and nowhere else.

### 7. Notion

1. Go to **notion.so/my-integrations** (signed in to Notion).
2. Click **New integration**. Name: **Lobby**. Pick your workspace. Click **Submit**.
3. Click **Show** next to **Internal Integration Secret**, then **Copy**. You'll paste it in step 8.
4. In Notion, open the database captures should land in (your inbox). If it sits inside a page, hover over it and click **Open as full page** (the arrows icon) so it fills the window.
5. Click the **...** top right, **Connections**, **Connect to**, choose **Lobby**.
6. Copy the database's ID from your browser's address bar: the 32 letters and numbers after the last `/` and before the `?`.

If the database has a date column with "due" or "date" in its name, captures with a day in them fill it in. It works either way.

### 8. Put the five secrets into GitHub

1. Go to **github.com/wadezm-swim/lobby/settings/secrets/actions**.
2. For each row below: click **New repository secret**, type the **Name** exactly, paste the **Value**, click **Add secret**.

| Name | Value |
|---|---|
| `FIREBASE_PROJECT_ID` | The project ID from step 1 (like `lobby-4f2a1`) |
| `FIREBASE_SERVICE_ACCOUNT` | Open the JSON file from step 6 in **TextEdit**, **Edit > Select All**, **Copy**, paste the whole thing |
| `NOTION_TOKEN` | The integration secret from step 7 |
| `NOTION_INBOX_DATABASE_ID` | The 32-character database ID from step 7 |
| `SQUIGGLE_CONTACT` | Your personal email. Squiggle (the AFL feed) asks for a contact; it only ever goes to them |

### 9. Deploy

1. Go to **github.com/wadezm-swim/lobby/actions**.
2. In the left list click **Set Notion token**, then the **Run workflow** button on the right, then the green **Run workflow**. Wait for the tick (about a minute).
3. Then click **Deploy cloud** in the left list, **Run workflow**, **Run workflow**. This one takes five to ten minutes the first time: Google switches on a handful of services.
4. Green tick: done. The sports feed refreshes itself every 15 minutes from now on. You can watch the data appear in the Firebase console under **Firestore Database**.

**If the first deploy fails** with words like "service agent" or "Eventarc", that's Google still setting up. Wait two minutes and run **Deploy cloud** again. Anything else: I can read the run's log from here, so just tell me it went red.

From now on, any change I make to the cloud deploys itself when it's pushed.

### 10. Sign in

Open Lobby (download the latest build if I've said there's a new one). It sees the plist and asks for the email and password from step 4. After that, the cards switch from sample to live one at a time as I wire them.

## If something goes wrong

- **"Lobby is damaged and can't be opened."** The zip got unpacked by something other than Finder. Delete it, download again, double-click the zip in Finder.
- **Option+Space does nothing.** Another app holds that shortcut (Raycast, Alfred, or Spotlight if you've changed it). Lobby shows a note at the bottom of the window when that happens. The search box on Home still opens the concierge.
- **Lobby asks you to sign in again after an update.** Expected for now: each download is a fresh copy and macOS keeps their keychain entries apart. Goes away once it's properly signed at the phone stage.
- **Anything red on the Actions page.** Tell me which workflow; I can read the log.
