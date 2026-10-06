import QtQuick
import qs.Commons
import qs.Ui

// Self-contained password entry field, shared by every layout. Reads/writes
// state on `root` (the LockView instance) and registers itself as
// root.currentPasswordField on load, so root.forcePasswordFocus()/
// clearPassword() keep working regardless of which layout is active -
// Service.qml's contract with LockView never changes.
BorderSurface {
  id: field
  required property var root
  // Style preset object from StylePresets.js (passed as a plain JS object,
  // not a QML type, to keep the 20 presets as pure data). `underline: true`
  // means a bottom-only border with no fill; otherwise a filled card using
  // the preset's bgAlpha/borderWidth/radius.
  required property var style
  readonly property bool underline: !!style.underline

  width: root.fieldWidth
  height: root.fieldHeight
  color: underline ? "transparent" : Qt.rgba(0, 0, 0, style.bgAlpha)
  borderSpec: underline
    ? Border.withWidth(root.inputBorderSpec, "0 0 " + (style.underlineWidth || 2) + " 0")
    : Border.withWidth(root.inputBorderSpec, String(style.borderWidth))
  radius: underline ? 0 : style.radius
  clip: true

  readonly property string fontFamily: style.monospace ? "monospace" : Style.font.family
  readonly property color textColor: style.light ? "#1a1a1a" : Color.lock.text

  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: root.fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible - otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function syncPasswordText() {
    if (passwordInput.text === root.passwordText) return
    root.syncingPasswordText = true
    passwordInput.text = root.passwordText
    root.syncingPasswordText = false
  }

  Component.onCompleted: {
    root.currentPasswordField = field
    syncPasswordText()
    if (root.inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  Connections {
    target: root
    function onPasswordTextChanged() { field.syncPasswordText() }
    function onInputEnabledChanged() {
      if (root.inputEnabled) Qt.callLater(field.forcePasswordFocus)
    }
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  TextInput {
    id: passwordInput
    anchors.fill: parent
    anchors.topMargin: field.borderTop
    anchors.rightMargin: field.borderRight + 18 + field.fingerprintReserve
    anchors.bottomMargin: field.borderBottom
    anchors.leftMargin: field.borderLeft + 18 + field.fingerprintReserve
    verticalAlignment: TextInput.AlignVCenter
    horizontalAlignment: TextInput.AlignHCenter
    activeFocusOnPress: true
    clip: true
    enabled: root.inputEnabled && !root.authenticatingPassword
    readOnly: root.authenticatingPassword
    echoMode: TextInput.Password
    passwordCharacter: "●"
    passwordMaskDelay: 0
    color: field.textColor
    selectionColor: Color.lock.selection
    selectedTextColor: field.textColor
    font.family: field.fontFamily
    font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * field.passwordDotScale)) : root.fieldFontSize
    font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * field.passwordDotScale : 0
    cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
    cursorDelegate: Rectangle {
      width: 2
      color: Color.lock.text
      visible: passwordInput.cursorVisible
    }

    onTextChanged: {
      if (!root.syncingPasswordText) root.passwordTextEdited(text)
      if (text.length > 0) {
        root.wakeRequested()
      }
      if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
    }

    onAccepted: {
      var submitted = root.passwordText
      root.passwordTextEdited("")
      if (submitted.length > 0) root.submitPassword(submitted)
    }

    Keys.onPressed: function(event) {
      root.wakeRequested()
      if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
        root.passwordTextEdited("")
        event.accepted = true
      }
    }
  }

  Text {
    textFormat: Text.PlainText
    anchors.fill: passwordInput
    text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
    visible: passwordInput.text.length === 0
    color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
    style: field.style.textShadow ? Text.Raised : Text.Normal
    styleColor: "#000000"
    font.family: Style.font.family
    font.pixelSize: root.fieldFontSize
    font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  // Fingerprint hint pinned inside the field's right edge when a sensor is
  // enrolled, so the user knows they can touch to unlock instead of typing.
  // Matches hyprlock, which draws its fingerprint icon in the same spot.
  Text {
    id: fingerprintIcon
    objectName: "fingerprintIndicator"
    anchors.right: parent.right
    anchors.rightMargin: field.borderRight + 18
    anchors.verticalCenter: parent.verticalCenter
    visible: root.fingerprintConfigured
    text: "󰈷"
    color: Color.lock.placeholder
    style: field.style.textShadow ? Text.Raised : Text.Normal
    styleColor: "#000000"
    font.family: Style.font.family
    font.pixelSize: Math.round(root.fieldFontSize * 1.1)
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
