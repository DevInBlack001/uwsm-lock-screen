# Wallpaper rotation + TUI selector - design

Date: 2026-10-06
Status: approved, ready for implementation plan

## Goal

Let the Omarchy lock screen (built in sub-project 1) rotate between multiple
wallpapers drawn from the active theme, with the pool extendable by the user
via local file paths or direct image URLs, managed through a `gum`-based TUI.
Rotation is independent of the regular desktop wallpaper.

## Scope

- Omarchy lock screen only (the cloned `le_4rchitect.lock` plugin). The
  regular Hyprland desktop wallpaper and the future hyprlock/gtklock
  sub-projects are out of scope for this iteration.
- Rotation trigger: every lock (a new random pick each time the screen locks).
- Online sources: direct `https://` image URLs only, user-supplied one at a
  time via the TUI - no wallpaper API/search integration.

## Current state (from sub-project 1)

`Service.qml`'s `refreshBackground()` runs `readlink -f` on
`$STATE_HOME/omarchy/current/background` (the same symlink the regular
desktop wallpaper uses) and stores the result in `backgroundPath`, which
`LockView.qml` loads and blurs. This is shared with the desktop wallpaper -
exactly what this sub-project's "lock screen only" scope decision needs to
stop being the case for theme-rotation users.

Omarchy already ships multiple wallpapers per theme, unused by the lock
screen today: `~/.local/state/omarchy/current/theme/backgrounds/` (a
per-theme directory, e.g. the `ristretto` theme currently has 4 images
there). This is the local half of the rotation pool, for free.

## Architecture

1. **Sources config**: `~/.config/uwsm-lock-screen/wallpapers/<theme-name>.list`
   - Plain text, one entry per line: either an absolute local path or an
     `https://` URL. Comment lines start with `#`. One file per theme name
     (matching `~/.local/state/omarchy/current/theme.name`), created empty
     (user-additions only) the first time the TUI opens for a theme that
     has no file yet.
   - The *pool* for a theme is: every file in
     `~/.local/state/omarchy/current/theme/backgrounds/` (when the active
     theme matches) **plus** every entry in that theme's `.list` file
     (local paths used directly, URLs resolved to their cached copy).

2. **Cache**: online URLs download into
   `~/.cache/uwsm-lock-screen/wallpapers/<theme-name>/<sha256-of-url>.<ext>`
   on first use (by the TUI when added, and again by the rotation script if
   the cached file has gone missing). Never re-downloaded if the cached
   file already exists and is non-empty.

3. **Rotation script**: `bin/uwsm-lock-wallpaper-rotate` (bash)
   - Reads the active theme name, builds the pool as above, and if rotation
     is enabled for that theme (see below), picks one entry at random.
   - For a `.list` URL entry with no cached copy yet, downloads it
     (bounded, see Security) before use; if the download fails, that entry
     is skipped for this pick (falls back to another pool member).
   - Writes the resolved absolute path to
     `~/.local/state/uwsm-lock-screen/current-wallpaper` (a symlink,
     mirroring Omarchy's own `current/background` symlink convention).
   - If rotation is disabled for the theme, or the pool is empty, or every
     pool member fails to resolve, the script instead symlinks
     `current-wallpaper` to the existing shared
     `~/.local/state/omarchy/current/background` - the lock screen never
     ends up with a missing background.
   - Rotation is **on by default** for every theme - no per-theme setup
     required, so it follows whichever theme is currently active without
     the user having to configure anything first. A `rotation-disabled`
     flag lives as a zero-byte marker file
     `~/.config/uwsm-lock-screen/wallpapers/<theme-name>.disabled`; its mere
     presence turns rotation OFF for that theme (opt-out, not opt-in). The
     TUI's "Toggle rotation" action creates/removes this marker.

4. **Service.qml hook** (the one change to previously-untouched code): in
   `beginLock()`, immediately before the existing
   `Qt.callLater(function() { root.refreshBackground(); ... })` block, run
   the rotation script as a `Process` and only call `refreshBackground()`
   once it exits (success or failure - the script always leaves
   `current-wallpaper` pointing at *something* per the fallback above).
   `refreshBackground()` itself changes its `readlink -f` target from
   `$STATE_HOME/omarchy/current/background` to
   `$STATE_HOME/uwsm-lock-screen/current-wallpaper`.

5. **TUI**: `bin/uwsm-lock-wallpaper` (bash + `gum`)
   - Opens on the active theme's pool: lists each entry (local paths as
     given, URLs with their cached/not-yet-cached status), plus a header
     showing whether rotation is currently on or off for this theme.
   - Actions (via `gum choose`): Add source (prompts path or URL via `gum
     input`, validates before saving - see Security), Remove a source
     (`gum choose` against current entries), Toggle rotation on/off,
     Quit.
   - Adding a URL downloads it immediately (so the user gets feedback if a
     link is bad) rather than deferring to the next lock.

## Security (per the project's standing checklist)

- **Transfer**: only `https://` URLs accepted (reject `http://`, `file://`,
  anything else) when adding a source. `curl` is invoked with an argument
  list (`curl --proto =https --max-filesize 20971520 --max-time 15 -sSL -o
  <path> -- <url>`), never via shell string interpolation.
- **Data handling**: downloads capped at 20MB (`--max-filesize`) and 15s
  timeout; the response `Content-Type` is checked against an image
  allowlist (`image/png`, `image/jpeg`, `image/webp`) before the cached
  file is kept, and a failed/oversized/wrong-type download is deleted
  rather than left partially written.
- **File integrity**: local path entries are checked with `[[ -L "$path"
  ]]` and rejected if the path itself is a symlink before being saved to
  the `.list` file, and the rotation script re-checks this at read time too
  (a `.list` file could in principle be hand-edited after the TUI accepted
  it) - consistent with the project's no-symlinks-on-sensitive-reads rule,
  applied here because a wallpaper path is rendered full-screen and a
  symlink swap could be used to probe filesystem timing/existence.
- **Hashing**: the cache filename uses `sha256sum` (coreutils, already a
  dependency via the rest of the Omarchy toolchain) - not a custom hash.
- **RCE**: no `eval`, no shell string-built commands; every `Process`/`curl`
  invocation in both the bash scripts and the new `Process` block in
  `Service.qml` uses an explicit argument list.

## Non-goals

- No wallpaper search/browse API integration (Unsplash, Wallhaven, etc).
- No time-based rotation (lock-triggered only, per the approved design).
- No in-terminal image preview in the TUI (would need `chafa` or similar as
  a new dependency); entries are listed by filename/URL only.
- No changes to the regular desktop wallpaper or to any non-Omarchy lock
  screen flavor.

## Testing

- Pure logic (pool resolution, fallback selection, URL validation) gets
  Node-run tests the same way sub-project 1's Model.js files did, by
  extracting the bash logic that can reasonably be expressed as pure
  functions into a small JS helper where that's natural, and testing the
  rest (download, caching, Process invocation) via direct script
  invocation against a temp `HOME`/cache dir rather than mocking `curl`.
- Live verification follows the same pattern established in sub-project 1:
  `omarchy-shell lock preview`, `grim -o eDP-1` (not `omarchy capture
  screenshot`, which is unreliable for scripted capture - see
  `.superpowers` ledger history), cross-checked with `hyprctl layers`
  before trusting a capture, and a real `omarchy system lock` + unlock at
  the end. Given the hot-reload staleness issue found in sub-project 1's
  layout work, any `Service.qml` edit in particular should be verified
  with a full `omarchy restart shell` rather than trusting hot-reload
  alone, since `Service.qml` changes are exactly the kind that produced
  silent stale-fallback behavior before.
