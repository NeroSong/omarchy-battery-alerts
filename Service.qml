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
  property var settings: BatteryModel.normalizeSettings({})

  PersistentProperties {
    id: persisted
    reloadableId: "io-github-nerosong-battery-alerts"
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
    // The stock helper sends a critical notification and preserves Omarchy's
    // battery-low hook. Critical notifications remain until dismissed.
    criticalProcess.command = ["omarchy-battery-low", String(level)]
    criticalProcess.running = true
  }

  Process { id: warningProcess }
  Process { id: criticalProcess }

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
