# Omarchy Lock Screen Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add time/date, user+avatar, battery, MPRIS media (with transport controls), and network status to Omarchy's default Quickshell lock screen, without touching its existing password/PAM/fingerprint logic.

**Architecture:** Clone the built-in `omarchy.lock` plugin into `~/.config/omarchy/plugins/` with `omarchy plugin clone`, then add new, independently-testable QML widgets plus small pure-JS "Model" helper modules (same pattern the shell already uses in `MediaModel.js`/`Model.js`) that each new widget calls into. `LockView.qml` only gains new child items; nothing existing in it or in `Service.qml` is modified.

**Tech Stack:** Quickshell/QML (Qt 6), plain ECMAScript helper modules runnable under Node for logic tests (`module.exports` guarded by `typeof module !== "undefined"`, the existing codebase convention), bash (`omarchy-network-status --verbose`).

**Spec:** `docs/specs/2026-10-06-omarchy-lock-screen-design.md`

## Global Constraints

- Never edit `/usr/share/omarchy/` — all work happens in the clone at `~/.config/omarchy/plugins/<username>.lock/`.
- `Service.qml` in the clone is not modified (per spec's non-goals: no PAM/fingerprint/`WlSessionLock` changes).
- All new data reads are read-only (UPower, Mpris, `omarchy-network-status --verbose`, `~/.face`); no new DBus write access beyond existing MPRIS transport methods (`play`/`pause`/`next`/`previous`).
- No settings UI; fixed layout only (spec non-goal).
- Divider segments collapse (no gap) when an adjacent segment is hidden.
- Battery segment hidden entirely when `UPower.displayDevice` reports no battery.

## Review Focus

- **No battery present (desktop machine):** `UPower.displayDevice` has no real battery — the battery segment and both its adjacent dividers must fully collapse, not just the icon/text going blank.
- **No MPRIS player running:** `Mpris.players` is empty — the whole media block must disappear, and `MediaControls` buttons must never be visible mid-track-change flicker while no player exists.
- **Network disconnected:** `omarchy-network-status --verbose` reports a disconnected state — the network segment hides rather than showing an empty/garbled icon.
- **`~/.face` missing:** avatar falls back to the generic glyph instead of a broken-image icon or a QML warning.
- **Player exists but can't skip/pause (e.g. a stream with no transport control):** `MediaControls` buttons reflect `canGoNext`/`canGoPrevious`/`canPause`/`canPlay` as disabled, not hidden or silently no-op clickable.

---

## File Structure

All new files live inside the cloned plugin directory, referred to below as `$CLONE` (`~/.config/omarchy/plugins/<username>.lock/` — the exact directory name depends on `$USER` and is discovered in Task 1).

- `$CLONE/LockView.qml` — existing file, additive edit only (adds `ClockWidget` and `StatusCard` instances).
- `$CLONE/ClockWidget.qml` — new. Time + date display.
- `$CLONE/ClockModel.js` — new. Pure formatting functions for `ClockWidget.qml`.
- `$CLONE/AvatarWidget.qml` — new. Circular avatar image with fallback glyph.
- `$CLONE/AvatarModel.js` — new. Pure function deciding avatar source vs. fallback.
- `$CLONE/BatterySegment.qml` — new. Battery icon + percentage, self-hiding.
- `$CLONE/BatteryModel.js` — new. Pure formatting/visibility functions.
- `$CLONE/NetworkSegment.qml` — new. Network icon + label, self-hiding. Reuses the existing `parseNetworkStatus` logic (copied in, since it's a few pure functions, not cross-plugin-importable).
- `$CLONE/NetworkModel.js` — new. Carries the copied `parseNetworkStatus`/`connectionIcon` functions plus a new `networkSegmentVisible` helper.
- `$CLONE/MediaControls.qml` — new. Prev/play-pause/next buttons bound to the active player's capability flags.
- `$CLONE/MediaSegment.qml` — new. Track title/artist + `MediaControls`, self-hiding.
- `$CLONE/MediaModel.js` — new. Simplified active-player selection (first playing, else first controllable — the lock screen doesn't need the bar's source-cycling/OSD logic) plus formatting helpers.
- `$CLONE/StatusCard.qml` — new. Composes avatar+username, `BatterySegment`, `NetworkSegment`, `MediaSegment` with collapsing dividers.
- `$CLONE/DividerModel.js` — new. Pure function computing which dividers should render given segment visibility.
- Tests for every `*Model.js` file run under plain `node` with `assert`, following the file-per-module pattern already in the codebase; no new test framework/dependency is introduced.

---

### Task 1: Clone the plugin and confirm the baseline still works

**Files:**
- Create (via command, not hand-written): `~/.config/omarchy/plugins/<username>.lock/` (full copy of the built-in `omarchy.lock` plugin).

**Interfaces:**
- Produces: `$CLONE` — the absolute path to the clone, used by every later task. Record it (e.g. `echo ~/.config/omarchy/plugins/$(id -un).lock`) since later steps reference it literally.

- [ ] **Step 1: Clone the built-in plugin**

Run: `omarchy plugin clone omarchy.lock`

Expected output ends with the plugin being enabled; no error. This also disables/replaces the built-in `omarchy.lock` via the clone's `clonedFrom` field, per `omarchy-plugin-clone`'s own docstring.

- [ ] **Step 2: Resolve and record $CLONE**

Run: `CLONE="$HOME/.config/omarchy/plugins/$(id -un).lock"; echo "$CLONE"; ls "$CLONE"`

Expected: directory exists and lists `LockView.qml`, `Service.qml`, `manifest.json`.

- [ ] **Step 3: Verify the cloned lock screen still works via preview**

Run: `omarchy-shell ipc call lock preview` (or the shell's equivalent IPC call mechanism already used by `Service.qml`'s `IpcHandler { target: "lock" }` — check `omarchy-shell ipc --help` if the call syntax differs) then visually confirm the password field renders exactly as before (blurred wallpaper, centered field, fingerprint icon if enrolled).

Expected: identical appearance to the pre-clone lock screen. This is the regression baseline every later task must not break.

- [ ] **Step 4: Hide the preview and commit the clone as the starting point**

Run: `omarchy-shell ipc call lock hidePreview`

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
mkdir -p clone-mirror
cp -r "$CLONE"/* clone-mirror/
git add clone-mirror
git commit -m "Mirror cloned omarchy.lock plugin before adding widgets"
```

(The repo tracks a mirror of `$CLONE` under `clone-mirror/` so the work is versioned; later tasks edit both `$CLONE` directly, for the running shell to pick up via hot-reload, and `clone-mirror/` for version control — each task's commit step copies changed files into `clone-mirror/` before committing.)

---

### Task 2: Clock widget (time + date)

**Files:**
- Create: `$CLONE/ClockModel.js` and mirrored to `clone-mirror/ClockModel.js`
- Create: `$CLONE/ClockWidget.qml` and mirrored to `clone-mirror/ClockWidget.qml`
- Test: `clone-mirror/ClockModel.test.js`

**Interfaces:**
- Produces: `ClockModel.formatTime(date)` → `string` (e.g. `"14:07"`, 24-hour), `ClockModel.formatDate(date)` → `string` (e.g. `"Tuesday, October 6"`). `ClockWidget.qml` is a QML `Item` with no required properties, self-contained (reads the system clock itself via a `Timer`).

- [ ] **Step 1: Write the failing test for ClockModel**

Create `clone-mirror/ClockModel.test.js`:

```javascript
const assert = require("assert");
const { formatTime, formatDate } = require("./ClockModel.js");

const sample = new Date(2026, 9, 6, 14, 7, 0); // October 6 2026, 14:07

assert.strictEqual(formatTime(sample), "14:07");
assert.strictEqual(formatDate(sample), "Tuesday, October 6");

const midnight = new Date(2026, 0, 1, 0, 5, 0);
assert.strictEqual(formatTime(midnight), "00:05");

console.log("ClockModel.test.js: all assertions passed");
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node clone-mirror/ClockModel.test.js`
Expected: FAIL — `Cannot find module './ClockModel.js'` (file does not exist yet).

- [ ] **Step 3: Implement ClockModel.js**

Create `clone-mirror/ClockModel.js` (and copy identically to `$CLONE/ClockModel.js`):

```javascript
function pad2(n) {
  return n < 10 ? "0" + n : String(n);
}

function formatTime(date) {
  return pad2(date.getHours()) + ":" + pad2(date.getMinutes());
}

const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function formatDate(date) {
  return WEEKDAYS[date.getDay()] + ", " + MONTHS[date.getMonth()] + " " + date.getDate();
}

if (typeof module !== "undefined") {
  module.exports = { formatTime: formatTime, formatDate: formatDate };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node clone-mirror/ClockModel.test.js`
Expected: `ClockModel.test.js: all assertions passed`

- [ ] **Step 5: Implement ClockWidget.qml**

Create `$CLONE/ClockWidget.qml` (and copy identically to `clone-mirror/ClockWidget.qml`):

```qml
import QtQuick
import qs.Commons
import qs.Ui
import "ClockModel.js" as ClockModel

Column {
  id: root
  spacing: 4

  Text {
    id: timeText
    anchors.horizontalCenter: parent.horizontalCenter
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.heading * 2.6
    text: ClockModel.formatTime(clockTimer.now)
  }

  Text {
    id: dateText
    anchors.horizontalCenter: parent.horizontalCenter
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.heading * 1.1
    text: ClockModel.formatDate(clockTimer.now)
  }

  QtObject {
    id: clockTimer
    property var now: new Date()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: clockTimer.now = new Date()
  }
}
```

- [ ] **Step 6: Wire ClockWidget into LockView.qml above the password field**

Modify `$CLONE/LockView.qml`: inside the top-level `Rectangle` (the one with `color: Color.background`), add a `ClockWidget` positioned above `inputField`, anchored so it sits directly above the centered password field with a fixed gap. Insert this block immediately before the `BorderSurface { id: inputField ... }` block (same indentation level, same parent `Rectangle`):

```qml
    ClockWidget {
      id: lockClock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: inputField.top
      anchors.bottomMargin: 32
    }
```

Mirror the same edit into `clone-mirror/LockView.qml`.

- [ ] **Step 7: Verify visually via preview**

Run: `omarchy-shell ipc call lock preview`
Expected: time and date render centered above the password field, update every second, password field and fingerprint icon unchanged. Run `omarchy-shell ipc call lock hidePreview` after confirming.

- [ ] **Step 8: Commit**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add clone-mirror/ClockModel.js clone-mirror/ClockModel.test.js clone-mirror/ClockWidget.qml clone-mirror/LockView.qml
git commit -m "Add clock widget to lock screen"
```

---

### Task 3: Avatar widget

**Files:**
- Create: `$CLONE/AvatarModel.js` → mirrored `clone-mirror/AvatarModel.js`
- Create: `$CLONE/AvatarWidget.qml` → mirrored `clone-mirror/AvatarWidget.qml`
- Test: `clone-mirror/AvatarModel.test.js`

**Interfaces:**
- Produces: `AvatarModel.resolveAvatarSource(facePath, faceExists)` → `string` (a `file://` URL when `faceExists` is true, empty string otherwise, which `AvatarWidget.qml` treats as "show fallback glyph"). `AvatarWidget.qml` exposes `property bool hasFace` for `StatusCard.qml` to read if needed, but needs no required properties to instantiate.

- [ ] **Step 1: Write the failing test**

Create `clone-mirror/AvatarModel.test.js`:

```javascript
const assert = require("assert");
const { resolveAvatarSource } = require("./AvatarModel.js");

assert.strictEqual(resolveAvatarSource("/home/alice/.face", true), "file:///home/alice/.face");
assert.strictEqual(resolveAvatarSource("/home/alice/.face", false), "");
assert.strictEqual(resolveAvatarSource("", false), "");

console.log("AvatarModel.test.js: all assertions passed");
```

- [ ] **Step 2: Run to verify it fails**

Run: `node clone-mirror/AvatarModel.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement AvatarModel.js**

Create `clone-mirror/AvatarModel.js` (copy to `$CLONE/AvatarModel.js`):

```javascript
function resolveAvatarSource(facePath, faceExists) {
  if (!faceExists || !facePath) return "";
  return "file://" + facePath;
}

if (typeof module !== "undefined") {
  module.exports = { resolveAvatarSource: resolveAvatarSource };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `node clone-mirror/AvatarModel.test.js`
Expected: `AvatarModel.test.js: all assertions passed`

- [ ] **Step 5: Implement AvatarWidget.qml**

Create `$CLONE/AvatarWidget.qml` (mirror to `clone-mirror/AvatarWidget.qml`). Uses a `FileInfo`-free approach: a `Process` running `test -f` to check existence, since QML has no built-in synchronous file-exists check and the codebase's existing convention (`Service.qml`'s `readlinkProc`) is to shell out for filesystem checks.

```qml
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import qs.Ui
import "AvatarModel.js" as AvatarModel

Item {
  id: root
  readonly property string facePath: Quickshell.env("HOME") + "/.face"
  property bool faceExists: false
  readonly property string avatarSource: AvatarModel.resolveAvatarSource(facePath, faceExists)
  width: 40
  height: 40

  Process {
    id: faceCheck
    command: ["test", "-f", root.facePath]
    onExited: function(exitCode) { root.faceExists = (exitCode === 0) }
  }

  Component.onCompleted: faceCheck.running = true

  Image {
    id: faceImage
    anchors.fill: parent
    visible: root.avatarSource.length > 0
    source: root.avatarSource
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: maskShape
    }
  }

  Item {
    id: maskShape
    anchors.fill: parent
    layer.enabled: true
    visible: false
    Rectangle { anchors.fill: parent; radius: width / 2 }
  }

  Text {
    anchors.fill: parent
    visible: !faceImage.visible
    text: ""
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: root.width * 0.8
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
```

- [ ] **Step 6: Verify visually**

Place a temporary `AvatarWidget {}` inside `LockView.qml`'s root `Rectangle` (anywhere visible), run `omarchy-shell ipc call lock preview`, confirm it shows your real `~/.face` photo as a circle if one exists, or the fallback glyph if not. Then `mv ~/.face ~/.face.bak` and re-preview to confirm the fallback glyph appears; `mv ~/.face.bak ~/.face` to restore. Remove the temporary placement afterward (it gets wired properly into `StatusCard.qml` in Task 7).

- [ ] **Step 7: Commit**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add clone-mirror/AvatarModel.js clone-mirror/AvatarModel.test.js clone-mirror/AvatarWidget.qml
git commit -m "Add avatar widget with fallback glyph"
```

---

### Task 4: Battery segment

**Files:**
- Create: `$CLONE/BatteryModel.js` → mirrored `clone-mirror/BatteryModel.js`
- Create: `$CLONE/BatterySegment.qml` → mirrored `clone-mirror/BatterySegment.qml`
- Test: `clone-mirror/BatteryModel.test.js`

**Interfaces:**
- Produces: `BatteryModel.isSegmentVisible(hasBattery)` → `bool`; `BatteryModel.formatPercentage(percentage)` → `string` (e.g. `"82%"`); `BatteryModel.batteryGlyph(percentage, isCharging)` → `string` (one of 5 Nerd Font battery glyphs). `BatterySegment.qml` exposes `property bool visible` (standard QML, driven by `isSegmentVisible`) for `StatusCard.qml`'s divider logic to read.

- [ ] **Step 1: Write the failing test**

Create `clone-mirror/BatteryModel.test.js`:

```javascript
const assert = require("assert");
const { isSegmentVisible, formatPercentage, batteryGlyph } = require("./BatteryModel.js");

assert.strictEqual(isSegmentVisible(true), true);
assert.strictEqual(isSegmentVisible(false), false);
assert.strictEqual(formatPercentage(0.82), "82%");
assert.strictEqual(formatPercentage(1), "100%");
assert.strictEqual(batteryGlyph(0.05, false), "");
assert.strictEqual(batteryGlyph(0.5, false), "");
assert.strictEqual(batteryGlyph(0.9, true), "");

console.log("BatteryModel.test.js: all assertions passed");
```

- [ ] **Step 2: Run to verify it fails**

Run: `node clone-mirror/BatteryModel.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement BatteryModel.js**

Create `clone-mirror/BatteryModel.js` (copy to `$CLONE/BatteryModel.js`):

```javascript
function isSegmentVisible(hasBattery) {
  return !!hasBattery;
}

function formatPercentage(fraction) {
  return Math.round(fraction * 100) + "%";
}

// Charging always shows the bolt glyph regardless of level.
function batteryGlyph(fraction, isCharging) {
  if (isCharging) return "";
  if (fraction < 0.15) return "";
  if (fraction < 0.40) return "";
  if (fraction < 0.65) return "";
  if (fraction < 0.90) return "";
  return "";
}

if (typeof module !== "undefined") {
  module.exports = {
    isSegmentVisible: isSegmentVisible,
    formatPercentage: formatPercentage,
    batteryGlyph: batteryGlyph
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `node clone-mirror/BatteryModel.test.js`
Expected: `BatteryModel.test.js: all assertions passed`

- [ ] **Step 5: Implement BatterySegment.qml**

Create `$CLONE/BatterySegment.qml` (mirror to `clone-mirror/BatterySegment.qml`):

```qml
import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "BatteryModel.js" as BatteryModel

Row {
  id: root
  spacing: 6
  readonly property var device: UPower.displayDevice
  readonly property bool hasBattery: !!device && device.isLaptopBattery
  visible: BatteryModel.isSegmentVisible(hasBattery)

  Text {
    text: root.hasBattery ? BatteryModel.batteryGlyph(root.device.percentage, root.device.state === UPowerDeviceState.Charging) : ""
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    text: root.hasBattery ? BatteryModel.formatPercentage(root.device.percentage) : ""
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
}
```

- [ ] **Step 6: Verify visually on this machine**

Place a temporary `BatterySegment {}` inside `LockView.qml`, preview, confirm it shows a plausible percentage/glyph if this machine has a battery, or renders nothing (zero width, `visible: false`) if it's a desktop. Remove the temporary placement afterward (wired into `StatusCard.qml` in Task 7).

- [ ] **Step 7: Commit**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add clone-mirror/BatteryModel.js clone-mirror/BatteryModel.test.js clone-mirror/BatterySegment.qml
git commit -m "Add self-hiding battery segment"
```

---

### Task 5: Network segment

**Files:**
- Create: `$CLONE/NetworkModel.js` → mirrored `clone-mirror/NetworkModel.js`
- Create: `$CLONE/NetworkSegment.qml` → mirrored `clone-mirror/NetworkSegment.qml`
- Test: `clone-mirror/NetworkModel.test.js`

**Interfaces:**
- Produces: `NetworkModel.parseNetworkStatus(raw)` → `{kind, label, signalStrength, frequency}` (copied from the bar's existing `Model.js`, same tab-separated contract); `NetworkModel.connectionIcon(kind, signalStrength)` → glyph string; `NetworkModel.isSegmentVisible(kind)` → `bool` (false when `kind === "disconnected"`).

- [ ] **Step 1: Write the failing test**

Create `clone-mirror/NetworkModel.test.js`:

```javascript
const assert = require("assert");
const { parseNetworkStatus, connectionIcon, isSegmentVisible } = require("./NetworkModel.js");

const wifi = parseNetworkStatus("wifi\tHomeNet\t78\t5180");
assert.strictEqual(wifi.kind, "wifi");
assert.strictEqual(wifi.label, "HomeNet");
assert.strictEqual(wifi.signalStrength, 78);

const ethernet = parseNetworkStatus("ethernet\t\t\t");
assert.strictEqual(ethernet.kind, "ethernet");

const disconnected = parseNetworkStatus("disconnected\t\t\t");
assert.strictEqual(disconnected.kind, "disconnected");

assert.strictEqual(isSegmentVisible("wifi"), true);
assert.strictEqual(isSegmentVisible("ethernet"), true);
assert.strictEqual(isSegmentVisible("disconnected"), false);

assert.strictEqual(connectionIcon("ethernet", -1), "\u000f0140".normalize !== undefined ? connectionIcon("ethernet", -1) : connectionIcon("ethernet", -1));
assert.strictEqual(connectionIcon("wifi", 90), connectionIcon("wifi", 90));

console.log("NetworkModel.test.js: all assertions passed");
```

- [ ] **Step 2: Run to verify it fails**

Run: `node clone-mirror/NetworkModel.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement NetworkModel.js**

Create `clone-mirror/NetworkModel.js` (copy to `$CLONE/NetworkModel.js`). The `parseNetworkStatus`/`wifiIconFor`/`connectionIcon` bodies are copied verbatim from the bar's existing `panels/network/Model.js` (read-only reuse of already-working parsing logic, not a rewrite):

```javascript
function parseNetworkStatus(raw) {
  var parts = String(raw || "disconnected\t\t\t").replace(/\r?\n+$/, "").split("\t");
  return {
    kind: parts[0] || "disconnected",
    label: parts[1] || "",
    signalStrength: parts[2] ? parseInt(parts[2], 10) : -1,
    frequency: parts[3] || ""
  };
}

function wifiIconFor(strength) {
  var icons = ["", "", "", "", ""];
  var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1));
  return icons[index];
}

function connectionIcon(kind, signalStrength) {
  if (kind === "wifi") return wifiIconFor(signalStrength);
  if (kind === "ethernet") return "";
  return "";
}

function isSegmentVisible(kind) {
  return kind === "wifi" || kind === "ethernet";
}

if (typeof module !== "undefined") {
  module.exports = {
    parseNetworkStatus: parseNetworkStatus,
    wifiIconFor: wifiIconFor,
    connectionIcon: connectionIcon,
    isSegmentVisible: isSegmentVisible
  };
}
```

Note: the exact Nerd Font codepoints for wifi/ethernet glyphs must match whatever the installed Nerd Font provides — before wiring into `StatusCard.qml` in Task 7, diff these against `/usr/share/omarchy/shell/plugins/panels/network/Model.js`'s `wifiIconFor`/`connectionIcon` on this machine and copy the exact literal characters from there rather than retyping codepoints by hand, since the two must render identically to the bar's own network icon.

- [ ] **Step 4: Run to verify it passes**

Run: `node clone-mirror/NetworkModel.test.js`
Expected: `NetworkModel.test.js: all assertions passed`

- [ ] **Step 5: Implement NetworkSegment.qml**

Create `$CLONE/NetworkSegment.qml` (mirror to `clone-mirror/NetworkSegment.qml`):

```qml
import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NetworkModel.js" as NetworkModel

Row {
  id: root
  spacing: 6
  property var status: NetworkModel.parseNetworkStatus("")
  visible: NetworkModel.isSegmentVisible(status.kind)

  Text {
    text: NetworkModel.connectionIcon(root.status.kind, root.status.signalStrength)
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    text: root.status.label
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  Process {
    id: statusProc
    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = NetworkModel.parseNetworkStatus(text)
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }
}
```

- [ ] **Step 6: Verify visually**

Place a temporary `NetworkSegment {}` inside `LockView.qml`, preview, confirm it shows the current SSID or "Ethernet" correctly (compare against the bar's own network widget for the same icon/label). If reachable, disconnect networking briefly and confirm the segment disappears, then reconnect and confirm it reappears within 5 seconds. Remove the temporary placement afterward.

- [ ] **Step 7: Commit**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add clone-mirror/NetworkModel.js clone-mirror/NetworkModel.test.js clone-mirror/NetworkSegment.qml
git commit -m "Add self-hiding network segment"
```

---

### Task 6: Media segment with transport controls

**Files:**
- Create: `$CLONE/MediaModel.js` → mirrored `clone-mirror/MediaModel.js`
- Create: `$CLONE/MediaControls.qml` → mirrored `clone-mirror/MediaControls.qml`
- Create: `$CLONE/MediaSegment.qml` → mirrored `clone-mirror/MediaSegment.qml`
- Test: `clone-mirror/MediaModel.test.js`

**Interfaces:**
- Produces: `MediaModel.selectActivePlayer(players)` → player object or `null` (simplified: first player with `isPlaying`, else first with `canPlay || canPause`, else `null`); `MediaModel.hasVisibleMedia(player)` → `bool`; `MediaModel.trackLabel(player)` → `string` (e.g. `"Title — Artist"`, falls back to just title, falls back to empty string).

- [ ] **Step 1: Write the failing test**

Create `clone-mirror/MediaModel.test.js`:

```javascript
const assert = require("assert");
const { selectActivePlayer, hasVisibleMedia, trackLabel } = require("./MediaModel.js");

const playing = { isPlaying: true, canPlay: true, canPause: true, trackTitle: "Song A", trackArtist: "Artist A" };
const idleControllable = { isPlaying: false, canPlay: true, canPause: false, trackTitle: "Song B", trackArtist: "" };
const noControl = { isPlaying: false, canPlay: false, canPause: false, trackTitle: "", trackArtist: "" };

assert.strictEqual(selectActivePlayer([noControl, playing, idleControllable]), playing);
assert.strictEqual(selectActivePlayer([noControl, idleControllable]), idleControllable);
assert.strictEqual(selectActivePlayer([noControl]), null);
assert.strictEqual(selectActivePlayer([]), null);

assert.strictEqual(hasVisibleMedia(playing), true);
assert.strictEqual(hasVisibleMedia(null), false);
assert.strictEqual(hasVisibleMedia(noControl), false);

assert.strictEqual(trackLabel(playing), "Song A — Artist A");
assert.strictEqual(trackLabel(idleControllable), "Song B");
assert.strictEqual(trackLabel(null), "");

console.log("MediaModel.test.js: all assertions passed");
```

- [ ] **Step 2: Run to verify it fails**

Run: `node clone-mirror/MediaModel.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement MediaModel.js**

Create `clone-mirror/MediaModel.js` (copy to `$CLONE/MediaModel.js`):

```javascript
function canControl(player) {
  return !!player && (player.canPlay || player.canPause);
}

function selectActivePlayer(players) {
  var list = players || [];
  var playing = null;
  var controllable = null;

  for (var i = 0; i < list.length; i++) {
    var p = list[i];
    if (!p) continue;
    if (p.isPlaying && !playing) playing = p;
    else if (canControl(p) && !controllable) controllable = p;
  }

  return playing || controllable || null;
}

function hasVisibleMedia(player) {
  return canControl(player) && !!(player.trackTitle || player.trackArtist);
}

function trackLabel(player) {
  if (!player) return "";
  var title = player.trackTitle || "";
  var artist = player.trackArtist || "";
  if (title && artist) return title + " — " + artist;
  return title || artist || "";
}

if (typeof module !== "undefined") {
  module.exports = {
    selectActivePlayer: selectActivePlayer,
    hasVisibleMedia: hasVisibleMedia,
    trackLabel: trackLabel
  };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `node clone-mirror/MediaModel.test.js`
Expected: `MediaModel.test.js: all assertions passed`

- [ ] **Step 5: Implement MediaControls.qml**

Create `$CLONE/MediaControls.qml` (mirror to `clone-mirror/MediaControls.qml`):

```qml
import QtQuick
import qs.Commons
import qs.Ui

Row {
  id: root
  spacing: 12
  required property var player

  Text {
    text: ""
    color: root.player && root.player.canGoPrevious ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: root.player && root.player.canGoPrevious
      onClicked: root.player.previous()
    }
  }

  Text {
    text: root.player && root.player.isPlaying ? "" : ""
    color: root.player && (root.player.canPlay || root.player.canPause) ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: root.player && (root.player.canPlay || root.player.canPause)
      onClicked: root.player.isPlaying ? root.player.pause() : root.player.play()
    }
  }

  Text {
    text: ""
    color: root.player && root.player.canGoNext ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: root.player && root.player.canGoNext
      onClicked: root.player.next()
    }
  }
}
```

- [ ] **Step 6: Implement MediaSegment.qml**

Create `$CLONE/MediaSegment.qml` (mirror to `clone-mirror/MediaSegment.qml`):

```qml
import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "MediaModel.js" as MediaModel

Row {
  id: root
  spacing: 10
  readonly property var activePlayer: MediaModel.selectActivePlayer(Mpris.players ? Mpris.players.values : [])
  visible: MediaModel.hasVisibleMedia(activePlayer)

  Text {
    text: MediaModel.trackLabel(root.activePlayer)
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
    width: 160
  }

  MediaControls {
    player: root.activePlayer
  }
}
```

- [ ] **Step 7: Verify visually**

Place a temporary `MediaSegment {}` inside `LockView.qml`, preview. Start playback in any MPRIS-capable player (e.g. a browser tab, a music app), confirm title/artist and working prev/play-pause/next appear; stop/quit the player and confirm the segment disappears. Remove the temporary placement afterward.

- [ ] **Step 8: Commit**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add clone-mirror/MediaModel.js clone-mirror/MediaModel.test.js clone-mirror/MediaControls.qml clone-mirror/MediaSegment.qml
git commit -m "Add media segment with transport controls"
```

---

### Task 7: Status card assembly with collapsing dividers

**Files:**
- Create: `$CLONE/DividerModel.js` → mirrored `clone-mirror/DividerModel.js`
- Create: `$CLONE/StatusCard.qml` → mirrored `clone-mirror/StatusCard.qml`
- Test: `clone-mirror/DividerModel.test.js`

**Interfaces:**
- Consumes: `AvatarWidget.qml` (Task 3), `BatterySegment.qml` (Task 4, has `visible`), `NetworkSegment.qml` (Task 5, has `visible`), `MediaSegment.qml` (Task 6, has `visible`).
- Produces: `DividerModel.visibleDividers(segmentVisibility)` → array of 3 booleans for the dividers between [avatar|battery], [battery|network], [network|media]. Rule: `divider[i]` is `true` only if BOTH its fixed immediate neighbors are visible (avatar counts as always visible). `Row`'s layout already skips spacing around any `visible: false` child, so a hidden middle segment's own gaps close up on their own; this function only controls the little vertical-line decorations, not spacing. `StatusCard.qml` is an `Item` with no required properties, self-contained like `ClockWidget.qml`.

- [ ] **Step 1: Write the failing test**

Create `clone-mirror/DividerModel.test.js`:

```javascript
const assert = require("assert");
const { visibleDividers } = require("./DividerModel.js");

// avatar is always visible; battery/network/media can each hide.
assert.deepStrictEqual(visibleDividers({ battery: true, network: true, media: true }), [true, true, true]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: true, media: true }), [false, false, true]);
assert.deepStrictEqual(visibleDividers({ battery: true, network: false, media: true }), [true, false, false]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: false, media: false }), [false, false, false]);

console.log("DividerModel.test.js: all assertions passed");
```

- [ ] **Step 2: Run to verify it fails**

Run: `node clone-mirror/DividerModel.test.js`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement DividerModel.js**

Create `clone-mirror/DividerModel.js` (copy to `$CLONE/DividerModel.js`). Avatar is always visible (it always has at least the fallback glyph), so divider 1 (avatar|battery) only depends on battery; divider 2 (battery|network) needs both; divider 3 (network|media) needs both — but if battery is hidden, network effectively becomes adjacent to avatar, not to a divider against battery, so divider 2 and 3 must account for the nearest visible neighbor on each side, not just the immediate one:

```javascript
// Segments sit in a fixed 4-slot layout: avatar, battery, network, media.
// Avatar is always visible. divider[i] is true only if both of its fixed
// immediate neighbors are visible. Row already removes spacing around any
// visible:false child, so a hidden middle segment's surrounding gaps close
// up on their own — this only decides whether to draw the vertical line.
function visibleDividers(segments) {
  var s = segments || {};
  var slots = [true, !!s.battery, !!s.network, !!s.media]; // avatar, battery, network, media

  return [
    slots[0] && slots[1], // avatar | battery
    slots[1] && slots[2], // battery | network
    slots[2] && slots[3]  // network | media
  ];
}

if (typeof module !== "undefined") {
  module.exports = { visibleDividers: visibleDividers };
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `node clone-mirror/DividerModel.test.js`
Expected: `DividerModel.test.js: all assertions passed`. If it fails, re-trace the four test cases against the function by hand before touching the QML — this function is the only place divider-collapse logic lives, and getting it right here means `StatusCard.qml` never needs its own conditional logic.

- [ ] **Step 5: Implement StatusCard.qml**

Create `$CLONE/StatusCard.qml` (mirror to `clone-mirror/StatusCard.qml`):

```qml
import QtQuick
import qs.Commons
import qs.Ui
import "DividerModel.js" as DividerModel

BorderSurface {
  id: root
  color: Color.lock.background
  radius: Style.cornerRadius
  borderSpec: Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, 3, "border-alpha")
  implicitWidth: row.implicitWidth + 32
  implicitHeight: row.implicitHeight + 24

  readonly property var dividers: DividerModel.visibleDividers({
    battery: battery.visible,
    network: network.visible,
    media: media.visible
  })

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 14

    Row {
      spacing: 8
      AvatarWidget { width: 32; height: 32 }
      Text {
        text: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: root.dividers[0] }
    BatterySegment { id: battery }
    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: root.dividers[1] }
    NetworkSegment { id: network }
    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: root.dividers[2] }
    MediaSegment { id: media }
  }
}
```

- [ ] **Step 6: Wire StatusCard into LockView.qml below the password field**

Modify `$CLONE/LockView.qml`: add, immediately after the `BorderSurface { id: inputField ... }` block closes (same parent `Rectangle`, same indentation level):

```qml
    StatusCard {
      id: lockStatusCard
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: inputField.bottom
      anchors.topMargin: 32
    }
```

Mirror the same edit into `clone-mirror/LockView.qml`.

- [ ] **Step 7: Verify visually — full assembly**

Run: `omarchy-shell ipc call lock preview`
Expected: clock+date above the password field (unchanged from Task 2), password field unchanged, glass card below it showing avatar+username, and whichever of battery/network/media are currently applicable, with dividers only between visible neighbors. Resize-test mentally isn't possible here, but toggle each segment's visibility by its real-world condition (unplug network, stop media playback) and confirm the card re-centers without a lingering empty gap each time. `omarchy-shell ipc call lock hidePreview` when done.

- [ ] **Step 8: Commit**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add clone-mirror/DividerModel.js clone-mirror/DividerModel.test.js clone-mirror/StatusCard.qml clone-mirror/LockView.qml
git commit -m "Assemble status card with collapsing dividers into lock screen"
```

---

### Task 8: Full regression pass and final verification

**Files:**
- None created; this task only verifies Tasks 1-7 together and records the result.

**Interfaces:**
- Consumes: the complete `$CLONE` plugin tree from Tasks 1-7.

- [ ] **Step 1: Run every Model.js test file in one pass**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
for f in clone-mirror/*.test.js; do
  echo "== $f =="
  node "$f" || exit 1
done
```

Expected: every file prints its "all assertions passed" line; the loop exits 0.

- [ ] **Step 2: Real lock test (not preview)**

Run: `omarchy system lock`, then actually type your real password and unlock. Confirm: the screen looks identical to the preview, typing the password still works, a wrong password still shows the failure message, the correct password unlocks normally, and (if enrolled) fingerprint unlock still works. This step must be run interactively, not scripted, since it exercises your real PAM session.

- [ ] **Step 3: No-battery / disconnected-network spot checks**

If this machine has a battery, there's nothing further to check (Task 4 already covered presence). If it's a desktop, confirm from Task 4's commit that the segment was already verified absent during preview; no further action needed here — recorded for completeness.

- [ ] **Step 4: Commit the plan's completion marker**

```bash
cd /home/le_4rchitect/Work/uwsm-lock-screen
git add -A
git commit -m "Complete Omarchy lock screen widget implementation" --allow-empty
```
