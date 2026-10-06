function avatarFileUrl(facePath) {
  if (!facePath) return "";
  return "file://" + facePath;
}

if (typeof module !== "undefined") {
  module.exports = { avatarFileUrl: avatarFileUrl };
}
