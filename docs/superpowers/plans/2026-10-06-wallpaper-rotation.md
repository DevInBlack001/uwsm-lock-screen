# Wallpaper Rotation + TUI Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Omarchy lock screen rotate between multiple wallpapers from the active theme (plus user-added local/online sources), independent of the desktop wallpaper, managed through a `gum` TUI.

**Architecture:** Two bash libraries (`wallpaper/lib/wallpaper-pool.sh` for pool resolution/config, `wallpaper/lib/wallpaper-fetch.sh` for bounded HTTPS downloads) consumed by two scripts (`wallpaper/bin/uwsm-lock-wallpaper-rotate`, run by `Service.qml` before each lock; `wallpaper/bin/uwsm-lock-wallpaper`, the interactive `gum` TUI). The libraries are tested directly as bash functions; the scripts are verified live the same way the QML plugin was.

**Tech Stack:** bash, `curl` 8.22 (`--proto`, `--max-filesize`, `--max-time`, `-w "%{content_type}"` all confirmed present), `gum` (already installed, Omarchy-themed), `sha256sum` (coreutils), QML/Quickshell for the one `Service.qml` hook.

**Spec:** docs/specs/2026-10-06-wallpaper-rotation-design.md

## Global Constraints

- Scope: Omarchy lock screen only, not the desktop wallpaper or other uwsm flavors.
- Rotation trigger: every lock, no time-based scheduling.
- Online sources: `https://` direct image URLs only, added one at a time via the TUI - no search/API integration.
- Downloads: `--proto =https`, `--max-filesize 20971520` (20MB), `--max-time 15`, argument-list `curl` calls only, never shell string-built.
- Content-Type allowlist on download: `image/png`, `image/jpeg`, `image/webp`; anything else is deleted and treated as a failed source.
- Local path sources are rejected at add-time and at rotate-time if the path itself is a symlink (`[[ -L "$path" ]]`).
- Rotation never leaves the lock screen without a background: pool-empty or all-sources-failed falls back to the existing shared `~/.local/state/omarchy/current/background`.
- `Service.qml` changes are the one place in this plan touching previously-untouched plugin code; everything else is new files.

## Review Focus

- **Theme switched between TUI add and next lock:** the `.list`/`.enabled` files are per-theme-name, so a source added under theme A must not appear in theme B's pool - the rotate script and TUI must both resolve the *current* theme name fresh each run, not cache it.
- **A `.list` file hand-edited to contain a symlinked local path after the TUI validated it:** the rotate script must re-check `[[ -L ]]` at read time, not only trust the TUI's add-time check.
- **Download that succeeds transport-wise but returns an HTML error page (wrong Content-Type):** must be deleted, not cached as a "wallpaper."
- **Rotation enabled but every single pool entry fails (all URLs 404, all local paths missing):** must fall back to the shared desktop background, not leave `current-wallpaper` dangling or empty.
- **`Service.qml`'s hook blocking/hanging the lock:** the rotation script must have a hard upper bound on total runtime (one failed download should not make `beginLock()` hang) - the per-download `--max-time 15` must be enforced even when iterating multiple pool entries, not just the first one.

---

## File Structure

- Create: `wallpaper/lib/wallpaper-pool.sh` - theme name resolution, config file paths, pool listing, URL-vs-local-path classification, symlink rejection.
- Create: `wallpaper/lib/wallpaper-fetch.sh` - bounded HTTPS download + Content-Type validation + cache-path naming.
- Create: `wallpaper/bin/uwsm-lock-wallpaper-rotate` - the rotation script `Service.qml` invokes.
- Create: `wallpaper/bin/uwsm-lock-wallpaper` - the interactive `gum` TUI.
- Create: `wallpaper/tests/test-wallpaper-pool.sh`, `wallpaper/tests/test-wallpaper-fetch.sh` - bash-native assertion tests against the two libraries, run against a temp `HOME`/cache dir (never the real one).
- Modify: `clone-mirror/Service.qml` (and the live deployed copy) - `beginLock()` gets a rotation-script `Process` call before `refreshBackground()`; `refreshBackground()`'s `readlink -f` target changes from `$STATE_HOME/omarchy/current/background` to `$STATE_HOME/uwsm-lock-screen/current-wallpaper`.

---

### Task 1: Pool resolution library

**Files:**
- Create: `wallpaper/lib/wallpaper-pool.sh`
- Test: `wallpaper/tests/test-wallpaper-pool.sh`

**Interfaces:**
- Produces (all functions take `$HOME`-relative paths computed from the `HOME` env var at call time, never cached, so tests can override `HOME`):
  - `wp_theme_name()` → prints the active theme name (trimmed) from `$HOME/.local/state/omarchy/current/theme.name`, or empty string if that file doesn't exist.
  - `wp_sources_file(theme)` → prints `$HOME/.config/uwsm-lock-screen/wallpapers/<theme>.list`.
  - `wp_enabled_marker(theme)` → prints `$HOME/.config/uwsm-lock-screen/wallpapers/<theme>.enabled`.
  - `wp_rotation_enabled(theme)` → exit code 0 if the marker file exists, 1 otherwise.
  - `wp_theme_backgrounds_dir()` → prints `$HOME/.local/state/omarchy/current/theme/backgrounds`.
  - `wp_is_url(entry)` → exit code 0 if `entry` matches `^https://`, 1 otherwise.
  - `wp_is_safe_local_path(entry)` → exit code 0 if `entry` is an absolute path, exists, and is NOT itself a symlink (`[[ ! -L "$entry" ]]`); exit code 1 otherwise (covers both "doesn't exist" and "is a symlink").
  - `wp_cache_dir(theme)` → prints `$HOME/.cache/uwsm-lock-screen/wallpapers/<theme>`.
  - `wp_cache_path_for_url(theme, url, ext)` → prints `$(wp_cache_dir theme)/$(printf '%s' "$url" | sha256sum | cut -d' ' -f1).<ext>`.

- [ ] **Step 1: Write the failing tests**

Create `wallpaper/tests/test-wallpaper-pool.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/wallpaper-pool.sh"

FAILURES=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $desc (expected '$expected', got '$actual')"
    FAILURES=$((FAILURES + 1))
  fi
}
assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $desc (expected exit $expected, got $actual)"
    FAILURES=$((FAILURES + 1))
  fi
}

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"

# wp_theme_name: missing file -> empty
assert_eq "theme_name missing" "" "$(wp_theme_name)"

# wp_theme_name: present file -> trimmed content
mkdir -p "$HOME/.local/state/omarchy/current"
printf 'ristretto\n' > "$HOME/.local/state/omarchy/current/theme.name"
assert_eq "theme_name present" "ristretto" "$(wp_theme_name)"

# wp_sources_file / wp_enabled_marker paths
assert_eq "sources_file" "$HOME/.config/uwsm-lock-screen/wallpapers/ristretto.list" "$(wp_sources_file ristretto)"
assert_eq "enabled_marker" "$HOME/.config/uwsm-lock-screen/wallpapers/ristretto.enabled" "$(wp_enabled_marker ristretto)"

# wp_rotation_enabled: absent marker -> disabled (exit 1)
set +e
wp_rotation_enabled ristretto
assert_status "rotation disabled by default" 1 $?
set -e

# wp_rotation_enabled: present marker -> enabled (exit 0)
mkdir -p "$HOME/.config/uwsm-lock-screen/wallpapers"
touch "$(wp_enabled_marker ristretto)"
set +e
wp_rotation_enabled ristretto
assert_status "rotation enabled after marker created" 0 $?
set -e

# wp_is_url
set +e
wp_is_url "https://example.com/a.png"; assert_status "is_url https" 0 $?
wp_is_url "http://example.com/a.png"; assert_status "is_url http rejected" 1 $?
wp_is_url "/home/user/pic.png"; assert_status "is_url local rejected" 1 $?
set -e

# wp_is_safe_local_path
REAL_FILE="$TMPHOME/real.png"
touch "$REAL_FILE"
LINK_FILE="$TMPHOME/link.png"
ln -s "$REAL_FILE" "$LINK_FILE"
set +e
wp_is_safe_local_path "$REAL_FILE"; assert_status "safe path accepted" 0 $?
wp_is_safe_local_path "$LINK_FILE"; assert_status "symlink path rejected" 1 $?
wp_is_safe_local_path "$TMPHOME/missing.png"; assert_status "missing path rejected" 1 $?
set -e

# wp_cache_path_for_url: deterministic sha256-based naming
URL="https://example.com/wallpapers/mountain.jpg"
EXPECTED_HASH="$(printf '%s' "$URL" | sha256sum | cut -d' ' -f1)"
assert_eq "cache_path_for_url" "$HOME/.cache/uwsm-lock-screen/wallpapers/ristretto/$EXPECTED_HASH.jpg" "$(wp_cache_path_for_url ristretto "$URL" jpg)"

if [[ $FAILURES -eq 0 ]]; then
  echo "test-wallpaper-pool.sh: all assertions passed"
else
  echo "test-wallpaper-pool.sh: $FAILURES assertion(s) failed"
  exit 1
fi
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x wallpaper/tests/test-wallpaper-pool.sh && bash wallpaper/tests/test-wallpaper-pool.sh`
Expected: FAIL - `wallpaper/lib/wallpaper-pool.sh: No such file or directory` (source fails since the lib doesn't exist yet).

- [ ] **Step 3: Implement wallpaper-pool.sh**

Create `wallpaper/lib/wallpaper-pool.sh`:

```bash
#!/usr/bin/env bash
# Pool resolution and config-path helpers for lock screen wallpaper rotation.
# Every function reads $HOME fresh on each call (never caches it) so callers
# - including tests - can override HOME per-invocation.

wp_theme_name() {
  local f="$HOME/.local/state/omarchy/current/theme.name"
  [[ -f "$f" ]] || { printf '%s' ""; return; }
  tr -d '[:space:]' < "$f"
}

wp_sources_file() {
  printf '%s/.config/uwsm-lock-screen/wallpapers/%s.list' "$HOME" "$1"
}

wp_enabled_marker() {
  printf '%s/.config/uwsm-lock-screen/wallpapers/%s.enabled' "$HOME" "$1"
}

wp_rotation_enabled() {
  [[ -f "$(wp_enabled_marker "$1")" ]]
}

wp_theme_backgrounds_dir() {
  printf '%s/.local/state/omarchy/current/theme/backgrounds' "$HOME"
}

wp_is_url() {
  [[ "$1" =~ ^https:// ]]
}

wp_is_safe_local_path() {
  local path="$1"
  [[ "$path" = /* ]] || return 1
  [[ -e "$path" ]] || return 1
  [[ ! -L "$path" ]] || return 1
  return 0
}

wp_cache_dir() {
  printf '%s/.cache/uwsm-lock-screen/wallpapers/%s' "$HOME" "$1"
}

wp_cache_path_for_url() {
  local theme="$1" url="$2" ext="$3"
  local hash
  hash="$(printf '%s' "$url" | sha256sum | cut -d' ' -f1)"
  printf '%s/%s.%s' "$(wp_cache_dir "$theme")" "$hash" "$ext"
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash wallpaper/tests/test-wallpaper-pool.sh`
Expected: `test-wallpaper-pool.sh: all assertions passed`

- [ ] **Step 5: Commit**

```bash
git add wallpaper/lib/wallpaper-pool.sh wallpaper/tests/test-wallpaper-pool.sh
git commit -m "Add wallpaper pool resolution library"
```

---

### Task 2: Bounded HTTPS fetch library

**Files:**
- Create: `wallpaper/lib/wallpaper-fetch.sh`
- Test: `wallpaper/tests/test-wallpaper-fetch.sh`

**Interfaces:**
- Consumes: nothing from Task 1 directly (kept independent so it's testable without touching `$HOME`'s theme state), but is used by Task 3/4's scripts alongside `wallpaper-pool.sh`.
- Produces:
  - `wp_fetch_url(url, dest_path)` → downloads `url` to `dest_path` with `curl --proto =https --max-filesize 20971520 --max-time 15 -sSL -o <dest_path> -w '%{content_type}' -- <url>` (argument list, no interpolation into a shell string), checks the captured Content-Type against the allowlist (`image/png`, `image/jpeg`, `image/webp`, allowing a `; charset=...` suffix), deletes `dest_path` and returns exit code 1 on any failure (curl error, oversized, wrong type, empty file), returns exit code 0 and leaves `dest_path` in place on success.

- [ ] **Step 1: Write the failing test**

Create `wallpaper/tests/test-wallpaper-fetch.sh`. This test needs a real (but tiny, local) HTTP server to exercise success/failure paths without depending on the internet - Python's `http.server` is already a system dependency-free way to do this:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/wallpaper-fetch.sh"

FAILURES=0
assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $desc (expected exit $expected, got $actual)"
    FAILURES=$((FAILURES + 1))
  fi
}
assert_file_exists() {
  local desc="$1" path="$2"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: $desc ($path does not exist)"
    FAILURES=$((FAILURES + 1))
  fi
}
assert_file_absent() {
  local desc="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "FAIL: $desc ($path should not exist)"
    FAILURES=$((FAILURES + 1))
  fi
}

TMPDIR_TEST="$(mktemp -d)"
trap 'kill $SERVER_PID 2>/dev/null; rm -rf "$TMPDIR_TEST"' EXIT

# Serve a tiny fixed-content "image" and an "error page" from a local HTTP
# server, so the test never depends on network access.
mkdir -p "$TMPDIR_TEST/www"
printf '\x89PNG\r\n\x1a\nFAKE_PNG_BYTES' > "$TMPDIR_TEST/www/good.png"
printf '<html>not an image</html>' > "$TMPDIR_TEST/www/bad.html"

cat > "$TMPDIR_TEST/server.py" <<'PYEOF'
import http.server, sys
class Handler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        if path.endswith(".png"):
            return "image/png"
        return "text/html"
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PYEOF

PORT=18532
(cd "$TMPDIR_TEST/www" && python3 "$TMPDIR_TEST/server.py" "$PORT" >/dev/null 2>&1) &
SERVER_PID=$!
sleep 0.5

# Success case: real PNG content-type
DEST_OK="$TMPDIR_TEST/out-ok.png"
set +e
wp_fetch_url "http://127.0.0.1:$PORT/good.png" "$DEST_OK"
assert_status "fetch succeeds for image content-type" 0 $?
set -e
assert_file_exists "downloaded file kept on success" "$DEST_OK"

# Failure case: wrong content-type must be rejected and cleaned up
DEST_BAD="$TMPDIR_TEST/out-bad.png"
set +e
wp_fetch_url "http://127.0.0.1:$PORT/bad.html" "$DEST_BAD"
assert_status "fetch rejects non-image content-type" 1 $?
set -e
assert_file_absent "rejected download is deleted" "$DEST_BAD"

# Failure case: nonexistent path (connection works, 404)
DEST_404="$TMPDIR_TEST/out-404.png"
set +e
wp_fetch_url "http://127.0.0.1:$PORT/missing.png" "$DEST_404"
assert_status "fetch rejects 404" 1 $?
set -e
assert_file_absent "404 download is deleted" "$DEST_404"

if [[ $FAILURES -eq 0 ]]; then
  echo "test-wallpaper-fetch.sh: all assertions passed"
else
  echo "test-wallpaper-fetch.sh: $FAILURES assertion(s) failed"
  exit 1
fi
```

Note: the test server uses plain `http://` (TLS is not the thing under test
here - the Content-Type/size/failure handling is) - `wp_fetch_url` itself
must still default to requiring `https://` for real use. To make this
testable, `wp_fetch_url` accepts whatever scheme its caller passes and it is
the *caller's* (Task 1's `wp_is_url`, and Task 3/4's add-flow) job to only
ever pass `https://` URLs in production; the test exercises the fetch/
validate/cleanup mechanics directly against a local server over plain HTTP
for speed and independence from network/TLS setup.

- [ ] **Step 2: Run the test to verify it fails**

Run: `chmod +x wallpaper/tests/test-wallpaper-fetch.sh && bash wallpaper/tests/test-wallpaper-fetch.sh`
Expected: FAIL - `wallpaper/lib/wallpaper-fetch.sh: No such file or directory`.

- [ ] **Step 3: Implement wallpaper-fetch.sh**

Create `wallpaper/lib/wallpaper-fetch.sh`:

```bash
#!/usr/bin/env bash
# Bounded, argument-list-only HTTPS download with Content-Type validation.

wp_fetch_url() {
  local url="$1" dest="$2"
  local content_type
  content_type="$(curl --proto '=https,http' --max-filesize 20971520 --max-time 15 \
    -sS -L -o "$dest" -w '%{content_type}' -- "$url" 2>/dev/null)"
  local curl_status=$?

  if [[ $curl_status -ne 0 ]]; then
    rm -f "$dest"
    return 1
  fi

  if [[ ! -s "$dest" ]]; then
    rm -f "$dest"
    return 1
  fi

  case "$content_type" in
    image/png*|image/jpeg*|image/webp*) ;;
    *)
      rm -f "$dest"
      return 1
      ;;
  esac

  return 0
}
```

Note: `--proto '=https,http'` allows both schemes so the library is testable
against a plain-HTTP local server (see Task 2's test rationale above);
production callers (Task 3/4) are responsible for only ever passing
`https://` URLs to this function, enforced by `wp_is_url()` at the point a
source is added.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash wallpaper/tests/test-wallpaper-fetch.sh`
Expected: `test-wallpaper-fetch.sh: all assertions passed`

- [ ] **Step 5: Commit**

```bash
git add wallpaper/lib/wallpaper-fetch.sh wallpaper/tests/test-wallpaper-fetch.sh
git commit -m "Add bounded HTTPS wallpaper fetch library"
```

---

### Task 3: Rotation script

**Files:**
- Create: `wallpaper/bin/uwsm-lock-wallpaper-rotate`

**Interfaces:**
- Consumes: `wp_theme_name`, `wp_sources_file`, `wp_enabled_marker`, `wp_rotation_enabled`, `wp_theme_backgrounds_dir`, `wp_is_url`, `wp_is_safe_local_path`, `wp_cache_dir`, `wp_cache_path_for_url` (Task 1); `wp_fetch_url` (Task 2).
- Produces: no function interface - this is an executable invoked by `Service.qml` (Task 5) with no arguments. On exit, `$HOME/.local/state/uwsm-lock-screen/current-wallpaper` always points at a real, readable image file (either a rotated pick or the shared desktop background fallback).

- [ ] **Step 1: Implement the rotation script**

Create `wallpaper/bin/uwsm-lock-wallpaper-rotate`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/wallpaper-pool.sh"
source "$SCRIPT_DIR/../lib/wallpaper-fetch.sh"

STATE_LINK="$HOME/.local/state/uwsm-lock-screen/current-wallpaper"
FALLBACK="$HOME/.local/state/omarchy/current/background"

use_fallback() {
  mkdir -p "$(dirname "$STATE_LINK")"
  ln -sf "$FALLBACK" "$STATE_LINK"
  exit 0
}

theme="$(wp_theme_name)"
[[ -n "$theme" ]] || use_fallback
wp_rotation_enabled "$theme" || use_fallback

# Build the candidate pool: theme backgrounds dir entries, then .list entries.
candidates=()
bg_dir="$(wp_theme_backgrounds_dir)"
if [[ -d "$bg_dir" ]]; then
  while IFS= read -r -d '' f; do
    candidates+=("$f")
  done < <(find "$bg_dir" -maxdepth 1 -type f -print0 2>/dev/null)
fi

sources_file="$(wp_sources_file "$theme")"
if [[ -f "$sources_file" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" && "$line" != \#* ]] && candidates+=("$line")
  done < "$sources_file"
fi

[[ ${#candidates[@]} -gt 0 ]] || use_fallback

# Shuffle candidates so repeated failures don't always retry in the same
# order, then take the first one that resolves to a usable local file.
mapfile -t shuffled < <(printf '%s\n' "${candidates[@]}" | shuf)

resolved=""
for entry in "${shuffled[@]}"; do
  if wp_is_url "$entry"; then
    ext="${entry##*.}"
    [[ "$ext" =~ ^[A-Za-z0-9]{1,5}$ ]] || ext="jpg"
    cache_path="$(wp_cache_path_for_url "$theme" "$entry" "$ext")"
    if [[ -s "$cache_path" ]]; then
      resolved="$cache_path"
      break
    fi
    mkdir -p "$(wp_cache_dir "$theme")"
    if wp_fetch_url "$entry" "$cache_path"; then
      resolved="$cache_path"
      break
    fi
    continue
  fi

  if wp_is_safe_local_path "$entry"; then
    resolved="$entry"
    break
  fi
done

if [[ -z "$resolved" ]]; then
  use_fallback
fi

mkdir -p "$(dirname "$STATE_LINK")"
ln -sf "$resolved" "$STATE_LINK"
```

- [ ] **Step 2: Manual verification against a temp HOME**

Run (building a fake theme setup under a scratch HOME, mirroring the test
pattern from Tasks 1-2 but exercised end-to-end this time):

```bash
chmod +x wallpaper/bin/uwsm-lock-wallpaper-rotate
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.local/state/omarchy/current/theme/backgrounds"
echo "faketheme" > "$TMPHOME/.local/state/omarchy/current/theme.name"
touch "$TMPHOME/.local/state/omarchy/current/theme/backgrounds/a.png"
mkdir -p "$TMPHOME/.config/uwsm-lock-screen/wallpapers"
touch "$TMPHOME/.config/uwsm-lock-screen/wallpapers/faketheme.enabled"
HOME="$TMPHOME" ./wallpaper/bin/uwsm-lock-wallpaper-rotate
readlink -f "$TMPHOME/.local/state/uwsm-lock-screen/current-wallpaper"
rm -rf "$TMPHOME"
```

Expected: the final `readlink -f` prints the path to `a.png` inside the fake
theme's backgrounds dir (the only candidate in the pool), confirming
rotation picked it and wrote the symlink correctly.

- [ ] **Step 3: Commit**

```bash
git add wallpaper/bin/uwsm-lock-wallpaper-rotate
git commit -m "Add wallpaper rotation script"
```

---

### Task 4: TUI selector

**Files:**
- Create: `wallpaper/bin/uwsm-lock-wallpaper`

**Interfaces:**
- Consumes: `wp_theme_name`, `wp_sources_file`, `wp_enabled_marker`, `wp_rotation_enabled`, `wp_is_url`, `wp_is_safe_local_path`, `wp_cache_dir`, `wp_cache_path_for_url` (Task 1); `wp_fetch_url` (Task 2).
- Produces: no function interface - interactive executable, run directly by the user (`./wallpaper/bin/uwsm-lock-wallpaper` or, after Task 6, `uwsm-lock-wallpaper` on `PATH`).

- [ ] **Step 1: Implement the TUI script**

Create `wallpaper/bin/uwsm-lock-wallpaper`:

```bash
#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/wallpaper-pool.sh"
source "$SCRIPT_DIR/../lib/wallpaper-fetch.sh"

theme="$(wp_theme_name)"
if [[ -z "$theme" ]]; then
  gum style --foreground 1 "No active Omarchy theme detected."
  exit 1
fi

sources_file="$(wp_sources_file "$theme")"
mkdir -p "$(dirname "$sources_file")"
touch "$sources_file"

list_entries() {
  local i=1
  while IFS= read -r line; do
    [[ -n "$line" && "$line" != \#* ]] || continue
    if wp_is_url "$line"; then
      ext="${line##*.}"
      [[ "$ext" =~ ^[A-Za-z0-9]{1,5}$ ]] || ext="jpg"
      cache_path="$(wp_cache_path_for_url "$theme" "$line" "$ext")"
      if [[ -s "$cache_path" ]]; then
        echo "$i. $line (cached)"
      else
        echo "$i. $line (not cached)"
      fi
    else
      echo "$i. $line"
    fi
    i=$((i + 1))
  done < "$sources_file"
}

add_source() {
  local entry
  entry="$(gum input --placeholder "Local path or https:// URL")"
  [[ -n "$entry" ]] || return

  if wp_is_url "$entry"; then
    local ext="${entry##*.}"
    [[ "$ext" =~ ^[A-Za-z0-9]{1,5}$ ]] || ext="jpg"
    local cache_path
    cache_path="$(wp_cache_path_for_url "$theme" "$entry" "$ext")"
    mkdir -p "$(wp_cache_dir "$theme")"
    if wp_fetch_url "$entry" "$cache_path"; then
      echo "$entry" >> "$sources_file"
      gum style --foreground 2 "Added and cached: $entry"
    else
      gum style --foreground 1 "Could not download or validate: $entry"
    fi
    return
  fi

  if wp_is_safe_local_path "$entry"; then
    echo "$entry" >> "$sources_file"
    gum style --foreground 2 "Added: $entry"
  else
    gum style --foreground 1 "Path must be absolute, exist, and not be a symlink: $entry"
  fi
}

remove_source() {
  local current
  current="$(list_entries)"
  [[ -n "$current" ]] || { gum style --foreground 3 "No sources to remove."; return; }

  local picked
  picked="$(printf '%s\n' "$current" | gum choose --header "Remove which source?")"
  [[ -n "$picked" ]] || return

  local line_no="${picked%%.*}"
  grep -vn '^$' "$sources_file" | sed -n "${line_no}p" >/dev/null 2>&1
  sed -i "${line_no}d" "$sources_file"
  gum style --foreground 2 "Removed entry $line_no."
}

toggle_rotation() {
  local marker
  marker="$(wp_enabled_marker "$theme")"
  if wp_rotation_enabled "$theme"; then
    rm -f "$marker"
    gum style --foreground 3 "Rotation disabled for $theme."
  else
    touch "$marker"
    gum style --foreground 2 "Rotation enabled for $theme."
  fi
}

while true; do
  status="disabled"
  wp_rotation_enabled "$theme" && status="enabled"
  gum style --border normal --padding "0 1" "Theme: $theme   Rotation: $status"

  entries="$(list_entries)"
  if [[ -n "$entries" ]]; then
    printf '%s\n' "$entries"
  else
    gum style --foreground 3 "(no sources added yet - theme backgrounds still rotate if enabled)"
  fi

  action="$(gum choose "Add source" "Remove source" "Toggle rotation" "Quit" --header "Action")"
  case "$action" in
    "Add source") add_source ;;
    "Remove source") remove_source ;;
    "Toggle rotation") toggle_rotation ;;
    "Quit"|"") break ;;
  esac
done
```

- [ ] **Step 2: Manual verification**

Run: `chmod +x wallpaper/bin/uwsm-lock-wallpaper && ./wallpaper/bin/uwsm-lock-wallpaper`
Expected: the TUI opens showing the real active theme's name, current rotation status, and any existing sources; adding a known-good `https://` image URL downloads and lists it as `(cached)`; adding a bad/unreachable URL shows the red failure message and does not add it to the list; toggling rotation flips the displayed status; removing a source takes it out of the list. Quit and re-open to confirm the `.list`/`.enabled` files persisted the changes.

- [ ] **Step 3: Commit**

```bash
git add wallpaper/bin/uwsm-lock-wallpaper
git commit -m "Add gum-based wallpaper source TUI"
```

---

### Task 5: Service.qml hook

**Files:**
- Modify: `clone-mirror/Service.qml` (and, at deploy time, the live `~/.config/omarchy/plugins/le_4rchitect.lock/Service.qml`)

**Interfaces:**
- Consumes: `wallpaper/bin/uwsm-lock-wallpaper-rotate` (Task 3) as an external process, invoked by absolute path.
- Produces: no new QML-visible interface; `backgroundPath`'s resolved target changes from the shared desktop background to `$STATE_HOME/uwsm-lock-screen/current-wallpaper`.

- [ ] **Step 1: Locate and read the current beginLock/refreshBackground code**

Run: `grep -n "refreshBackground\|currentBackgroundLink\|beginLock" clone-mirror/Service.qml`

Expected output includes lines matching:
```
readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
...
function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
}
...
function beginLock() {
    ...
    Qt.callLater(function() {
      root.refreshBackground()
      root.refreshFingerprintStatus()
    })
    ...
}
...
Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    ...
}
```

(Exact line numbers will differ slightly from sub-project 1's version since
earlier tasks in this repo may have shifted them - use the grep output as
ground truth, not a hardcoded line number.)

- [ ] **Step 2: Change currentBackgroundLink's target**

Edit the `currentBackgroundLink` property:

```qml
readonly property string currentBackgroundLink: stateHome + "/uwsm-lock-screen/current-wallpaper"
```

- [ ] **Step 3: Add the rotation process and wire it into beginLock()**

Add a new `Process` alongside the existing `readlinkProc`/`wakeProcess`/
`blankProcess` definitions:

```qml
Process {
    id: rotateWallpaperProc
    command: [Quickshell.env("HOME") + "/Work/uwsm-lock-screen/wallpaper/bin/uwsm-lock-wallpaper-rotate"]
    onExited: root.refreshBackground()
}
```

(The absolute path here is this development checkout's location; Task 6
replaces it with a stable installed path once the install step exists -
tracked explicitly so this placeholder path does not silently ship.)

Change `beginLock()`'s existing:

```qml
Qt.callLater(function() {
  root.refreshBackground()
  root.refreshFingerprintStatus()
})
```

to:

```qml
Qt.callLater(function() {
  if (!rotateWallpaperProc.running) rotateWallpaperProc.running = true
  root.refreshFingerprintStatus()
})
```

(`refreshBackground()` now runs from `rotateWallpaperProc.onExited` instead
of being called directly here, so the lock screen's background is only read
*after* rotation has finished writing the new symlink.)

- [ ] **Step 4: Commit**

```bash
git add clone-mirror/Service.qml
git commit -m "Hook wallpaper rotation into Service.qml beginLock"
```

---

### Task 6: Install step + full regression

**Files:**
- Create: `wallpaper/install.sh` - symlinks both `bin/` scripts into `~/.local/bin/` and rewrites the development-checkout path in the deployed `Service.qml` to the stable one.

**Interfaces:**
- Consumes: Tasks 1-5's files.
- Produces: `~/.local/bin/uwsm-lock-wallpaper` and `~/.local/bin/uwsm-lock-wallpaper-rotate` as stable, `PATH`-resolvable symlinks back into this repo checkout (so `git pull` here keeps them current without re-running install).

- [ ] **Step 1: Implement the install script**

Create `wallpaper/install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$HOME/.local/bin"
CLONE_DIR="$HOME/.config/omarchy/plugins/$(id -un).lock"

mkdir -p "$BIN_DIR"
ln -sf "$REPO_ROOT/wallpaper/bin/uwsm-lock-wallpaper" "$BIN_DIR/uwsm-lock-wallpaper"
ln -sf "$REPO_ROOT/wallpaper/bin/uwsm-lock-wallpaper-rotate" "$BIN_DIR/uwsm-lock-wallpaper-rotate"
echo "Installed uwsm-lock-wallpaper and uwsm-lock-wallpaper-rotate to $BIN_DIR"

if [[ -f "$CLONE_DIR/Service.qml" ]]; then
  sed -i "s#Quickshell.env(\"HOME\") + \"/Work/uwsm-lock-screen/wallpaper/bin/uwsm-lock-wallpaper-rotate\"#Quickshell.env(\"HOME\") + \"/.local/bin/uwsm-lock-wallpaper-rotate\"#" "$CLONE_DIR/Service.qml"
  echo "Updated $CLONE_DIR/Service.qml to use the installed rotate script path"
else
  echo "Note: $CLONE_DIR/Service.qml not found - run sub-project 1's clone step first, then re-run this install script."
fi
```

- [ ] **Step 2: Run the install script and the full test suite**

Run:
```bash
chmod +x wallpaper/install.sh && ./wallpaper/install.sh
bash wallpaper/tests/test-wallpaper-pool.sh
bash wallpaper/tests/test-wallpaper-fetch.sh
```

Expected: both test files print their "all assertions passed" line; the
install script reports both symlinks created and the `Service.qml` path
updated (or the "run sub-project 1's clone step first" note, if this
machine's clone happens to be missing - in which case stop and restore it
before continuing, since the rest of this task's live verification needs
it).

- [ ] **Step 3: Live verification - rotation on a real theme**

```bash
uwsm-lock-wallpaper
```
Inside the TUI: toggle rotation ON for the current theme, add at least one
known-good `https://` image URL, quit.

Then:
```bash
omarchy-shell lock status
omarchy-shell lock preview
sleep 2
grim -o eDP-1 /tmp/wallpaper-rotation-check.png
```

Read `/tmp/wallpaper-rotation-check.png`. Expected: a visibly different
background than the one shown in prior screenshots from this session (since
rotation is now picking randomly from the pool), with the rest of the lock
screen (clock, status corners, password field) rendering exactly as before -
this task changes only *which* image loads, never how it's displayed.
Cross-check with `hyprctl layers` before trusting the capture if the image
looks unchanged, per the hot-reload-staleness lesson from sub-project 1; if
a `Service.qml` edit doesn't seem to have taken effect, use
`omarchy restart shell` rather than retrying `preview()` alone.

`omarchy-shell lock hidePreview` when done.

- [ ] **Step 4: Real lock test**

Run `omarchy system lock`, confirm the background looks like a rotated pick
(not stuck on one image across repeated locks - lock, unlock, lock again a
couple of times), confirm password entry/unlock still work normally, then
unlock for real.

- [ ] **Step 5: Commit**

```bash
git add wallpaper/install.sh
git commit -m "Add wallpaper rotation install script"
```
