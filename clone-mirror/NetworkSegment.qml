import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NetworkModel.js" as NetworkModel

Row {
  id: root
  spacing: 6
  property var status: NetworkModel.parseNetworkStatus("")
  // Gates the poll timer so the preview instance (kept alive for the whole
  // shell session per the lock plugin's keepLoaded) doesn't poll forever
  // while the screen isn't actually locked or being previewed.
  property bool active: true
  visible: NetworkModel.isSegmentVisible(status.kind)

  Text {
    textFormat: Text.PlainText
    text: NetworkModel.connectionIcon(root.status.kind, root.status.signalStrength)
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    textFormat: Text.PlainText
    text: root.status.label
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  Process {
    id: statusProc
    command: ["omarchy-network-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.status = NetworkModel.parseNetworkStatus(text)
    }
  }

  Timer {
    interval: 5000
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }
}
