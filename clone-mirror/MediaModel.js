function canControl(player) {
  return !!player && (player.canPlay || player.canPause);
}

function selectActivePlayer(players) {
  var list = players || [];
  var playing = null;
  var controllable = null;

  for (var i = 0; i < list.length; i++) {
    var p = list[i];
    if (!p) continue;
    if (p.isPlaying && !playing) playing = p;
    else if (canControl(p) && !controllable) controllable = p;
  }

  return playing || controllable || null;
}

function hasVisibleMedia(player) {
  return canControl(player) && !!(player.trackTitle || player.trackArtist);
}

function trackLabel(player) {
  if (!player) return "";
  var title = player.trackTitle || "";
  var artist = player.trackArtist || "";
  if (title && artist) return title + " — " + artist;
  return title || artist || "";
}

if (typeof module !== "undefined") {
  module.exports = {
    selectActivePlayer: selectActivePlayer,
    hasVisibleMedia: hasVisibleMedia,
    trackLabel: trackLabel
  };
}
