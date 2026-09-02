import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "BatteryModel.js" as BatteryModel

Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string settingsPath: Quickshell.env("HOME")
    + "/.config/omarchy/battery-alerts.json"
  readonly property string criticalIconPath: {
    var url = Qt.resolvedUrl("critical-battery.svg").toString()
    return url.startsWith("file://") ? url.slice(7) : url
  }
  property var settings: BatteryModel.normalizeSettings({})

  PersistentProperties {
    id: persisted
    reloadableId: "nerosong-battery-alerts"
    property bool warningSent: false
    property bool criticalSent: false
  }

  function loadSettings(raw) {
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {
      console.warn("battery-alerts: invalid settings file, using defaults:", e)
    }
    settings = BatteryModel.normalizeSettings(parsed)
    checkBattery()
  }

  function batteryPercentage() {
    return BatteryModel.batteryPercentage(UPower.displayDevice)
  }

  function isDischarging() {
    return BatteryModel.isDischarging(
      UPower.displayDevice, UPower.onBattery, UPowerDeviceState.Discharging)
  }

  function checkBattery() {
    var level = batteryPercentage()
    var state = BatteryModel.nextAlert(
      level, UPower.onBattery, isDischarging(), settings,
      persisted.warningSent, persisted.criticalSent)

    persisted.warningSent = state.warningSent
    persisted.criticalSent = state.criticalSent

    if (state.alert === "critical") sendCriticalWarning(level)
    else if (state.alert === "warning") sendWarning(level)
  }

  function sendWarning(level) {
    warningProcess.command = [
      "omarchy-notification-send",
      "-g", "󰂃",
      "-u", "normal",
      "-i", "battery-low",
      "-t", "10000",
      "Battery is getting low",
      "Battery is down to " + level + "%"
    ]
    warningProcess.running = true
  }

  function sendCriticalWarning(level) {
    sendCriticalNotification(level)
    // Preserve Omarchy's standard extension point without inheriting the
    // stock helper's theme-dependent battery icon.
    if (!hookProcess.running) {
      hookProcess.command = ["omarchy-hook", "battery-low", String(level)]
      hookProcess.running = true
    }
  }

  function sendCriticalNotification(level) {
    if (criticalProcess.running) return
    criticalProcess.command = [
      "omarchy-notification-send",
      "-g", "󱐋",
      "-u", "critical",
      "-i", criticalIconPath,
      "-t", "30000",
      "Time to recharge!",
      "Battery is down to " + level + "%"
    ]
    criticalProcess.running = true
  }

  function sendTestNotifications() {
    if (!warningProcess.running) sendWarning(settings.warningThreshold)
    // Match the real critical notification without running battery-low hooks
    // during a UI test.
    if (!criticalProcess.running) sendCriticalNotification(settings.criticalThreshold)
  }

  Process { id: warningProcess }
  Process { id: criticalProcess }
  Process { id: hookProcess }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
    onFileChanged: reload()
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.checkBattery()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.checkBattery() }
  }
}
