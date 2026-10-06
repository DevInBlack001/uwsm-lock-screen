import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "NetworkModel.js" as NetworkModel

Row {
  id: root
  spacing: 6
  property var status: NetworkModel.parseNetworkStatus("")
  visible: NetworkModel.isSegmentVisible(status.kind)

  Text {
    text: NetworkModel.connectionIcon(root.status.kind, root.status.signalStrength)
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
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
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }
}
