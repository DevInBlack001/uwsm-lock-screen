import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "LayoutPresets.js" as LayoutPresets
import "StylePresets.js" as StylePresets

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  // Set by whichever PasswordField instance the active layout creates, so
  // forcePasswordFocus()/clearPassword() keep working for Service.qml
  // regardless of which layout/style preset is selected.
  property var currentPasswordField: null

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // Appearance selection, read from ~/.config/uwsm-lock-screen/appearance.conf
  // (two lines: "layout=<name>" and "style=<name>"). Defaults match the
  // previous hardcoded cinematic layout, so an unconfigured install looks
  // exactly like it did before this feature existed.
  property string layoutName: "cinematic"
  property string styleName: "no-card"
  readonly property var activeLayout: LayoutPresets.wp_layout_preset(root.layoutName)
  readonly property var activeStyle: StylePresets.wp_style_preset(root.styleName)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    if (root.currentPasswordField) root.currentPasswordField.forcePasswordFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function parseAppearanceConfig(text) {
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line.length === 0 || line.charAt(0) === "#") continue
      var eq = line.indexOf("=")
      if (eq === -1) continue
      var key = line.substring(0, eq).trim()
      var value = line.substring(eq + 1).trim()
      if (key === "layout" && LayoutPresets.wp_layout_exists(value)) root.layoutName = value
      if (key === "style" && StylePresets.wp_style_exists(value)) root.styleName = value
    }
  }

  function refreshAppearanceConfig() {
    if (!appearanceConfigProc.running) appearanceConfigProc.running = true
  }

  Process {
    id: appearanceConfigProc
    command: ["cat", Quickshell.env("HOME") + "/.config/uwsm-lock-screen/appearance.conf"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseAppearanceConfig(text)
    }
  }

  Component.onCompleted: root.refreshAppearanceConfig()

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    AdaptiveLayout {
      anchors.fill: parent
      root: root
      layout: root.activeLayout
      style: root.activeStyle
    }
  }
}
