function pad2(n) {
  return n < 10 ? "0" + n : String(n);
}

function formatTime(date) {
  return pad2(date.getHours()) + ":" + pad2(date.getMinutes());
}

const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function formatDate(date) {
  return WEEKDAYS[date.getDay()] + ", " + MONTHS[date.getMonth()] + " " + date.getDate();
}

if (typeof module !== "undefined") {
  module.exports = { formatTime: formatTime, formatDate: formatDate };
}
