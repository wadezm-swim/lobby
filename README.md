# Lobby

A personal always-on app for Mac, iPhone and iPad. Work up front in work hours, your interests after.

- **To run it:** [docs/SETUP.md](docs/SETUP.md), plain steps.
- **The brief and current status:** [CLAUDE.md](CLAUDE.md).
- **The designs:** open any file in `design/` in a browser.

| Folder | What it is |
|---|---|
| `Lobby/`, `Lobby.xcodeproj` | The Mac app (SwiftUI). Open the project in Xcode and press Play. |
| `LobbyCore/` | Shared logic with no UI, tested on Mac and Linux. |
| `functions/` | Firebase Cloud Functions: scheduled sports and news fetches, captures to Notion. |
| `design/` | Signed-off HTML mock-ups. |
| `docs/` | Setup guide. |

Tests: `swift test --package-path LobbyCore` and `cd functions && npm test`. `npm run smoke` in `functions/` hits the live feeds.
