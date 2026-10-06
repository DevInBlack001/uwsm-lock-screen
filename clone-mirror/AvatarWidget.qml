import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui
import "AvatarModel.js" as AvatarModel

Item {
  id: root
  readonly property string facePath: Quickshell.env("HOME") + "/.face"
  readonly property string avatarSource: AvatarModel.avatarFileUrl(facePath)
  width: 40
  height: 40

  // No existence pre-check: a path that exists but is unreadable, corrupt
  // or empty still passes `test -f`, which left a blank circle with
  // neither the photo nor the fallback glyph. Always attempting the load
  // and keying visibility off Image.status covers every failure mode in
  // one place, the way Qt itself reports them.
  Image {
    id: faceImage
    anchors.fill: parent
    visible: status === Image.Ready
    source: root.avatarSource
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: maskShape
    }
  }

  Item {
    id: maskShape
    anchors.fill: parent
    layer.enabled: true
    visible: false
    Rectangle { anchors.fill: parent; radius: width / 2 }
  }

  Text {
    anchors.fill: parent
    visible: !faceImage.visible
    text: ""
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: root.width * 0.8
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
