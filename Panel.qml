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
  property bool opened: false
  property int warningThreshold: 50
  property int criticalThreshold: 30
  property string statusText: ""

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "nerosong.battery-alerts"
  readonly property string settingsPath: Quickshell.env("HOME")
    + "/.config/omarchy/battery-alerts.json"
  readonly property color foreground: Color.foreground
  readonly property color background: Color.background
  readonly property color accent: Color.accent
  readonly property string fontFamily: Style.font.family

  function open(payloadJson) {
    opened = true
    settingsFile.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { opened = false }

  function dismiss() {
    if (saveTimer.running) saveSettings()
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function loadSettings(raw) {
    var parsed = {}
    try { parsed = JSON.parse(String(raw || "{}")) } catch (e) {}
    var normalized = BatteryModel.normalizeSettings(parsed)
    warningThreshold = normalized.warningThreshold
    criticalThreshold = normalized.criticalThreshold
  }

  function saveSettings() {
    var normalized = BatteryModel.normalizeSettings({
      warningThreshold: warningThreshold,
      criticalThreshold: criticalThreshold
    })
    warningThreshold = normalized.warningThreshold
    criticalThreshold = normalized.criticalThreshold
    settingsFile.setText(JSON.stringify(normalized, null, 2) + "\n")
    statusText = "Saved — new thresholds are active"
    statusTimer.restart()
  }

  function setWarning(value) {
    warningThreshold = Math.max(criticalThreshold + 1, Math.round(value))
    saveTimer.restart()
  }

  function setCritical(value) {
    criticalThreshold = Math.min(warningThreshold - 1, Math.round(value))
    saveTimer.restart()
  }

  function resetDefaults() {
    warningThreshold = 50
    criticalThreshold = 30
    saveSettings()
  }

  function testNotification() {
    Quickshell.execDetached([
      "omarchy-notification-send", "-u", "normal", "-t", "10000",
      "Battery Alerts test",
      "Warning at " + warningThreshold + "% · critical at " + criticalThreshold + "%"
    ])
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    onLoadFailed: root.loadSettings("")
    onFileChanged: reload()
  }

  Timer {
    id: saveTimer
    interval: 250
    onTriggered: root.saveSettings()
  }

  Timer {
    id: statusTimer
    interval: 2500
    onTriggered: root.statusText = ""
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
        width: Math.min(460, parent.width - Style.space(32))
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
          anchors.margins: Style.space(20)
          spacing: Style.space(18)

          RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(3)
              Text {
                text: "Battery Alerts"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                text: "Two reminders, no bar icon"
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.62)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              text: "Close"
              onClicked: root.dismiss()
            }
          }

          ThresholdRow {
            Layout.fillWidth: true
            title: "Low battery warning"
            description: "Normal notification; disappears automatically"
            glyph: "󰁾"
            value: root.warningThreshold
            minimum: Math.max(2, root.criticalThreshold + 1)
            maximum: 95
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
            minimum: 1
            maximum: Math.min(94, root.warningThreshold - 1)
            foreground: root.foreground
            accent: root.accent
            fontFamily: root.fontFamily
            onValueModified: function(value) { root.setCritical(value) }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Button {
              text: "Test notification"
              onClicked: root.testNotification()
            }
            Button {
              text: "Restore defaults"
              onClicked: root.resetDefaults()
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.statusText
              visible: text !== ""
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
