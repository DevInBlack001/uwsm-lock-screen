const assert = require("assert");
const { visibleDividers } = require("./DividerModel.js");

// avatar is always visible; battery/network/media can each hide.
assert.deepStrictEqual(visibleDividers({ battery: true, network: true, media: true }), [true, true, true]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: true, media: true }), [false, false, true]);
assert.deepStrictEqual(visibleDividers({ battery: true, network: false, media: true }), [true, false, false]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: false, media: false }), [false, false, false]);

console.log("DividerModel.test.js: all assertions passed");
