import QtQuick
import qs.Commons
import qs.Ui

Row {
  id: root
  spacing: 12
  required property var player

  Text {
    text: "󰒮"
    color: root.player && root.player.canGoPrevious ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: root.player && root.player.canGoPrevious
      onClicked: root.player.previous()
    }
  }

  Text {
    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
    color: root.player && (root.player.canPlay || root.player.canPause) ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: root.player && (root.player.canPlay || root.player.canPause)
      onClicked: root.player.isPlaying ? root.player.pause() : root.player.play()
    }
  }

  Text {
    text: "󰒭"
    color: root.player && root.player.canGoNext ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: root.player && root.player.canGoNext
      onClicked: root.player.next()
    }
  }
}
