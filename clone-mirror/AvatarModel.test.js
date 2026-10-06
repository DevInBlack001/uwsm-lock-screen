const assert = require("assert");
const { resolveAvatarSource } = require("./AvatarModel.js");

assert.strictEqual(resolveAvatarSource("/home/alice/.face", true), "file:///home/alice/.face");
assert.strictEqual(resolveAvatarSource("/home/alice/.face", false), "");
assert.strictEqual(resolveAvatarSource("", false), "");

console.log("AvatarModel.test.js: all assertions passed");
