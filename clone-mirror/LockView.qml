import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "LayoutPresets.js" as LayoutPresets
import "StylePresets.js" as StylePresets
import "BlurPresets.js" as BlurPresets

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
  // (lines "layout=<name>", "style=<name>", "blur=<name>"). Defaults match
  // the previous hardcoded cinematic layout, so an unconfigured install
  // looks exactly like it did before this feature existed. Blur is a
  // standalone axis, independent of the card/field style - not a style
  // property - so it gets its own name/preset/config key.
  property string layoutName: "cinematic"
  property string styleName: "no-card"
  property string blurName: "default"
  readonly property var activeLayout: LayoutPresets.wp_layout_preset(root.layoutName)
  readonly property var activeStyle: StylePresets.wp_style_preset(root.styleName)
  readonly property var activeBlur: BlurPresets.wp_blur_preset(root.blurName)

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
      if (key === "blur" && BlurPresets.wp_blur_exists(value)) root.blurName = value
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
      blur: root.activeBlur.blur
      blurMax: root.activeBlur.blurMax
      blurMultiplier: root.activeBlur.blurMultiplier
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
