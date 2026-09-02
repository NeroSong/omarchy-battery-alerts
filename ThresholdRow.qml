import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string title: ""
  property string description: ""
  property string glyph: ""
  property int value: 0
  property int minimum: 1
  property int maximum: 99
  property color foreground: "white"
  property color accent: "white"
  property string fontFamily: ""

  signal valueModified(int value)

  implicitHeight: 96
  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.045)
  border.width: 1
  border.color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.1)

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(14)
    spacing: Style.space(8)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      Text {
        text: root.glyph
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Math.round(Style.font.heading * 1.35)
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text {
          text: root.title
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
        Text {
          text: root.description
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.58)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(12)

      Text {
        Layout.preferredWidth: Style.space(42)
        text: root.value + "%"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
        font.bold: true
        horizontalAlignment: Text.AlignLeft
      }

      PanelSlider {
        Layout.fillWidth: true
        bar: null
        minimum: root.minimum
        maximum: root.maximum
        step: 1
        integer: true
        value: root.value
        trackColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
        fillColor: root.accent
        knobColor: root.foreground
        onMoved: function(value) { root.valueModified(value) }
      }
    }
  }
}
