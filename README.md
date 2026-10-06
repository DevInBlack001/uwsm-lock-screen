# uwsm-lock-screen

A richer lock screen for uwsm-managed Wayland sessions on Arch Linux, showing
time, date, user, avatar, battery, media playback (with controls), and
network status.

Status: design in progress. Three sub-projects, built and documented
independently:

1. **Omarchy** - a cloned Quickshell/QML lock plugin (`omarchy-plugins/`)
2. **Hyprland + uwsm (non-Omarchy)** - a portable `hyprlock.conf` setup (`hyprlock/`)
3. **Sway / generic wlroots + uwsm** - a `gtklock` module configuration (`gtklock/`)

Each sub-project has its own design doc under `docs/specs/` before implementation.

## License

MIT, see [LICENSE](LICENSE).
