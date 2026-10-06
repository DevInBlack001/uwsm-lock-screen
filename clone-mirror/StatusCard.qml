import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "DividerModel.js" as DividerModel

BorderSurface {
  id: root
  color: Color.lock.background
  radius: Style.cornerRadius
  borderSpec: Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, 3, "border-alpha")
  width: row.implicitWidth + 32
  height: row.implicitHeight + 24
  property bool active: true

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
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }

    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: root.dividers[0] }
    BatterySegment { id: battery }
    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: root.dividers[1] }
    NetworkSegment { id: network; active: root.active }
    Rectangle { width: 1; height: 20; color: Color.lock.border; visible: root.dividers[2] }
    MediaSegment { id: media }
  }
}
