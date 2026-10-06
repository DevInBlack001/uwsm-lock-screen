const assert = require("assert");
const { selectActivePlayer, hasVisibleMedia, trackLabel } = require("./MediaModel.js");

const playing = { isPlaying: true, canPlay: true, canPause: true, trackTitle: "Song A", trackArtist: "Artist A" };
const idleControllable = { isPlaying: false, canPlay: true, canPause: false, trackTitle: "Song B", trackArtist: "" };
const noControl = { isPlaying: false, canPlay: false, canPause: false, trackTitle: "", trackArtist: "" };

assert.strictEqual(selectActivePlayer([noControl, playing, idleControllable]), playing);
assert.strictEqual(selectActivePlayer([noControl, idleControllable]), idleControllable);
assert.strictEqual(selectActivePlayer([noControl]), null);
assert.strictEqual(selectActivePlayer([]), null);

assert.strictEqual(hasVisibleMedia(playing), true);
assert.strictEqual(hasVisibleMedia(null), false);
assert.strictEqual(hasVisibleMedia(noControl), false);

assert.strictEqual(trackLabel(playing), "Song A - Artist A");
assert.strictEqual(trackLabel(idleControllable), "Song B");
assert.strictEqual(trackLabel(null), "");

console.log("MediaModel.test.js: all assertions passed");
