const assert = require("assert");
const { avatarFileUrl } = require("./AvatarModel.js");

// No existence check here on purpose: the widget now always attempts the
// load and falls back on Image.status, which also covers a path that
// exists but is unreadable/corrupt/empty - a plain exists-check can't.
assert.strictEqual(avatarFileUrl("/home/alice/.face"), "file:///home/alice/.face");
assert.strictEqual(avatarFileUrl(""), "");

console.log("AvatarModel.test.js: all assertions passed");
