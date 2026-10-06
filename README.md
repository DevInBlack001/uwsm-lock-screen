# uwsm-lock-screen

A richer lock screen for uwsm-managed Wayland sessions on Arch Linux, showing
time, date, user, avatar, battery, media playback (with controls), network
status, and a rotating wallpaper drawn from your active theme.

Status: Omarchy sub-project functional and installable. Two more sub-projects
planned (see below).

## Install

```bash
git clone https://github.com/DevInBlack001/uwsm-lock-screen.git
cd uwsm-lock-screen
./install.sh
```

This clones Omarchy's built-in lock screen plugin (if you haven't already),
deploys the widgets in this repo onto it, installs the wallpaper rotation
scripts to `~/.local/bin`, and restarts the Omarchy shell.

Pull the latest changes and redeploy at any time with:

```bash
./update.sh
```

Remove everything this repo installed (with a confirmation prompt) with:

```bash
./uninstall.sh
```

Both `CLONE_DIR` (where the plugin clone lives) and `BIN_DIR` (where the
wallpaper scripts get symlinked) can be overridden via the
`UWSM_LOCK_CLONE_DIR` / `UWSM_LOCK_BIN_DIR` environment variables if your
setup doesn't use the default locations.

## Wallpaper rotation

Rotation is on by default once installed - every lock picks a random
wallpaper from your active theme's own background images, no setup needed.
To add your own local images or `https://` image URLs to the pool, or to
turn rotation off for a specific theme, run:

```bash
uwsm-lock-wallpaper
```

It shows inline thumbnails of your theme's backgrounds and any sources
you've added (via `chafa`, installed automatically), and also appears as
**Lock Screen Wallpapers** in your app launcher.

## Sub-projects

1. **Omarchy** - a cloned Quickshell/QML lock plugin (`clone-mirror/`) - **done**
2. **Hyprland + uwsm (non-Omarchy)** - a portable `hyprlock.conf` setup (`hyprlock/`) - planned
3. **Sway / generic wlroots + uwsm** - a `gtklock` module configuration (`gtklock/`) - planned

Each sub-project has its own design doc under `docs/specs/`.

## License

MIT, see [LICENSE](LICENSE).
