import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "DividerModel.js" as DividerModel

// Single status card (avatar+username, battery, network, media) styled from
// a StylePresets.js preset. Used by layouts whose statusArrangement is
// "card-below".
BorderSurface {
  id: card
  required property var root
  required property var style

  color: Qt.rgba(0, 0, 0, style.bgAlpha)
  borderSpec: Border.withWidth(Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, 2, "border-alpha"), String(style.borderWidth))
  radius: style.radius
  width: row.implicitWidth + 32
  height: row.implicitHeight + 24

  readonly property string fontFamily: style.monospace ? "monospace" : Style.font.family
  readonly property color textColor: style.light ? "#1a1a1a" : Color.lock.text

  readonly property var dividers: DividerModel.visibleDividers({
    battery: battery.visible,
    network: network.visible,
    media: media.visible
  })

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 14

    Row {
      spacing: 8
      AvatarWidget { width: 32; height: 32 }
      Text {
        textFormat: Text.PlainText
        text: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        color: card.textColor
        font.family: card.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: card.dividers[0] }
    BatterySegment { id: battery }
    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: card.dividers[1] }
    NetworkSegment { id: network; active: root.loadBackground }
    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: card.dividers[2] }
    MediaSegment { id: media }
  }
}
