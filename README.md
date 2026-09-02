# Battery Alerts for Omarchy

Configurable two-stage battery notifications for the Omarchy shell.

- A normal warning at 50% by default; it disappears automatically.
- A critical warning at 30% by default; it stays visible until dismissed.
- Each warning appears once per discharge session and resets after AC power is
  connected.
- Runs alongside Omarchy's built-in battery service without replacing it.
- A small settings panel opens from the Omarchy menu.
- No extra icon is added to the top bar.

## Install

```bash
omarchy plugin add https://github.com/NeroSong/omarchy-battery-alerts --enable
~/.config/omarchy/plugins/nerosong.battery-alerts/bin/install-menu-entry
```

Open the Omarchy menu and search for **Battery Alerts**. The panel lets you
change both thresholds, restore the defaults, and send a test notification.
Changes take effect immediately and are saved in:

```text
~/.config/omarchy/battery-alerts.json
```

Both sliders use the same fixed 5–90% range. The critical threshold cannot be
higher than or equal to the normal warning threshold; dragging one across the
other moves the other threshold with it while preserving at least a 1% gap.
At the range edges the pair stops at 5/6% or 89/90%. The service also validates
a hand-edited settings file before use.

This is an independent third-party service. It does not replace, clone, or
modify Omarchy's built-in `omarchy.battery` service, so future Omarchy updates
to battery handling and power-profile switching continue to apply normally.
Omarchy's stock 10% warning remains enabled and may appear after this plugin's
configurable warnings.

## Remove the menu entry

Before removing the plugin, remove its menu entry:

```bash
~/.config/omarchy/plugins/nerosong.battery-alerts/bin/uninstall-menu-entry
omarchy plugin remove nerosong.battery-alerts
```

The settings file is intentionally kept so reinstalling preserves your
thresholds. Delete it manually if you also want to reset stored preferences.

## Development

```bash
node tests/test_battery_model.js
python tests/test_menu_scripts.py
omarchy plugin validate .
```

The service uses Quickshell's native UPower integration and checks every 60
seconds, plus an immediate check whenever the power source changes. It calls
Omarchy's existing notification helpers, including the
standard `battery-low` hook for the critical alert.
