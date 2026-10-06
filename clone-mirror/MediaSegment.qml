import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "MediaModel.js" as MediaModel

Row {
  id: root
  spacing: 10
  readonly property var activePlayer: MediaModel.selectActivePlayer(Mpris.players ? Mpris.players.values : [])
  visible: MediaModel.hasVisibleMedia(activePlayer)

  Text {
    text: MediaModel.trackLabel(root.activePlayer)
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
    width: 160
  }

  MediaControls {
    player: root.activePlayer
  }
}
