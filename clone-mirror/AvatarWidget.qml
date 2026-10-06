import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "AvatarModel.js" as AvatarModel

Item {
  id: root
  readonly property string facePath: Quickshell.env("HOME") + "/.face"
  property bool faceExists: false
  readonly property string avatarSource: AvatarModel.resolveAvatarSource(facePath, faceExists)
  width: 40
  height: 40

  Process {
    id: faceCheck
    command: ["test", "-f", root.facePath]
    onExited: function(exitCode) { root.faceExists = (exitCode === 0) }
  }

  Component.onCompleted: faceCheck.running = true

  Image {
    id: faceImage
    anchors.fill: parent
    visible: root.avatarSource.length > 0
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
