import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Renders whichever layout preset (LayoutPresets.js) and style preset
// (StylePresets.js) are active. One flexible component instead of N
// hand-written layout files - a preset is a position on a small grid of
// axes (clock position x status arrangement x password field style), not
// a bespoke design.
Item {
  id: view
  required property var root
  required property var layout
  required property var style

  anchors.fill: parent

  ClockWidget {
    id: clockW
    active: root.loadBackground
    scale: view.layout.clockScale || 1.0
    transformOrigin: {
      switch (view.layout.clockAnchor) {
        case "top-right": return Item.TopRight
        case "top-center": return Item.Top
        case "center-above-password": return Item.Bottom
        default: return Item.TopLeft
      }
    }

    states: [
      State {
        name: "top-left"
        when: view.layout.clockAnchor === "top-left"
        AnchorChanges { target: clockW; anchors.left: view.left; anchors.top: view.top }
        PropertyChanges { clockW.anchors.leftMargin: 32; clockW.anchors.topMargin: 28 }
      },
      State {
        name: "top-right"
        when: view.layout.clockAnchor === "top-right"
        AnchorChanges { target: clockW; anchors.right: view.right; anchors.top: view.top }
        PropertyChanges { clockW.anchors.rightMargin: 32; clockW.anchors.topMargin: 28 }
      },
      State {
        name: "top-center"
        when: view.layout.clockAnchor === "top-center"
        AnchorChanges { target: clockW; anchors.horizontalCenter: view.horizontalCenter; anchors.top: view.top }
        PropertyChanges { clockW.anchors.topMargin: 32 }
      },
      State {
        name: "center-above-password"
        when: view.layout.clockAnchor === "center-above-password"
        AnchorChanges { target: clockW; anchors.horizontalCenter: view.horizontalCenter; anchors.bottom: pwField.top }
        PropertyChanges { clockW.anchors.bottomMargin: 32 }
      }
    ]
  }

  PasswordField {
    id: pwField
    root: view.root
    // The layout preset decides box-vs-underline shape (a geometry
    // decision); the style preset decides everything else (opacity,
    // border width, radius, shadow, font, color) - explicit object
    // literal rather than mutating the shared style preset object.
    style: ({
      bgAlpha: view.style.bgAlpha,
      borderWidth: view.style.borderWidth,
      radius: view.style.radius,
      shadow: view.style.shadow,
      shadowStrong: view.style.shadowStrong,
      shadowGlow: view.style.shadowGlow,
      textShadow: view.style.textShadow,
      underline: view.layout.passwordStyle === "underline",
      underlineWidth: view.style.underlineWidth,
      monospace: view.style.monospace,
      light: view.style.light
    })
    anchors.centerIn: parent
  }

  // Status arrangement: "corners" scatters battery/network bottom-left and
  // avatar/username/media bottom-right (no card, the cinematic look).
  // "card-below" is a single AdaptiveStatusCard under the password field.
  Column {
    id: cornerLeft
    visible: view.layout.statusArrangement === "corners"
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.leftMargin: 32
    anchors.bottomMargin: 28
    spacing: 6
    BatterySegment { id: cornerBattery }
    NetworkSegment { id: cornerNetwork; active: view.root.loadBackground }
  }

  Column {
    id: cornerRight
    visible: view.layout.statusArrangement === "corners"
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 32
    anchors.bottomMargin: 28
    spacing: 6

    Row {
      anchors.right: parent.right
      spacing: 8
      AvatarWidget { width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter }
      Text {
        textFormat: Text.PlainText
        text: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
        color: Color.lock.text
        style: Text.Raised
        styleColor: "#000000"
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MediaSegment { id: cornerMedia; anchors.right: parent.right }
  }

  AdaptiveStatusCard {
    id: statusCard
    visible: view.layout.statusArrangement === "card-below"
    root: view.root
    style: view.style
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: pwField.bottom
    anchors.topMargin: 32
  }
}
