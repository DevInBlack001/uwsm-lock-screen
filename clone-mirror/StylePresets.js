// 20 named visual presets for the card/field shell used across layouts.
// Each preset is pure data: background alpha, border treatment, corner
// radius, background blur strength, and whether to apply a drop shadow /
// text shadow. One shared rendering component (StyledCard.qml) applies
// whichever preset is active, rather than each style being its own
// hand-written QML file.
// blurAmount feeds LockView.qml's MultiEffect.blur (0.0-1.0). "no-card" is
// the default style and must stay 1.0 - that was the original hardcoded
// blur value, so an unconfigured install still looks identical to before.
var PRESETS = {
  "flat-bordered":   { bgAlpha: 0.55, borderWidth: 2, radius: 10, shadow: false, textShadow: false, underline: false, blurAmount: 0.9 },
  "soft-shadow":     { bgAlpha: 0.72, borderWidth: 0, radius: 16, shadow: true,  textShadow: false, underline: false, blurAmount: 0.9 },
  "warm-glass":      { bgAlpha: 0.45, borderWidth: 1, radius: 14, shadow: true,  textShadow: false, underline: false, blurAmount: 0.7 },
  "no-card":         { bgAlpha: 0.0,  borderWidth: 0, radius: 0,  shadow: false, textShadow: true,  underline: true,  blurAmount: 1.0 },
  "hairline":        { bgAlpha: 0.30, borderWidth: 1, radius: 4,  shadow: false, textShadow: true,  underline: false, blurAmount: 0.6 },
  "heavy-border":    { bgAlpha: 0.60, borderWidth: 4, radius: 6,  shadow: false, textShadow: false, underline: false, blurAmount: 0.9 },
  "pill":            { bgAlpha: 0.65, borderWidth: 0, radius: 999, shadow: true, textShadow: false, underline: false, blurAmount: 0.8 },
  "square":          { bgAlpha: 0.65, borderWidth: 2, radius: 0,  shadow: false, textShadow: false, underline: false, blurAmount: 0.9 },
  "frosted":         { bgAlpha: 0.38, borderWidth: 1, radius: 18, shadow: true,  textShadow: false, underline: false, blurAmount: 1.0 },
  "solid-dark":      { bgAlpha: 0.92, borderWidth: 0, radius: 12, shadow: false, textShadow: false, underline: false, blurAmount: 0.5 },
  "solid-light":     { bgAlpha: 0.88, borderWidth: 0, radius: 12, shadow: false, textShadow: false, underline: false, light: true, blurAmount: 0.5 },
  "outline-only":    { bgAlpha: 0.0,  borderWidth: 2, radius: 10, shadow: false, textShadow: true,  underline: false, blurAmount: 0.7 },
  "deep-shadow":     { bgAlpha: 0.50, borderWidth: 0, radius: 20, shadow: true,  shadowStrong: true, textShadow: false, underline: false, blurAmount: 0.9 },
  "thin-glass":      { bgAlpha: 0.22, borderWidth: 1, radius: 20, shadow: false, textShadow: true,  underline: false, blurAmount: 0.5 },
  "retro-terminal":  { bgAlpha: 0.85, borderWidth: 2, radius: 0,  shadow: false, textShadow: false, underline: false, monospace: true, blurAmount: 0.3 },
  "underline-thick":{ bgAlpha: 0.0,  borderWidth: 0, radius: 0,  shadow: false, textShadow: true,  underline: true, underlineWidth: 4, blurAmount: 1.0 },
  "card-glow":       { bgAlpha: 0.40, borderWidth: 1, radius: 16, shadow: true,  shadowGlow: true,  textShadow: false, underline: false, blurAmount: 0.8 },
  "minimal-pill":    { bgAlpha: 0.25, borderWidth: 1, radius: 999, shadow: false, textShadow: true, underline: false, blurAmount: 0.6 },
  "brutalist":       { bgAlpha: 1.0,  borderWidth: 3, radius: 0,  shadow: false, textShadow: false, underline: false, blurAmount: 0.4 },
  "paper":           { bgAlpha: 0.80, borderWidth: 0, radius: 8,  shadow: true,  textShadow: false, underline: false, light: true, blurAmount: 0.6 }
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
