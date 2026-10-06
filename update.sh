#!/usr/bin/env bash
# Pulls the latest changes and re-deploys the plugin + wallpaper scripts.
# Requires install.sh to have been run at least once already (a clone must
# already exist).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE_DIR="$HOME/.config/omarchy/plugins/$(id -un).lock"

if [[ ! -d "$CLONE_DIR" ]]; then
  echo "No existing install found at $CLONE_DIR - run ./install.sh first." >&2
  exit 1
fi

echo "Pulling latest changes..."
git -C "$SCRIPT_DIR" pull

exec "$SCRIPT_DIR/install.sh"
