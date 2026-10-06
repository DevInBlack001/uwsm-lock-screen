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
    // The action a click actually performs is pause-if-playing or
    // play-if-not, so enabled must track the capability for THAT action,
    // not "either capability" - a playing player with canPause:false would
    // otherwise show an enabled button that silently does nothing.
    readonly property bool playPauseEnabled: root.player && (root.player.isPlaying ? root.player.canPause : root.player.canPlay)
    text: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
    color: playPauseEnabled ? Color.lock.text : Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    MouseArea {
      anchors.fill: parent
      enabled: parent.playPauseEnabled
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
