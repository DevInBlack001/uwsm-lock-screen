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
