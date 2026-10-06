# Omarchy lock screen widgets - design

Date: 2026-10-06
Status: approved, ready for implementation plan

## Goal

Extend Omarchy's default lock screen (currently just a blurred wallpaper and
a password field) to also show: time, date, user, avatar, battery,
media/MPRIS playback with transport controls, and network status (wifi SSID
or ethernet).

## Current state

Omarchy's lock screen is not hyprlock. It is a Quickshell/QML plugin at
`/usr/share/omarchy/shell/plugins/lock/`:

- `manifest.json` - plugin id `omarchy.lock`, kind `service`, entry point
  `Service.qml`.
- `Service.qml` - owns `WlSessionLock`/`WlSessionLockSurface`, PAM password
  and fingerprint auth flows, idle-blank timer, background-path resolution,
  and an `IpcHandler` (`lock`) exposing `lock()`, `status()`, `preview()`,
  `hidePreview()`.
- `LockView.qml` - pure presentation: blurred wallpaper + centered password
  field with fingerprint hint icon. No clock, user info, battery, media, or
  network widgets exist today.

Reusable services already running in the shell (found under
`/usr/share/omarchy/shell/plugins/{panels,services}/`), all of which the
lock screen widgets will read from directly rather than re-implementing:

- **Battery**: `Quickshell.Services.UPower`, `UPower.displayDevice`. The
  `services/battery` plugin only adds low-battery notifications and power
  profile switching on top of this; the raw device properties are enough for
  display.
- **Media**: `Quickshell.Services.Mpris`, `Mpris.players`. The
  `services/media` plugin's `selectActivePlayer()` logic (in `Service.qml`/
  `MediaModel.js`) is the same "which player is actually active" resolution
  used by the bar; the lock screen's media widget mirrors that selection
  rather than writing new logic, and drives playback through the player
  object directly (`play()`, `pause()`, `next()`, `previous()`).
- **Network**: the `panels/network` panel shells out to
  `omarchy-network-status --verbose` and parses the tab-separated output with
  `Model.js#parseNetworkStatus`. The lock screen reuses the same command and
  parser for an icon + SSID/ethernet label, read-only.
- **Avatar**: no existing service. Read `~/.face` directly (standard Linux
  per-user avatar path); if absent, fall back to a generic person glyph
  already used elsewhere in the shell's icon set. No AccountsService/DBus
  call needed since the lock screen always runs as the logged-in user.

## Non-goals

- No changes to PAM, fingerprint auth, or `WlSessionLock` logic in
  `Service.qml`.
- No new DBus services, no new write access to NetworkManager/UPower/MPRIS
  beyond existing playback transport controls.
- No settings UI for toggling individual widgets in this iteration; a fixed
  layout ships first.

## Layout

Minimal glass card style, chosen to match the existing password field's
`BorderSurface` look:

- Centered clock (large time) + date directly above the password field,
  in the same vertical position the password field already centers around.
- Password field: unchanged, same position and behavior as today.
- A new glass card (`BorderSurface`, same corner radius/border spec as the
  password field) anchored bottom-center, below the password field,
  containing, left to right:
  1. Circular avatar + username
  2. Thin vertical divider
  3. Battery icon + percentage (entire battery segment hidden if
     `UPower.displayDevice` reports no battery, e.g. on a desktop)
  4. Thin vertical divider
  5. Network icon + SSID (wifi) or "Ethernet" (wired) or hidden if
     disconnected
  6. Thin vertical divider
  7. Media block: elided track title / artist, with previous / play-pause /
     next icon buttons. Entire block hidden when `Mpris.players` has no
     active/controllable player.

Dividers collapse (no leftover gap) when an adjacent segment is hidden.

## New files (inside the cloned plugin)

Per the omarchy skill, the packaged plugin at
`/usr/share/omarchy/shell/plugins/lock/` is never edited directly. The
implementation plan clones it with `omarchy plugin clone omarchy.lock` into
the user's plugin override directory, then adds:

- `ClockWidget.qml` - time + date text, reusing `Style.font` tokens already
  used elsewhere in the shell for consistent typography.
- `AvatarWidget.qml` - circular `Image` of `~/.face` with fallback glyph.
- `StatusCard.qml` - the glass card described above, composing avatar,
  battery, network, and media segments with the divider-collapse behavior.
- `MediaControls.qml` - prev/play-pause/next buttons, bound to the active
  MPRIS player's `canGoNext`/`canGoPrevious`/`canPause`/`canPlay` for
  enabled/disabled state (mirrors how `services/media` already guards these
  actions).

`LockView.qml` changes are additive only: the new widgets are inserted
alongside the existing wallpaper/password-field tree; none of the existing
`Item`s, signals, or PAM-driven properties change.

`Service.qml` is unmodified - it already exposes everything the new widgets
need to read (`backgroundPath` aside, these widgets don't need any new
properties threaded through from `Service.qml` since they read UPower/Mpris/
the network command directly).

## Data flow / security notes

- Battery, media, and network reads are all read-only against existing
  system services/commands already trusted and running in the shell; no new
  attack surface.
- Avatar read is a single bounded local file (`~/.face`); no symlink-follow
  concerns beyond what Qt's `Image` element already does for any other
  wallpaper/icon load in this shell.
- Media transport controls (`play`/`pause`/`next`/`previous`) call existing
  MPRIS player methods; no new process execution, no shell string building.
- No secrets are read or displayed (this widget set never touches the PAM
  password flow).

## Testing

- Use the plugin's existing `preview()` IPC call (`Service.qml`'s
  `IpcHandler { target: "lock" }`) to render `LockView` live in a
  `PanelWindow` without actually taking the session lock, so each widget can
  be visually checked while iterating.
- Manually verify: battery segment hides on a desktop/no-battery system;
  network segment updates on wifi/ethernet/disconnected transitions; media
  block appears/disappears as players start/stop and buttons respect
  disabled state when a player can't skip/pause; avatar falls back cleanly
  when `~/.face` is absent.
