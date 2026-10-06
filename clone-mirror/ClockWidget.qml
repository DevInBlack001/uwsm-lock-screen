import QtQuick
import qs.Commons
import qs.Ui
import "ClockModel.js" as ClockModel

Column {
  id: root
  spacing: 4
  // Gates the 1s tick so the preview instance (kept alive for the whole
  // shell session) doesn't tick forever while not actually locked/previewed.
  property bool active: true

  Text {
    id: timeText
    color: Color.lock.text
    style: Text.Raised
    styleColor: "#000000"
    font.family: Style.font.family
    font.pixelSize: Style.font.heading * 1.5
    font.weight: Font.Light
    text: ClockModel.formatTime(clockTimer.now)
  }

  Text {
    id: dateText
    color: Color.lock.placeholder
    style: Text.Raised
    styleColor: "#000000"
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    text: ClockModel.formatDate(clockTimer.now)
  }

  QtObject {
    id: clockTimer
    property var now: new Date()
  }

  Timer {
    interval: 1000
    running: root.active
    repeat: true
    triggeredOnStart: true
    onTriggered: clockTimer.now = new Date()
  }
}
