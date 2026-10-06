#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="${UWSM_LOCK_BIN_DIR:-$HOME/.local/bin}"
CLONE_DIR="${UWSM_LOCK_CLONE_DIR:-$HOME/.config/omarchy/plugins/$(id -un).lock}"

mkdir -p "$BIN_DIR"
ln -sf "$REPO_ROOT/wallpaper/bin/uwsm-lock-wallpaper" "$BIN_DIR/uwsm-lock-wallpaper"
ln -sf "$REPO_ROOT/wallpaper/bin/uwsm-lock-wallpaper-rotate" "$BIN_DIR/uwsm-lock-wallpaper-rotate"
echo "Installed uwsm-lock-wallpaper and uwsm-lock-wallpaper-rotate to $BIN_DIR"

# App launcher entry for the TUI. Exec references the bare command name
# (not an absolute path) since $BIN_DIR is ~/.local/bin, already on PATH
# for a standard XDG user install - no path templating needed here.
APPS_DIR="${UWSM_LOCK_APPS_DIR:-$HOME/.local/share/applications}"
mkdir -p "$APPS_DIR"
ln -sf "$REPO_ROOT/wallpaper/uwsm-lock-wallpaper.desktop" "$APPS_DIR/uwsm-lock-wallpaper.desktop"
echo "Installed app launcher entry to $APPS_DIR/uwsm-lock-wallpaper.desktop"

# Service.qml's own source already points at the stable ~/.local/bin/ path
# (no dev-checkout path to rewrite here); this step just confirms the
# plugin clone that path depends on actually exists.
if [[ -f "$CLONE_DIR/Service.qml" ]]; then
  echo "Found plugin clone at $CLONE_DIR - rotation hook will use $BIN_DIR/uwsm-lock-wallpaper-rotate"
else
  echo "Note: $CLONE_DIR/Service.qml not found - run sub-project 1's clone step first (or ./install.sh at the repo root), then re-run this install script."
fi
