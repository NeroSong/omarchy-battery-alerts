import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "BatteryModel.js" as BatteryModel

Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  readonly property string safeJsonPath: {
    var url = Qt.resolvedUrl("bin/safe-json").toString()
    return url.startsWith("file://") ? url.slice(7) : url
  }
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
  property bool stateLoaded: false
  property bool warningSent: false
  property bool criticalSent: false
  property double readFailureStartedAt: 0
  property double readFailureLastAt: 0
  property bool readFailureNotified: false

  function safeJsonCommand(operation, kind, value) {
    var command = [
      "/usr/bin/timeout", "--kill-after=1s", "5s",
      safeJsonPath, operation, kind
    ]
    if (value !== undefined) command.push(value)
    return command
  }

  function loadSettings(raw) {
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {
      console.warn("battery-alerts: invalid settings file, using defaults:", e)
    }
    settings = BatteryModel.normalizeSettings(parsed)
    settingsLoaded = true
    maybeCheckBattery()
  }

  function reloadSettings() {
    if (!settingsReadProcess.running) {
      settingsReadProcess.command = safeJsonCommand("read", "settings")
      settingsReadProcess.running = true
    }
  }

  function loadRuntimeState(raw) {
    // Hydrate exactly once so a later read cannot send the same alert twice.
    if (stateLoaded) return
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {
      console.warn("battery-alerts: invalid state file, starting a new state:", e)
    }
    warningSent = parsed.warningSent === true
    criticalSent = parsed.criticalSent === true
    var failure = BatteryModel.normalizeReadFailureState(parsed)
    readFailureStartedAt = failure.startedAt
    readFailureLastAt = failure.lastAt
    readFailureNotified = failure.notified
    stateLoaded = true
    maybeCheckBattery()
  }

  function saveRuntimeState() {
    if (!stateLoaded) return
    pendingState = JSON.stringify({
      version: 2,
      warningSent: warningSent,
      criticalSent: criticalSent,
      readFailureStartedAt: readFailureStartedAt,
      readFailureLastAt: readFailureLastAt,
      readFailureNotified: readFailureNotified
    })
    if (!stateWriteProcess.running) writePendingState()
  }

  property string pendingState: ""
  function writePendingState() {
    if (!pendingState) return
    var value = pendingState
    pendingState = ""
    stateWriteProcess.command = safeJsonCommand("write", "state", value)
    stateWriteProcess.running = true
  }

  function updateAlertState(nextWarningSent, nextCriticalSent) {
    var changed = warningSent !== nextWarningSent
      || criticalSent !== nextCriticalSent
    warningSent = nextWarningSent
    criticalSent = nextCriticalSent
    if (changed) saveRuntimeState()
  }

  function updateReadFailureState(next) {
    var changed = readFailureStartedAt !== next.startedAt
      || readFailureLastAt !== next.lastAt
      || readFailureNotified !== next.notified
    readFailureStartedAt = next.startedAt
    readFailureLastAt = next.lastAt
    readFailureNotified = next.notified
    if (changed) saveRuntimeState()
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
    var failure = BatteryModel.nextReadFailureState(level, Date.now(), {
      readFailureStartedAt: readFailureStartedAt,
      readFailureLastAt: readFailureLastAt,
      readFailureNotified: readFailureNotified
    })
    updateReadFailureState(failure)
    if (failure.notify) sendReadFailureWarning()

    var state = BatteryModel.nextAlert(
      level, UPower.onBattery, isDischarging(), settings,
      warningSent, criticalSent)

    updateAlertState(state.warningSent, state.criticalSent)

    if (state.alert === "critical") sendCriticalWarning(level)
    else if (state.alert === "warning") sendWarning(level)
  }

  function sendWarning(level) {
    warningProcess.command = [
      "/usr/bin/timeout", "--kill-after=1s", "5s", "/usr/bin/omarchy-notification-send",
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
      "/usr/bin/timeout", "--kill-after=1s", "5s", "/usr/bin/omarchy-notification-send",
      "-g", "󱐋",
      "-u", "critical",
      "-i", criticalIconPath,
      "Time to recharge!",
      "Battery is down to " + level + "%"
    ]
    criticalProcess.running = true
  }

  function sendReadFailureWarning() {
    if (readFailureProcess.running) return
    readFailureProcess.command = [
      "/usr/bin/timeout", "--kill-after=1s", "5s", "/usr/bin/omarchy-notification-send",
      "-g", "󰂃",
      "-u", "normal",
      "-i", warningIconPath,
      "-t", "10000",
      "Battery status unavailable",
      "Battery level could not be read for 10 minutes"
    ]
    readFailureProcess.running = true
  }

  function sendTestNotifications() {
    if (!warningProcess.running) sendWarning(settings.warningThreshold)
    // Match the real critical notification without running battery-low hooks
    // during a UI test.
    if (!criticalProcess.running) sendCriticalNotification(settings.criticalThreshold)
  }

  Process { id: warningProcess }
  Process { id: criticalProcess }
  Process { id: readFailureProcess }
  Process {
    id: settingsReadProcess
    stdout: StdioCollector { id: settingsReadOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.loadSettings(exitCode === 0 ? settingsReadOutput.text : "")
    }
  }
  Process {
    id: stateReadProcess
    stdout: StdioCollector { id: stateReadOutput; waitForEnd: true }
    onExited: function(exitCode) {
      root.loadRuntimeState(exitCode === 0 ? stateReadOutput.text : "")
    }
  }
  Process {
    id: stateWriteProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("battery-alerts: state write failed:", exitCode)
      root.writePendingState()
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { root.reloadSettings(); root.maybeCheckBattery() }
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.maybeCheckBattery() }
  }

  Component.onCompleted: {
    reloadSettings()
    stateReadProcess.command = safeJsonCommand("read", "state")
    stateReadProcess.running = true
  }
}
