# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.3.0] - 2026-10-06

### Added
- Wallpaper rotation for the Omarchy lock screen, on by default, drawing
  from the active theme's own backgrounds plus any user-added local paths
  or `https://` image URLs.
- `uwsm-lock-wallpaper`, a `gum`-based TUI for managing wallpaper sources
  and toggling rotation per theme, with an app launcher entry
  ("Lock Screen Wallpapers").
- Top-level `install.sh`, `update.sh`, and `uninstall.sh`.

## [0.2.0] - 2026-10-06

### Changed
- Replaced the single bordered status card with corner-anchored widgets
  (no card background): clock top-left, battery + network bottom-left,
  avatar + username + media bottom-right.
- Password field restyled to an underline-only field (no box/fill).
- All text now uses a drop-shadow style for legibility directly over the
  wallpaper.

## [0.1.0] - 2026-10-06

### Added
- Cloned Omarchy Quickshell lock screen plugin with clock + date, user
  avatar (with fallback glyph), battery status, network status, and MPRIS
  media playback with transport controls.
