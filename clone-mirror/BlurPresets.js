// Named background blur presets - a standalone axis, independent of the
// card/field style (StylePresets.js) and the layout (LayoutPresets.js).
// Each preset controls all three of MultiEffect's blur knobs together:
// blur alone (0.0-1.0) barely changes the visible result when blurMax and
// blurMultiplier stay fixed, since blur is just a fraction of that fixed
// radius - so blurMax/blurMultiplier scale per preset too, for a range
// that's actually visible from "off" to "max".
// "default" matches the original hardcoded values (blur: 1.0, blurMax:
// 128, blurMultiplier: 1.25) exactly, so an unconfigured install looks
// identical to before this feature existed.
var PRESETS = {
  "off":     { blur: 0.0, blurMax: 1,   blurMultiplier: 1.0  },
  "subtle":  { blur: 0.4, blurMax: 48,  blurMultiplier: 1.0  },
  "light":   { blur: 0.6, blurMax: 72,  blurMultiplier: 1.0  },
  "default": { blur: 1.0, blurMax: 128, blurMultiplier: 1.25 },
  "heavy":   { blur: 1.0, blurMax: 200, blurMultiplier: 1.5  },
  "max":     { blur: 1.0, blurMax: 256, blurMultiplier: 1.75 }
};

var ORDER = [
  "off", "subtle", "light", "default", "heavy", "max"
];

function wp_blur_names() {
  return ORDER.slice();
}

function wp_blur_preset(name) {
  return PRESETS[name] || PRESETS["default"];
}

function wp_blur_exists(name) {
  return Object.prototype.hasOwnProperty.call(PRESETS, name);
}

if (typeof module !== "undefined") {
  module.exports = {
    wp_blur_names: wp_blur_names,
    wp_blur_preset: wp_blur_preset,
    wp_blur_exists: wp_blur_exists
  };
}
