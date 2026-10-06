import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "BatteryModel.js" as BatteryModel

Row {
  id: root
  spacing: 6
  readonly property var device: UPower.displayDevice
  readonly property bool hasBattery: !!device && device.isLaptopBattery
  visible: BatteryModel.isSegmentVisible(hasBattery)

  Text {
    text: root.hasBattery ? BatteryModel.batteryGlyph(root.device.percentage, root.device.state === UPowerDeviceState.Charging) : ""
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  Text {
    text: root.hasBattery ? BatteryModel.formatPercentage(root.device.percentage) : ""
    color: Color.lock.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
}
