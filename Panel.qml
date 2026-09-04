import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "BatteryModel.js" as BatteryModel

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property int warningThreshold: 30
  property int criticalThreshold: 20
  property string pendingSettings: ""
  property bool closeAfterSave: false

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "nerosong.battery-alerts"
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
  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family

  function safeJsonCommand(operation, value) {
    var command = [
      "/usr/bin/timeout", "--kill-after=1s", "5s",
      safeJsonPath, operation, "settings"
    ]
    if (value !== undefined) command.push(value)
    return command
  }

  function open(payloadJson) {
    opened = true
    reloadSettings()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { opened = false }

  function finishDismiss() {
    closeAfterSave = false
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function dismiss() {
    if (saveTimer.running) {
      saveTimer.stop()
      saveSettings()
    }
    if (settingsWriteProcess.running || pendingSettings) {
      closeAfterSave = true
      return
    }
    finishDismiss()
  }

  function loadSettings(raw) {
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {}
    var normalized = BatteryModel.normalizeSettings(parsed)
    warningThreshold = normalized.warningThreshold
    criticalThreshold = normalized.criticalThreshold
  }

  function reloadSettings() {
    if (!settingsReadProcess.running) {
      settingsReadProcess.command = safeJsonCommand("read")
      settingsReadProcess.running = true
    }
  }

  function saveSettings() {
    var normalized = BatteryModel.normalizeSettings({
      warningThreshold: warningThreshold,
      criticalThreshold: criticalThreshold
    })
    warningThreshold = normalized.warningThreshold
    criticalThreshold = normalized.criticalThreshold
    pendingSettings = JSON.stringify(normalized)
    if (!settingsWriteProcess.running) writePendingSettings()
  }

  function writePendingSettings() {
    if (!pendingSettings) return
    var value = pendingSettings
    pendingSettings = ""
    settingsWriteProcess.command = safeJsonCommand("write", value)
    settingsWriteProcess.running = true
  }

  function setWarning(value) {
    var adjusted = BatteryModel.adjustWarning({
      warningThreshold: warningThreshold,
      criticalThreshold: criticalThreshold
    }, value)
    warningThreshold = adjusted.warningThreshold
    criticalThreshold = adjusted.criticalThreshold
    saveTimer.restart()
  }

  function setCritical(value) {
    var adjusted = BatteryModel.adjustCritical({
      warningThreshold: warningThreshold,
      criticalThreshold: criticalThreshold
    }, value)
    warningThreshold = adjusted.warningThreshold
    criticalThreshold = adjusted.criticalThreshold
    saveTimer.restart()
  }

  function resetDefaults() {
    warningThreshold = 30
    criticalThreshold = 20
    saveSettings()
  }

  function testNotification() {
    if (service && typeof service.sendTestNotifications === "function") {
      service.sendTestNotifications()
      return
    }
    Quickshell.execDetached([
      "/usr/bin/timeout", "--kill-after=1s", "5s", "/usr/bin/omarchy-notification-send",
      "-g", "󰂃", "-u", "normal", "-i", warningIconPath, "-t", "10000",
      "Battery is getting low", "Battery is down to " + warningThreshold + "%"
    ])
    Quickshell.execDetached([
      "/usr/bin/timeout", "--kill-after=1s", "5s", "/usr/bin/omarchy-notification-send",
      "-g", "󱐋", "-u", "critical", "-i", criticalIconPath,
      "Time to recharge!", "Battery is down to " + criticalThreshold + "%"
    ])
  }

  Process {
    id: settingsReadProcess
    stdout: StdioCollector { id: settingsReadOutput; waitForEnd: true }
    onExited: function(exitCode) { root.loadSettings(exitCode === 0 ? settingsReadOutput.text : "") }
  }
  Process {
    id: settingsWriteProcess
    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("battery-alerts: settings write failed:", exitCode)
      if (root.pendingSettings) root.writePendingSettings()
      else if (root.closeAfterSave) root.finishDismiss()
    }
  }

  Timer {
    id: saveTimer
    interval: 250
    onTriggered: root.saveSettings()
  }

  PanelWindow {
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-battery-alerts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.56)
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onEscapePressed: root.dismiss()

      Rectangle {
        id: card
        width: Math.min(520, parent.width - Style.space(32))
        implicitHeight: content.implicitHeight + Style.space(40)
        height: implicitHeight
        anchors.centerIn: parent
        radius: Style.cornerRadius
        color: root.background
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

        MouseArea { anchors.fill: parent }

        ColumnLayout {
          id: content
          anchors.fill: parent
          anchors.leftMargin: Style.space(20)
          anchors.rightMargin: Style.space(20)
          anchors.topMargin: Style.space(20)
          anchors.bottomMargin: Style.space(12)
          spacing: Style.space(18)

          Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(headerText.implicitHeight, closeButton.implicitHeight)

            ColumnLayout {
              id: headerText
              anchors.left: parent.left
              anchors.top: parent.top
              spacing: Style.space(3)
              Text {
                text: "Battery Alerts"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                text: "Two reminders before your battery runs out"
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.62)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              id: closeButton
              anchors.right: parent.right
              anchors.top: parent.top
              iconText: "󰅖"
              tooltipText: "Close"
              bordered: true
              onClicked: root.dismiss()
            }
          }

          ThresholdRow {
            Layout.fillWidth: true
            title: "Low battery warning"
            description: "Normal notification; disappears automatically"
            glyph: "󰁾"
            value: root.warningThreshold
            minimum: 5
            maximum: 90
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onValueModified: function(value) { root.setWarning(value) }
          }

          ThresholdRow {
            Layout.fillWidth: true
            title: "Critical battery warning"
            description: "Stays visible until you dismiss it"
            glyph: "󱐋"
            value: root.criticalThreshold
            minimum: 5
            maximum: 90
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onValueModified: function(value) { root.setCritical(value) }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Button {
              text: "Test notification"
              bordered: true
              onClicked: root.testNotification()
            }
            Button {
              text: "Restore defaults"
              bordered: true
              onClicked: root.resetDefaults()
            }
            Item { Layout.fillWidth: true }
          }
        }
      }
    }
  }
}
