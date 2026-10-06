#!/usr/bin/env bash
# Installs the Omarchy lock screen widgets plugin and the wallpaper rotation
# TUI/scripts. Safe to re-run; it only clones the built-in plugin if no
# clone exists yet, and otherwise just (re)deploys this checkout's files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE_DIR="${UWSM_LOCK_CLONE_DIR:-$HOME/.config/omarchy/plugins/$(id -un).lock}"

# gum drives the wallpaper TUI; chafa renders its inline wallpaper
# thumbnails. Both are optional at runtime (the TUI degrades to a plain
# list without chafa, and errors clearly if gum is missing), but installing
# them up front means a fresh clone works out of the box. Only prompts for
# a password if something is actually missing.
missing_pkgs=()
command -v gum >/dev/null 2>&1 || missing_pkgs+=("gum")
command -v chafa >/dev/null 2>&1 || missing_pkgs+=("chafa")
if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
  echo "Installing missing dependencies: ${missing_pkgs[*]}"
  sudo pacman -S --needed --noconfirm "${missing_pkgs[@]}"
else
  echo "Dependencies already present: gum, chafa"
fi

if [[ ! -d "$CLONE_DIR" ]]; then
  echo "No cloned lock screen plugin found - cloning omarchy.lock..."
  omarchy plugin clone omarchy.lock
else
  echo "Found existing clone at $CLONE_DIR"
fi

echo "Deploying plugin files from $SCRIPT_DIR/clone-mirror/ to $CLONE_DIR/..."
# Retired in the layout-3 rework - remove if present from an older install,
# since a plain copy never deletes files that no longer exist in the repo.
rm -f "$CLONE_DIR/StatusCard.qml" "$CLONE_DIR/DividerModel.js" "$CLONE_DIR/DividerModel.test.js"

# manifest.json is deliberately not copied - it's generated per-machine by
# `omarchy plugin clone` (carries this user's own plugin id). *.test.js
# files are node-run tests, not plugin code, so they stay out of the clone.
cp "$SCRIPT_DIR"/clone-mirror/*.qml "$CLONE_DIR/"
for f in "$SCRIPT_DIR"/clone-mirror/*.js; do
  [[ "$f" == *.test.js ]] && continue
  cp "$f" "$CLONE_DIR/"
done

echo "Installing wallpaper rotation scripts..."
"$SCRIPT_DIR/wallpaper/install.sh"

echo "Restarting the Omarchy shell to load the fresh install..."
omarchy restart shell

echo "Install complete."
