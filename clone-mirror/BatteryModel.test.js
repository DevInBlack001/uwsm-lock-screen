const assert = require("assert");
const { isSegmentVisible, formatPercentage, batteryGlyph } = require("./BatteryModel.js");

assert.strictEqual(isSegmentVisible(true), true);
assert.strictEqual(isSegmentVisible(false), false);
assert.strictEqual(formatPercentage(0.82), "82%");
assert.strictEqual(formatPercentage(1), "100%");
assert.strictEqual(batteryGlyph(0.05, false), "");
assert.strictEqual(batteryGlyph(0.5, false), "");
assert.strictEqual(batteryGlyph(0.9, true), "");

console.log("BatteryModel.test.js: all assertions passed");
