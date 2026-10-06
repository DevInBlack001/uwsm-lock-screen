#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROTATE_SCRIPT="$SCRIPT_DIR/../bin/uwsm-lock-wallpaper-rotate"

FAILURES=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $desc (expected '$expected', got '$actual')"
    FAILURES=$((FAILURES + 1))
  fi
}

# Each case gets a fresh scratch $HOME so none of these interfere with each
# other or with the real $HOME - the rotate script is invoked as a real
# subprocess (it's a top-level script, not a sourceable function library),
# with HOME overridden for that one invocation only.
new_fixture_home() {
  local h
  h="$(mktemp -d)"
  mkdir -p "$h/.local/state/omarchy/current/theme/backgrounds"
  mkdir -p "$h/.config/uwsm-lock-screen/wallpapers"
  mkdir -p "$h/.local/state/omarchy/current"
  touch "$h/.local/state/omarchy/current/background"
  echo "testtheme" > "$h/.local/state/omarchy/current/theme.name"
  printf '%s' "$h"
}

run_rotate() {
  local h="$1"
  HOME="$h" "$ROTATE_SCRIPT" >/dev/null 2>&1
}

resolved_target() {
  local h="$1"
  readlink -f "$h/.local/state/uwsm-lock-screen/current-wallpaper"
}

# Case 1: no sources at all (empty theme backgrounds dir, no .list file) ->
# falls back to the shared desktop background.
HOME1="$(new_fixture_home)"
run_rotate "$HOME1"
assert_eq "empty pool falls back to shared background" \
  "$(readlink -f "$HOME1/.local/state/omarchy/current/background")" \
  "$(resolved_target "$HOME1")"
rm -rf "$HOME1"

# Case 2: rotation explicitly disabled for the theme -> falls back even
# though a real candidate exists in the pool.
HOME2="$(new_fixture_home)"
touch "$HOME2/.local/state/omarchy/current/theme/backgrounds/a.png"
touch "$HOME2/.config/uwsm-lock-screen/wallpapers/testtheme.disabled"
run_rotate "$HOME2"
assert_eq "disabled rotation falls back to shared background" \
  "$(readlink -f "$HOME2/.local/state/omarchy/current/background")" \
  "$(resolved_target "$HOME2")"
rm -rf "$HOME2"

# Case 3: a single real candidate in the theme backgrounds dir, rotation
# on by default (no marker needed) -> that candidate is picked.
HOME3="$(new_fixture_home)"
touch "$HOME3/.local/state/omarchy/current/theme/backgrounds/a.png"
run_rotate "$HOME3"
assert_eq "single real candidate is picked" \
  "$HOME3/.local/state/omarchy/current/theme/backgrounds/a.png" \
  "$(resolved_target "$HOME3")"
rm -rf "$HOME3"

# Case 4: the only .list entry is a symlink -> must be rejected at rotate
# time (not just at TUI add-time), falling back since nothing else in the
# pool resolves.
HOME4="$(new_fixture_home)"
REAL_FILE="$HOME4/real.png"
touch "$REAL_FILE"
LINK_FILE="$HOME4/link.png"
ln -s "$REAL_FILE" "$LINK_FILE"
echo "$LINK_FILE" > "$HOME4/.config/uwsm-lock-screen/wallpapers/testtheme.list"
run_rotate "$HOME4"
assert_eq "symlinked .list entry is rejected, falls back" \
  "$(readlink -f "$HOME4/.local/state/omarchy/current/background")" \
  "$(resolved_target "$HOME4")"
rm -rf "$HOME4"

# Case 5: one symlinked (bad) entry plus one real local entry in the pool
# -> the real entry is still picked (bad entries don't poison the whole
# pool, they're just skipped).
HOME5="$(new_fixture_home)"
REAL_FILE5="$HOME5/real.png"
touch "$REAL_FILE5"
LINK_FILE5="$HOME5/link.png"
ln -s "$REAL_FILE5" "$LINK_FILE5"
GOOD_FILE5="$HOME5/good.png"
touch "$GOOD_FILE5"
printf '%s\n%s\n' "$LINK_FILE5" "$GOOD_FILE5" > "$HOME5/.config/uwsm-lock-screen/wallpapers/testtheme.list"
run_rotate "$HOME5"
assert_eq "good entry picked even when pool also has a bad symlinked one" \
  "$GOOD_FILE5" \
  "$(resolved_target "$HOME5")"
rm -rf "$HOME5"

if [[ $FAILURES -eq 0 ]]; then
  echo "test-wallpaper-rotate.sh: all assertions passed"
else
  echo "test-wallpaper-rotate.sh: $FAILURES assertion(s) failed"
  exit 1
fi
