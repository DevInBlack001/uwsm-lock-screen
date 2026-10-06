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

# wp_sources_file / wp_disabled_marker paths
assert_eq "sources_file" "$HOME/.config/uwsm-lock-screen/wallpapers/ristretto.list" "$(wp_sources_file ristretto)"
assert_eq "disabled_marker" "$HOME/.config/uwsm-lock-screen/wallpapers/ristretto.disabled" "$(wp_disabled_marker ristretto)"

# wp_rotation_enabled: absent marker -> enabled by default (exit 0)
set +e
wp_rotation_enabled ristretto
assert_status "rotation enabled by default" 0 $?
set -e

# wp_rotation_enabled: present marker -> disabled (exit 1)
mkdir -p "$HOME/.config/uwsm-lock-screen/wallpapers"
touch "$(wp_disabled_marker ristretto)"
set +e
wp_rotation_enabled ristretto
assert_status "rotation disabled after marker created" 1 $?
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
