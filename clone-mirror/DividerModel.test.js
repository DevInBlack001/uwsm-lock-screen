const assert = require("assert");
const { visibleDividers } = require("./DividerModel.js");

// avatar is always visible; battery/network/media can each hide. Each
// segment's own divider tracks only that segment's own visibility - Row
// collapses spacing around hidden siblings, so a hidden middle segment's
// divider never leaves a stray separator between the two still-visible
// segments on either side of it.
assert.deepStrictEqual(visibleDividers({ battery: true, network: true, media: true }), [true, true, true]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: true, media: true }), [false, true, true]);
assert.deepStrictEqual(visibleDividers({ battery: true, network: false, media: true }), [true, false, true]);
assert.deepStrictEqual(visibleDividers({ battery: false, network: false, media: false }), [false, false, false]);

console.log("DividerModel.test.js: all assertions passed");
