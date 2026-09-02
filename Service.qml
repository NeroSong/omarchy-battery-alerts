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
  readonly property string stateDir: Quickshell.env("HOME")
    + "/.local/state/omarchy"
  readonly property string statePath: stateDir + "/battery-alerts.json"
  readonly property string warningIconPath: {
    var url = Qt.resolvedUrl("warning-battery.svg").toString()
    return url.startsWith("file://") ? url.slice(7) : url
  }
  readonly property string criticalIconPath: {
    var url = Qt.resolvedUrl("critical-battery.svg").toString()
    return url.startsWith("file://") ? url.slice(7) : url
  }
  property var settings: BatteryModel.normalizeSettings({})
  property bool settingsLoaded: false
  property bool stateDirReady: false
  property bool stateLoaded: false
  property bool warningSent: false
  property bool criticalSent: false

  function loadSettings(raw) {
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {
      console.warn("battery-alerts: invalid settings file, using defaults:", e)
    }
    settings = BatteryModel.normalizeSettings(parsed)
    settingsLoaded = true
    maybeCheckBattery()
  }

  function loadAlertState(raw) {
    // FileView may finish its implicit preload after the explicit reload that
    // follows mkdir. Hydrate exactly once so two startup callbacks cannot send
    // the same alert twice.
    if (stateLoaded) return
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {
      console.warn("battery-alerts: invalid state file, starting a new state:", e)
    }
    warningSent = parsed.warningSent === true
    criticalSent = parsed.criticalSent === true
    stateLoaded = true
    maybeCheckBattery()
  }

  function saveAlertState() {
    if (!stateLoaded) return
    stateFile.setText(JSON.stringify({
      version: 1,
      warningSent: warningSent,
      criticalSent: criticalSent
    }, null, 2) + "\n")
  }

  function updateAlertState(nextWarningSent, nextCriticalSent) {
    var changed = warningSent !== nextWarningSent
      || criticalSent !== nextCriticalSent
    warningSent = nextWarningSent
    criticalSent = nextCriticalSent
    if (changed) saveAlertState()
  }

  function maybeCheckBattery() {
    if (settingsLoaded && stateLoaded) checkBattery()
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
      warningSent, criticalSent)

    updateAlertState(state.warningSent, state.criticalSent)

    if (state.alert === "critical") sendCriticalWarning(level)
    else if (state.alert === "warning") sendWarning(level)
  }

  function sendWarning(level) {
    warningProcess.command = [
      "omarchy-notification-send",
      "-g", "󰂃",
      "-u", "normal",
      "-i", warningIconPath,
      "-t", "10000",
      "Battery is getting low",
      "Battery is down to " + level + "%"
    ]
    warningProcess.running = true
  }

  function sendCriticalWarning(level) {
    sendCriticalNotification(level)
  }

  function sendCriticalNotification(level) {
    if (criticalProcess.running) return
    criticalProcess.command = [
      "omarchy-notification-send",
      "-g", "󱐋",
      "-u", "critical",
      "-i", criticalIconPath,
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

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
    onFileChanged: reload()
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: if (root.stateDirReady) root.loadAlertState(text())
    onLoadFailed: if (root.stateDirReady) root.loadAlertState("")
  }

  Process {
    id: ensureStateDirProcess
    command: ["mkdir", "-p", root.stateDir]
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.warn("battery-alerts: could not create state directory")
        return
      }
      root.stateDirReady = true
      stateFile.reload()
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.maybeCheckBattery()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.maybeCheckBattery() }
  }

  Component.onCompleted: ensureStateDirProcess.running = true
}
