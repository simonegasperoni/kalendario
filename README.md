# Kalendario

Weekly planner for macOS: a Monday→Sunday grid with events, all-day activities, sticky notes
with to-do lists, a PLACE row marking where you work each day, read-only import of GitHub
issues, a status row with the temperature of CPU and GPU and the use of memory and disk, a row with
the commits of every repository imported from (one cell per day), and one settings window for the
weather place, the GitHub token and the work places.

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
store a token with *Issues: read* permission — it is entered in the **settings window** (⌘,, the gear
in the top bar) and goes into the **macOS Keychain** (service `local.kalendario.app`), never into the
JSON file, the preferences or the logs. `GITHUB_TOKEN` is
the developer fallback. The import is read-only, and closed issues are ticked as completed when
you refresh. The row at the foot of the calendar shows, in seven cells aligned with the days of the
week, how many commits each imported repository put on each day **on its default branch**. The first
read is made without the token (so opening the app never asks for the keychain), the button beside
the row repeats it with the token, and the numbers are kept in the preferences, so from the next
launch they are there straight away. The repositories to read are listed in the settings window
(**GitHub repositories**); the ones your imported issues come from are read as well, so importing an
issue is not needed to see a repository's commits. On a fine-grained token the commit count needs
**Contents: read** (a classic token needs the `repo` scope) — reading issues alone is not enough. The
token is entered in the same settings window (gear in the top bar, or ⌘,), together with the weather
place and the work places.

## Weather

Each day of the calendar body carries its forecast: a big, quiet icon at the foot of the column with
the maximum and minimum under it, in the tone of the paper. The header of each day stays on one line
— date and weekday — and the place is chosen with the gear in the chip of the top bar, which also
shows the city in use.
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
| Settings (weather place, GitHub token, work places) | ⌘, |

Closing the window hides it: the app stays in the Dock, and the Dock icon or ⌘0 brings the same
window back.

## Maintenance

```bash
swift build [-c release]                             # compile
./Scripts/check_secrets.sh                           # no tokens or keys in files a commit would include

.build/release/Kalendario --notes-check               # sticky note order: reorder and round trip
.build/release/Kalendario --stats-check               # CPU/GPU temperature, memory and disk of this Mac
.build/release/Kalendario --json-check [/tmp/f.json] # data format round-trip and old files
.build/release/Kalendario --github-check owner/name  # real API, prints what was parsed
.build/release/Kalendario --commits-check owner/name # the commits of each day of the current week
.build/release/Kalendario --render-icon /tmp/AppIcon.iconset
.build/release/Kalendario --render-preview /tmp/p.png --size 1440x900 [--dark]
#   also: --render-header, --render-import, --render-places, --render-settings (same options)
open -a dist/Kalendario.app --args --window-watch 12 /tmp/w.txt   # window close/reopen trace
```

## Layout

```
Package.swift
Sources/Kalendario/
  App/        EntryPoint, AppState, IssueImportModel, SystemStats, RepoMetaModel, WindowManager,
              LaunchOptions
  Models/     CalendarEvent, IssueRef, WorkLocation, StickyNote, TodoItem, EventCategory, NoteColor
  Store/      DataStore (persistence), GitHubClient, TokenStore (Keychain)
  Views/      RootView, HeaderBar, SystemStatsRow, WeekGridView, DayColumnView, GitHubMetaRow,
              NotesStripView, NotesRailView, EventEditorView, IssueImportView, SettingsView,
              WorkLocationRow, WorkLocationsView
  Support/    DateHelpers, Theme, ColorHex, PreviewMode
  Preview/    PreviewRenderer (PNG previews and the app icon)
Scripts/      build_app.sh, run.sh, install.sh, check_secrets.sh
```

## License

Apache 2.0 — see [LICENSE](LICENSE).