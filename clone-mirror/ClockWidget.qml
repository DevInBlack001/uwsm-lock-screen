import QtQuick
import qs.Commons
import qs.Ui
import "ClockModel.js" as ClockModel

Column {
  id: root
  spacing: 4

  Text {
    id: timeText
    anchors.horizontalCenter: parent.horizontalCenter
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.heading * 2.6
    text: ClockModel.formatTime(clockTimer.now)
  }

  Text {
    id: dateText
    anchors.horizontalCenter: parent.horizontalCenter
    color: Color.lock.placeholder
    font.family: Style.font.family
    font.pixelSize: Style.font.heading * 1.1
    text: ClockModel.formatDate(clockTimer.now)
  }

  QtObject {
    id: clockTimer
    property var now: new Date()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: clockTimer.now = new Date()
  }
}
