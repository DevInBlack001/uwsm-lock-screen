// 20 named visual presets for the card/field shell used across layouts.
// Each preset is pure data: background alpha, border treatment, corner
// radius, and whether to apply a drop shadow / text shadow. One shared
// rendering component (StyledCard.qml) applies whichever preset is active,
// rather than each style being its own hand-written QML file.
// Background blur is a separate, independently selected axis - see
// BlurPresets.js - not part of the card/field style.
var PRESETS = {
  "flat-bordered":   { bgAlpha: 0.55, borderWidth: 2, radius: 10, shadow: false, textShadow: false, underline: false },
  "soft-shadow":     { bgAlpha: 0.72, borderWidth: 0, radius: 16, shadow: true,  textShadow: false, underline: false },
  "warm-glass":      { bgAlpha: 0.45, borderWidth: 1, radius: 14, shadow: true,  textShadow: false, underline: false },
  "no-card":         { bgAlpha: 0.0,  borderWidth: 0, radius: 0,  shadow: false, textShadow: true,  underline: true  },
  "hairline":        { bgAlpha: 0.30, borderWidth: 1, radius: 4,  shadow: false, textShadow: true,  underline: false },
  "heavy-border":    { bgAlpha: 0.60, borderWidth: 4, radius: 6,  shadow: false, textShadow: false, underline: false },
  "pill":            { bgAlpha: 0.65, borderWidth: 0, radius: 999, shadow: true, textShadow: false, underline: false },
  "square":          { bgAlpha: 0.65, borderWidth: 2, radius: 0,  shadow: false, textShadow: false, underline: false },
  "frosted":         { bgAlpha: 0.38, borderWidth: 1, radius: 18, shadow: true,  textShadow: false, underline: false },
  "solid-dark":      { bgAlpha: 0.92, borderWidth: 0, radius: 12, shadow: false, textShadow: false, underline: false },
  "solid-light":     { bgAlpha: 0.88, borderWidth: 0, radius: 12, shadow: false, textShadow: false, underline: false, light: true },
  "outline-only":    { bgAlpha: 0.0,  borderWidth: 2, radius: 10, shadow: false, textShadow: true,  underline: false },
  "deep-shadow":     { bgAlpha: 0.50, borderWidth: 0, radius: 20, shadow: true,  shadowStrong: true, textShadow: false, underline: false },
  "thin-glass":      { bgAlpha: 0.22, borderWidth: 1, radius: 20, shadow: false, textShadow: true,  underline: false },
  "retro-terminal":  { bgAlpha: 0.85, borderWidth: 2, radius: 0,  shadow: false, textShadow: false, underline: false, monospace: true },
  "underline-thick":{ bgAlpha: 0.0,  borderWidth: 0, radius: 0,  shadow: false, textShadow: true,  underline: true, underlineWidth: 4 },
  "card-glow":       { bgAlpha: 0.40, borderWidth: 1, radius: 16, shadow: true,  shadowGlow: true,  textShadow: false, underline: false },
  "minimal-pill":    { bgAlpha: 0.25, borderWidth: 1, radius: 999, shadow: false, textShadow: true, underline: false },
  "brutalist":       { bgAlpha: 1.0,  borderWidth: 3, radius: 0,  shadow: false, textShadow: false, underline: false },
  "paper":           { bgAlpha: 0.80, borderWidth: 0, radius: 8,  shadow: true,  textShadow: false, underline: false, light: true }
};

var ORDER = [
  "flat-bordered", "soft-shadow", "warm-glass", "no-card", "hairline",
  "heavy-border", "pill", "square", "frosted", "solid-dark",
  "solid-light", "outline-only", "deep-shadow", "thin-glass", "retro-terminal",
  "underline-thick", "card-glow", "minimal-pill", "brutalist", "paper"
];

function wp_style_names() {
  return ORDER.slice();
}

function wp_style_preset(name) {
  return PRESETS[name] || PRESETS["flat-bordered"];
}

function wp_style_exists(name) {
  return Object.prototype.hasOwnProperty.call(PRESETS, name);
}

if (typeof module !== "undefined") {
  module.exports = {
    wp_style_names: wp_style_names,
    wp_style_preset: wp_style_preset,
    wp_style_exists: wp_style_exists
  };
}
