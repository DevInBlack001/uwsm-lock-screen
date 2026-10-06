function parseNetworkStatus(raw) {
  var parts = String(raw || "disconnected\t\t\t").replace(/\r?\n+$/, "").split("\t");
  return {
    kind: parts[0] || "disconnected",
    label: parts[1] || "",
    signalStrength: parts[2] ? parseInt(parts[2], 10) : -1,
    frequency: parts[3] || ""
  };
}

function wifiIconFor(strength) {
  var icons = ["\u{f092f}", "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"];
  var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1));
  return icons[index];
}

function connectionIcon(kind, signalStrength) {
  if (kind === "wifi") return wifiIconFor(signalStrength);
  if (kind === "ethernet") return "\u{f0200}";
  return "\u{f092f}";
}

function isSegmentVisible(kind) {
  return kind === "wifi" || kind === "ethernet";
}

if (typeof module !== "undefined") {
  module.exports = {
    parseNetworkStatus: parseNetworkStatus,
    wifiIconFor: wifiIconFor,
    connectionIcon: connectionIcon,
    isSegmentVisible: isSegmentVisible
  };
}
