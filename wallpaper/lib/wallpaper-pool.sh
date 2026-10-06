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
