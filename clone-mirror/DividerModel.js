// Segments sit in a fixed 4-slot layout: avatar, battery, network, media.
// Avatar is always visible. divider[i] is true only if both of its fixed
// immediate neighbors are visible. Row already removes spacing around any
// visible:false child, so a hidden middle segment's surrounding gaps close
// up on their own - this only decides whether to draw the vertical line.
function visibleDividers(segments) {
  var s = segments || {};
  var slots = [true, !!s.battery, !!s.network, !!s.media]; // avatar, battery, network, media

  return [
    slots[0] && slots[1], // avatar | battery
    slots[1] && slots[2], // battery | network
    slots[2] && slots[3]  // network | media
  ];
}

if (typeof module !== "undefined") {
  module.exports = { visibleDividers: visibleDividers };
}
