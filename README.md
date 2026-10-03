# Kalendario

Weekly planner for macOS: a Monday→Sunday grid with events, all-day activities, sticky notes
with to-do lists, a PLACE row marking where you work each day, and read-only import of GitHub
issues.

## Requirements

- macOS 14 or later (verified on macOS 27, Swift 6.4).
- Only the Xcode **Command Line Tools**: `swift build` is enough, no Xcode.
  For contributors: `@State` is a macro whose implementation plugin ships with Xcode only, so UI
  state lives in `@Observable` classes (`AppState`, `DataStore`) instead.

## Build, run, install

```bash
./Scripts/run.sh          # build and launch
./Scripts/build_app.sh    # create dist/Kalendario.app (icon + ad-hoc signature)
./Scripts/install.sh      # install into /Applications (or ~/Applications) and launch
KAL_UNIVERSAL=1 ./Scripts/build_app.sh   # universal binary (arm64 + x86_64)
```

`dist/Kalendario.app` is bundle identifier `local.kalendario.app` with `LSMinimumSystemVersion`
14.0 and an ad-hoc signature: Gatekeeper may warn on another Mac, and macOS may ask once for
access to the Keychain item holding the GitHub token.

## Data

`~/Library/Application Support/Kalendario/kalendario.json` — written atomically, debounced by
0.4 s. The app starts empty. Decoding is tolerant (missing fields fall back to defaults), and an
unreadable file is kept as `kalendario.json.bak` instead of being reset.

Category and colour values keep their historical Italian identifiers (`"lavoro"`, `"giallo"`, …)
even though the code is in English: **do not rename them**, or existing files stop loading.

## GitHub import

Enter a repository (`owner/name` or a pasted URL), load, tick issues, choose day/time and place
them. Every imported issue also becomes a **sticky note** of that week: its title is
`#123 Issue title` and the lines of the issue body become the to-do list (markdown bullets,
checkboxes and headings are stripped; at most 20 lines of 120 characters). Re-importing refreshes
the note instead of adding a second one. Public repositories need no token (60 requests/hour); for private ones, or a higher limit,
store a token with *Issues: read* permission — it goes into the **macOS Keychain** (service
`local.kalendario.app`), never into the JSON file, the preferences or the logs. `GITHUB_TOKEN` is
the developer fallback. The import is read-only, and closed issues are ticked as completed when
you refresh.

## Weather

Each day of the header shows the date, the weekday and the forecast (icon, maximum/minimum).
Choose the place with the gear in the left gutter of that row, which also shows the city in use.
The name is geocoded once and kept in the preferences (no account, no API key). Forecast from
Open-Meteo.com, refreshed every 30 minutes; only the place is remembered, the forecast is never
written to the data file.

An event can be marked **all-day** (*All-day activity* in the editor): it has no start and end
time (`"isAllDay": true`, `durationMinutes: 0` in the data file) and it is shown as a chip in the
header of its day instead of on the timeline.

## Shortcuts

| Action | Keys |
|---|---|
| New event / new sticky note | ⌘N / ⇧⌘N |
| Today / previous week / next week | ⌘T / ⌘← / ⌘→ |
| Show window | ⌘0 |

Closing the window hides it: the app stays in the Dock, and the Dock icon or ⌘0 brings the same
window back.

## Maintenance

```bash
swift build [-c release]                             # compile
./Scripts/check_secrets.sh                           # no tokens or keys in files a commit would include

.build/release/Kalendario --json-check [/tmp/f.json] # data format round-trip and old files
.build/release/Kalendario --github-check owner/name  # real API, prints what was parsed
.build/release/Kalendario --render-icon /tmp/AppIcon.iconset
.build/release/Kalendario --render-preview /tmp/p.png --size 1440x900 [--dark]
#   also: --render-header, --render-import, --render-places (same options)
open -a dist/Kalendario.app --args --window-watch 12 /tmp/w.txt   # window close/reopen trace
```

## Layout

```
Package.swift
Sources/Kalendario/
  App/        EntryPoint, AppState, IssueImportModel, WindowManager, LaunchOptions
  Models/     CalendarEvent, IssueRef, WorkLocation, StickyNote, TodoItem, EventCategory, NoteColor
  Store/      DataStore (persistence), GitHubClient, TokenStore (Keychain)
  Views/      RootView, HeaderBar, WeekGridView, DayColumnView, NotesRailView, EventEditorView,
              IssueImportView, WorkLocationRow, WorkLocationsView
  Support/    DateHelpers, Theme, ColorHex, PreviewMode
  Preview/    PreviewRenderer (PNG previews and the app icon)
Scripts/      build_app.sh, run.sh, install.sh, check_secrets.sh
```

## License

Apache 2.0 — see [LICENSE](LICENSE).