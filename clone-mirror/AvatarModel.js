function resolveAvatarSource(facePath, faceExists) {
  if (!faceExists || !facePath) return "";
  return "file://" + facePath;
}

if (typeof module !== "undefined") {
  module.exports = { resolveAvatarSource: resolveAvatarSource };
}
