// Segments sit in a fixed 4-slot layout: avatar, battery, network, media.
// Avatar is always visible, so each segment's own leading divider tracks
// only that segment's own visibility. Row removes spacing around any
// visible:false child, so a hidden middle segment's divider (also hidden)
// never leaves a stray double-gap.
function visibleDividers(segments) {
  var s = segments || {};
  return [!!s.battery, !!s.network, !!s.media];
}

if (typeof module !== "undefined") {
  module.exports = { visibleDividers: visibleDividers };
}
