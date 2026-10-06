const assert = require("assert");
const { visibleDividers } = require("./DividerModel.js");

assert.deepStrictEqual(visibleDividers({ battery: true, network: true, media: true }), [true, true, true]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: true, media: true }), [false, true, true]);
assert.deepStrictEqual(visibleDividers({ battery: true, network: false, media: true }), [true, false, true]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: false, media: false }), [false, false, false]);

console.log("DividerModel.test.js: all assertions passed");
