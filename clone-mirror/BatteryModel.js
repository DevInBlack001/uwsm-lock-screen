function isSegmentVisible(hasBattery) {
  return !!hasBattery;
}

function formatPercentage(fraction) {
  return Math.round(fraction * 100) + "%";
}

// Charging always shows the bolt glyph regardless of level.
function batteryGlyph(fraction, isCharging) {
  if (isCharging) return "";
  if (fraction < 0.15) return "";
  if (fraction < 0.40) return "";
  if (fraction < 0.65) return "";
  if (fraction < 0.90) return "";
  return "";
}

if (typeof module !== "undefined") {
  module.exports = {
    isSegmentVisible: isSegmentVisible,
    formatPercentage: formatPercentage,
    batteryGlyph: batteryGlyph
  };
}
