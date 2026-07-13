# Riffle

A tiny, custom [AltTab](https://alt-tab-macos.netlify.app/)-style **window** switcher for macOS.

- Switches between **windows**, not apps.
- Shows a clean list of **app icon + window title** only — no window previews/thumbnails (which also means it never needs the Screen Recording permission).
- Sees windows in **all Spaces (virtual desktops)**, not just the current one — scopes are about *physical monitors*, never Spaces. Switching to a window in another Space jumps there automatically.
- Multiple hotkeys, each with its own purpose, fully customizable via a JSON config:
  - **⌘ Tab** — cycle through the windows on the **active physical monitor** (the monitor with the focused window), across all its Spaces.
  - **⌘ `** — cycle through windows on **all monitors**. With a single monitor this behaves exactly like ⌘Tab.
  - **⌥ Tab** — cycle through the windows of the **frontmost app** (e.g. jump between open Chrome windows while in Chrome).
- Hold the modifier and keep pressing the key to move down the list; add **Shift** to move backwards; release the modifier to switch to the selected window; press **Esc** to cancel.
- A **Settings window** (menu bar icon → Settings…) to add/remove/re-record shortcuts, choose what each one shows, tune the switcher's appearance (list size and background opacity), and exclude apps from all lists — no config-file editing needed.
- Runs as a menu-bar-only app (no Dock icon).

## Requirements

- macOS 13 or later (Apple Silicon or Intel).
- Xcode Command Line Tools (for building): `xcode-select --install`

## Install

From this project directory:

```bash
./install.sh
```

That script:

1. Compiles the app in release mode (`swift build -c release`).
2. Assembles and ad-hoc code-signs `dist/Riffle.app`.
3. Resets any stale Accessibility permission (see note below) so a reinstall grants cleanly.
4. Copies it to `/Applications/Riffle.app` and launches it.

### First run: grant Accessibility access

macOS requires Accessibility access to list windows and intercept ⌘Tab:

1. On first launch you'll get a system prompt — click **Open System Settings**.
   (Or go there manually: **System Settings → Privacy & Security → Accessibility**.)
2. Enable **Riffle** in the list.
3. That's it — the app detects the grant automatically within a couple of seconds. Hold **⌘** and press **Tab**.

> While Riffle is running, it takes over ⌘Tab from the built-in macOS app switcher. Quit Riffle (menu bar icon → Quit) to get the native switcher back.

### Start at login (optional)

**System Settings → General → Login Items** → click **+** → select `/Applications/Riffle.app`.

## Usage

| Action | Keys |
|---|---|
| Cycle windows on the active screen | Hold ⌘, tap **Tab** |
| Cycle windows on all screens | Hold ⌘, tap **`** (backtick) |
| Cycle windows of the current app | Hold ⌥ (option), tap **Tab** |
| Move backwards through the list | Add **Shift** (e.g. ⌘⇧Tab) |
| Move around the list | **↓/→** forward, **↑/←** backward (while the list is open) |
| Switch to the selected window | Release ⌘ |
| Cancel without switching | **Esc** |

The list is in most-recently-used order — Riffle tracks window focus while it runs (macOS has no built-in "last focused" timestamp), so the order is true MRU across all Spaces and monitors. Windows not focused since the app launched fall back to front-to-back stacking order. The selection starts on the *second* item, so a quick ⌘Tab tap-and-release jumps to your previous window. Minimized windows and phantom helper windows that some apps create (Chrome, Acrobat, …) are hidden — only real, open windows are listed.

## Configuration

Open the menu bar icon → **Settings…**. From there you can:

- **Shortcuts** — click a shortcut to re-record it (just press the new key combination; Esc cancels), pick what each one shows from the dropdown (*active monitor / all monitors / current app*), remove shortcuts, or add new ones. Changes apply immediately.
- **Appearance** — scale the whole switcher with the *List size* slider (it still grows automatically for shorter lists) and drag *Background* from glassy (translucent blur) to fully solid.
- **Excluded Apps** — add any running app (or pick one from disk) to hide all of its windows from every list; remove it to bring it back.

A shortcut needs at least one of ⌘, ⌥, ⌃. Record without ⇧ — then Shift automatically means "cycle backwards" for that shortcut.

### Config file (advanced)

Settings are stored in a JSON file, so you can also edit or version-control it directly (relaunch the app after hand-editing):

```
~/Library/Application Support/Riffle/config.json
```

Default config:

```json
{
  "bindings": [
    { "key": "tab", "modifiers": ["cmd"],    "scope": "activeScreen" },
    { "key": "`",   "modifiers": ["cmd"],    "scope": "allScreens" },
    { "key": "tab", "modifiers": ["option"], "scope": "activeApp" }
  ],
  "excludedApps": ["com.spotify.client"]
}
```

`excludedApps` holds bundle identifiers (app names also work). Each binding has:

- **`key`** — one of: letters `a`–`z`, digits `0`–`9`, `tab`, `space`, `` ` `` (also `grave`/`backtick`), punctuation (`-`, `=`, `[`, `]`, `\`, `;`, `'`, `,`, `.`, `/`), `f1`–`f12`, `left`/`right`/`up`/`down`.
- **`modifiers`** — any combination of `cmd`, `option` (or `alt`), `ctrl`, `shift`. At least one is required; the switcher stays open while these are held and commits when released. Shift is best left out — it's automatically the "go backwards" key for any binding that doesn't require it.
- **`scope`** — what the binding cycles through (all scopes include windows in other Spaces):
  - `activeScreen` — only windows on the physical monitor containing the currently focused window.
  - `allScreens` — every window on every monitor.
  - `activeApp` — only windows belonging to the frontmost app (on any monitor).

Two more optional keys tune the switcher's look (or use the Settings window):

- **`listScale`** — multiplier over the dynamic row sizing (clamped to a sensible range).
- **`backgroundOpacity`** — `0` for a fully glassy blur, `1` for a solid background.

Add as many bindings as you like. Example — `option+tab` for all screens instead of `` cmd+` ``:

```json
{ "key": "tab", "modifiers": ["option"], "scope": "allScreens" }
```

## Uninstall

```bash
osascript -e 'quit app "Riffle"'
rm -rf /Applications/Riffle.app
rm -rf ~/Library/Application\ Support/Riffle
```

Then remove Riffle from **System Settings → Privacy & Security → Accessibility**.

## Troubleshooting

- **Hotkeys don't work while a terminal is focused (native ⌘Tab appears instead)** — that terminal has **Secure Keyboard Entry** enabled, which makes macOS hide keystrokes from all event taps while it's focused (by design; nothing can bypass it). The menu bar icon turns into a ⚠️ warning triangle while this is happening. To fix:
  - **Terminal.app**: menu bar → **Terminal** → untick **Secure Keyboard Entry**.
  - **iTerm2**: menu bar → **iTerm2** → untick **Secure Keyboard Entry**.
  - Note that some password managers toggle secure input briefly while their password fields are focused — that's normal and clears on its own.
- **⌘Tab still opens the native macOS switcher everywhere** — Accessibility access isn't granted (or was granted to an older build). Remove Riffle from the Accessibility list, re-add it (the **+** button, select `/Applications/Riffle.app`), then relaunch the app.
- **After rebuilding/reinstalling, hotkeys stopped working** — the ad-hoc code signature changes with each build, so macOS may treat it as a different app while the old grant lingers (the toggle looks on but doesn't apply). `install.sh` now clears the stale entry automatically (`tccutil reset Accessibility com.amin.riffle`) and the app re-prompts, so just re-enable **Riffle** in the Accessibility list after reinstalling. If you copied the app by hand instead of using `install.sh`, run that `tccutil` command yourself, then relaunch.
- **A hotkey does nothing** — check the key/modifier names in `config.json` against the lists above, then relaunch. Malformed config falls back to the defaults. Key codes assume an ANSI (US-style) physical layout.
- **An app's windows never appear in the list** — windows in other Spaces are found via the same accessibility side channel AltTab uses; a few apps with non-native toolkits (LibreOffice, some Java apps) don't answer those queries for windows outside the current Space and can't be listed. Switch to their Space once and they'll appear.
- **Is it running?** — look for the small window icon in the menu bar.

## Project layout

```
Package.swift                       Swift Package Manager manifest
Sources/Riffle/
  main.swift                        entry point
  AppDelegate.swift                 event tap (hotkey interception), menu bar item, permissions
  Config.swift                      settings storage, editing API, key/modifier resolution
  SettingsWindow.swift              the Settings UI (shortcut recorder, scopes, appearance, excluded apps)
  WindowEnumerator.swift            window listing across Spaces + focusing, monitor detection, caching
  PrivateAX.swift                   private accessibility APIs for windows in other Spaces
  SwitcherController.swift          trigger → cycle → commit/cancel state machine
  SwitcherPanel.swift               the floating icon+title list UI
Resources/Info.plist                app bundle metadata (menu-bar-only app)
Resources/Riffle.icns               app icon
Tools/GenerateIcon.swift            regenerates the app icon (see below)
build.sh                            compile + assemble + sign dist/Riffle.app
install.sh                          build + install to /Applications + launch
```

### Regenerating the icon

The app icon is drawn programmatically. To change it, edit `Tools/GenerateIcon.swift`, then:

```bash
swift Tools/GenerateIcon.swift build/Riffle.iconset
iconutil -c icns build/Riffle.iconset -o Resources/Riffle.icns
rm -rf build/Riffle.iconset
```
