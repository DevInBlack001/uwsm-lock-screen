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

wp_disabled_marker() {
  printf '%s/.config/uwsm-lock-screen/wallpapers/%s.disabled' "$HOME" "$1"
}

# Rotation is on by default for every theme; the marker is an opt-OUT, not
# an opt-in, so a theme nobody has configured still rotates.
wp_rotation_enabled() {
  [[ ! -f "$(wp_disabled_marker "$1")" ]]
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

wp_appearance_file() {
  printf '%s/.config/uwsm-lock-screen/appearance.conf' "$HOME"
}

# Reads the current value of "layout" or "style" from appearance.conf, or
# prints nothing if the file or key doesn't exist yet.
wp_read_appearance() {
  local key="$1" f
  f="$(wp_appearance_file)"
  [[ -f "$f" ]] || return 0
  sed -n -E "s/^${key}=(.*)$/\1/p" "$f" | tail -n1
}

# Rewrites appearance.conf with the given layout/style, preserving whichever
# of the two the caller passes as empty by keeping its current value.
wp_write_appearance() {
  local layout="$1" style="$2" f
  f="$(wp_appearance_file)"
  mkdir -p "$(dirname "$f")"
  [[ -n "$layout" ]] || layout="$(wp_read_appearance layout)"
  [[ -n "$style" ]] || style="$(wp_read_appearance style)"
  {
    [[ -n "$layout" ]] && printf 'layout=%s\n' "$layout"
    [[ -n "$style" ]] && printf 'style=%s\n' "$style"
  } > "$f"
}

# Extracts the preset name list from a LayoutPresets.js/StylePresets.js
# "var ORDER = [ ... ];" block without needing a node runtime dependency -
# the TUI only needs the names, not the preset data itself.
wp_preset_names_from_js() {
  local js_file="$1"
  [[ -f "$js_file" ]] || return 1
  sed -n '/var ORDER = \[/,/\];/p' "$js_file" \
    | grep -oE '"[A-Za-z0-9_-]+"' \
    | tr -d '"'
}

# Pulls one field's raw value (e.g. "top-left", 0.55, true) out of a named
# preset's object literal in LayoutPresets.js/StylePresets.js, for building
# a plain-text preview without a node runtime dependency.
wp_preset_field() {
  local js_file="$1" name="$2" field="$3" line value
  [[ -f "$js_file" ]] || return 1
  line="$(grep -E "^[[:space:]]*\"${name}\":" "$js_file")"
  [[ -n "$line" ]] || return 1
  value="$(printf '%s' "$line" | grep -oE "\\b${field}: *[^,}]+" | sed -E "s/^${field}: *//; s/[[:space:]]+$//")"
  value="${value%\"}"
  value="${value#\"}"
  printf '%s' "$value"
}

# One-line human-readable summary of a layout preset, shown next to its
# name in the TUI's "Select layout" list as a text preview.
wp_layout_preview() {
  local js_file="$1" name="$2"
  printf 'clock:%-22s status:%-9s password:%-9s scale:%sx' \
    "$(wp_preset_field "$js_file" "$name" clockAnchor)" \
    "$(wp_preset_field "$js_file" "$name" statusArrangement)" \
    "$(wp_preset_field "$js_file" "$name" passwordStyle)" \
    "$(wp_preset_field "$js_file" "$name" clockScale)"
}

# One-line human-readable summary of a style preset, shown next to its name
# in the TUI's "Select style" list as a text preview.
wp_style_preview() {
  local js_file="$1" name="$2" shadow underline
  shadow="$(wp_preset_field "$js_file" "$name" shadow)"
  underline="$(wp_preset_field "$js_file" "$name" underline)"
  [[ "$underline" == "true" ]] && shadow="n/a (underline)"
  printf 'alpha:%-5s border:%-3spx radius:%-4s shadow:%s' \
    "$(wp_preset_field "$js_file" "$name" bgAlpha)" \
    "$(wp_preset_field "$js_file" "$name" borderWidth)" \
    "$(wp_preset_field "$js_file" "$name" radius)" \
    "$shadow"
}
