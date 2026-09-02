# Battery Alerts for Omarchy

Configurable two-stage battery notifications for the Omarchy shell.

- A normal warning at 50% by default; it disappears automatically.
- A critical warning at 30% by default; it stays visible until dismissed.
- Each warning appears once per discharge session and resets after AC power is
  connected.
- A small settings panel opens from the Omarchy menu.
- No extra icon is added to the top bar.

## Install

```bash
omarchy plugin add https://github.com/NeroSong/omarchy-battery-alerts --enable
~/.config/omarchy/plugins/io.github.nerosong.battery-alerts/bin/install-menu-entry
```

Open the Omarchy menu and search for **Battery Alerts**. The panel lets you
change both thresholds, restore the defaults, and send a test notification.
Changes take effect immediately and are saved in:

```text
~/.config/omarchy/battery-alerts.json
```

The critical threshold must remain below the normal warning threshold. The
panel enforces that rule, and the service also validates a hand-edited settings
file before using it.

This plugin replaces Omarchy's built-in `omarchy.battery` service while it is
enabled, so the stock 10% notification will not fire as a duplicate. Disabling
or removing the plugin restores the built-in service.

## Remove the menu entry

Before removing the plugin, remove its menu entry:

```bash
~/.config/omarchy/plugins/io.github.nerosong.battery-alerts/bin/uninstall-menu-entry
omarchy plugin remove io.github.nerosong.battery-alerts
```

The settings file is intentionally kept so reinstalling preserves your
thresholds. Delete it manually if you also want to reset stored preferences.

## Development

```bash
node tests/test_battery_model.js
python tests/test_menu_scripts.py
omarchy plugin validate .
```

The service uses Quickshell's native UPower integration and checks every 30
seconds. It calls Omarchy's existing notification helpers, including the
standard `battery-low` hook for the critical alert.
