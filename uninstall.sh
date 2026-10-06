#!/usr/bin/env bash
# Removes the cloned lock screen plugin, the wallpaper rotation scripts, and
# (on confirmation) your wallpaper sources config/cache. Omarchy's built-in
# lock screen takes back over automatically once the clone is removed.
set -euo pipefail

CLONE_DIR="${UWSM_LOCK_CLONE_DIR:-$HOME/.config/omarchy/plugins/$(id -un).lock}"
BIN_DIR="${UWSM_LOCK_BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="$HOME/.config/uwsm-lock-screen"
CACHE_DIR="$HOME/.cache/uwsm-lock-screen"
STATE_DIR="$HOME/.local/state/uwsm-lock-screen"

echo "This will remove:"
echo "  - The cloned lock screen plugin ($CLONE_DIR)"
echo "  - $BIN_DIR/uwsm-lock-wallpaper and uwsm-lock-wallpaper-rotate"
echo "  - Wallpaper rotation state ($STATE_DIR)"
echo
echo "Your wallpaper sources config and download cache will be kept unless"
echo "you confirm removing those too:"
echo "  - $CONFIG_DIR"
echo "  - $CACHE_DIR"
echo
read -r -p "Type 'uninstall' to proceed: " confirm
if [[ "$confirm" != "uninstall" ]]; then
  echo "Aborted, nothing was removed."
  exit 1
fi

if [[ -d "$CLONE_DIR" ]]; then
  plugin_id="$(id -un).lock"
  omarchy plugin remove "$plugin_id" --yes
  echo "Removed plugin $plugin_id"
else
  echo "No clone found at $CLONE_DIR, skipping plugin removal."
fi

rm -f "$BIN_DIR/uwsm-lock-wallpaper" "$BIN_DIR/uwsm-lock-wallpaper-rotate"
rm -rf "$STATE_DIR"
echo "Removed wallpaper scripts and rotation state."

read -r -p "Also delete your wallpaper sources config and cache ($CONFIG_DIR, $CACHE_DIR)? [y/N] " confirm_data
if [[ "$confirm_data" =~ ^[Yy]$ ]]; then
  rm -rf "$CONFIG_DIR" "$CACHE_DIR"
  echo "Removed $CONFIG_DIR and $CACHE_DIR."
else
  echo "Kept $CONFIG_DIR and $CACHE_DIR."
fi

omarchy restart shell
echo "Uninstall complete. The built-in Omarchy lock screen is active again."
