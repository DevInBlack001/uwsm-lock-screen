// 20 named layout presets. Each is pure data describing where the clock
// sits, where the status info sits, and how big the clock renders - one
// shared component (AdaptiveLayout.qml) reads whichever preset is active
// and positions the real widgets accordingly, rather than each layout
// being its own hand-written QML file.
//
// clockAnchor: "top-left" | "top-center" | "top-right" | "center-above-password"
// statusArrangement: "corners" (scattered bottom-left/right, no card - the
//   "cinematic" look) | "card-below" (single card under the password field)
// passwordStyle: "box" | "underline"
// clockScale: multiplier on the base clock font size, for size variety
var PRESETS = {
  "cinematic":            { clockAnchor: "top-left",            statusArrangement: "corners",   passwordStyle: "underline", clockScale: 1.0 },
  "classic-card":         { clockAnchor: "center-above-password", statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.7 },
  "top-right-corners":    { clockAnchor: "top-right",           statusArrangement: "corners",   passwordStyle: "underline", clockScale: 1.0 },
  "top-center-card":      { clockAnchor: "top-center",          statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.3 },
  "minimal-corners":      { clockAnchor: "top-left",            statusArrangement: "corners",   passwordStyle: "underline", clockScale: 0.7 },
  "oversized-clock":      { clockAnchor: "center-above-password", statusArrangement: "card-below", passwordStyle: "underline", clockScale: 2.2 },
  "compact-card":         { clockAnchor: "top-left",            statusArrangement: "card-below", passwordStyle: "box",       clockScale: 0.8 },
  "right-corners-box":    { clockAnchor: "top-right",           statusArrangement: "corners",   passwordStyle: "box",       clockScale: 1.0 },
  "centered-minimal":     { clockAnchor: "center-above-password", statusArrangement: "corners",   passwordStyle: "underline", clockScale: 1.4 },
  "top-left-card":        { clockAnchor: "top-left",            statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.0 },
  "large-corners":        { clockAnchor: "top-center",          statusArrangement: "corners",   passwordStyle: "underline", clockScale: 1.6 },
  "boxed-minimal":        { clockAnchor: "top-left",            statusArrangement: "corners",   passwordStyle: "box",       clockScale: 0.9 },
  "card-top-right":       { clockAnchor: "top-right",           statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.1 },
  "small-centered-card":  { clockAnchor: "center-above-password", statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.0 },
  "dashboard":            { clockAnchor: "top-right",           statusArrangement: "card-below", passwordStyle: "underline", clockScale: 1.2 },
  "giant-corners":        { clockAnchor: "top-left",            statusArrangement: "corners",   passwordStyle: "underline", clockScale: 2.5 },
  "understated":          { clockAnchor: "top-right",           statusArrangement: "corners",   passwordStyle: "underline", clockScale: 0.6 },
  "framed-card":          { clockAnchor: "top-center",          statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.0 },
  "card-underline-mix":   { clockAnchor: "top-left",            statusArrangement: "card-below", passwordStyle: "underline", clockScale: 1.0 },
  "classic-default":      { clockAnchor: "center-above-password", statusArrangement: "card-below", passwordStyle: "box",       clockScale: 1.5 }
};

var ORDER = [
  "cinematic", "classic-card", "top-right-corners", "top-center-card", "minimal-corners",
  "oversized-clock", "compact-card", "right-corners-box", "centered-minimal", "top-left-card",
  "large-corners", "boxed-minimal", "card-top-right", "small-centered-card", "dashboard",
  "giant-corners", "understated", "framed-card", "card-underline-mix", "classic-default"
];

function wp_layout_names() {
  return ORDER.slice();
}

function wp_layout_preset(name) {
  return PRESETS[name] || PRESETS["cinematic"];
}

function wp_layout_exists(name) {
  return Object.prototype.hasOwnProperty.call(PRESETS, name);
}

if (typeof module !== "undefined") {
  module.exports = {
    wp_layout_names: wp_layout_names,
    wp_layout_preset: wp_layout_preset,
    wp_layout_exists: wp_layout_exists
  };
}
