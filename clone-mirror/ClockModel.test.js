const assert = require("assert");
const { formatTime, formatDate } = require("./ClockModel.js");

const sample = new Date(2026, 9, 6, 14, 7, 0); // October 6 2026, 14:07

assert.strictEqual(formatTime(sample), "14:07");
assert.strictEqual(formatDate(sample), "Tuesday, October 6");

const midnight = new Date(2026, 0, 1, 0, 5, 0);
assert.strictEqual(formatTime(midnight), "00:05");

console.log("ClockModel.test.js: all assertions passed");
