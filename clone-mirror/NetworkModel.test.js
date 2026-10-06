const assert = require("assert");
const { parseNetworkStatus, connectionIcon, isSegmentVisible } = require("./NetworkModel.js");

const wifi = parseNetworkStatus("wifi\tHomeNet\t78\t5180");
assert.strictEqual(wifi.kind, "wifi");
assert.strictEqual(wifi.label, "HomeNet");
assert.strictEqual(wifi.signalStrength, 78);

const ethernet = parseNetworkStatus("ethernet\t\t\t");
assert.strictEqual(ethernet.kind, "ethernet");

const disconnected = parseNetworkStatus("disconnected\t\t\t");
assert.strictEqual(disconnected.kind, "disconnected");

assert.strictEqual(isSegmentVisible("wifi"), true);
assert.strictEqual(isSegmentVisible("ethernet"), true);
assert.strictEqual(isSegmentVisible("disconnected"), false);

assert.strictEqual(connectionIcon("ethernet", -1), "\u{f0200}");
assert.strictEqual(connectionIcon("wifi", 90), "\u{f0928}");

console.log("NetworkModel.test.js: all assertions passed");
