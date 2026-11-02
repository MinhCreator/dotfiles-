.pragma library

/**
 * Formats an ISO 8601 date string into a humanized format.
 * Returns formats like "Today at 21:00", "Wednesday 27 May at 20:00", or "23 Apr 2024".
 * @param {string} dateString - e.g., "2026-04-27T21:00:00Z" or "2026-04-27"
 * @returns {string}
 */
function formatFullDate(dateString) {
  if (!dateString) return "";

  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;

  const now = new Date();
  const hasTime = dateString.includes("T");

  const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetMidnight = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diffDays = Math.round((targetMidnight - todayMidnight) / (1000 * 60 * 60 * 24));

  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

  let dayPart = "";
  const isCurrentYear = date.getFullYear() === now.getFullYear();

  // 1. Determine the Day Name / Relative Part
  if (diffDays === 0) {
    dayPart = "Today";
  } else if (diffDays === 1) {
    dayPart = "Tomorrow";
  } else if (diffDays === -1) {
    dayPart = "Yesterday";
  } else {
    const dayName = days[date.getDay()];
    const dayNum = date.getDate();
    const monthName = months[date.getMonth()];
    const yearPart = isCurrentYear ? "" : ` ${date.getFullYear()}`;

    dayPart = `${dayName} ${dayNum} ${monthName}${yearPart}`;
  }

  // 2. Append Time if it exists
  if (hasTime) {
    const hh = String(date.getHours()).padStart(2, '0');
    const mm = String(date.getMinutes()).padStart(2, '0');
    return `${dayPart} at ${hh}:${mm}`;
  }

  return dayPart;
}

/**
 * Compares a date string to the current time.
 * Returns: -1 (Past), 0 (Today), 1 (Tomorrow), 2 (Future)
 * @param {string} dateString
 * @returns {number}
 */
function compareToNow(dateString) {
    if (!dateString) return 2;

    const date = new Date(dateString);
    const now = new Date();

    // Reset both to midnight to compare calendar days only
    const target = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

    const oneDay = 24 * 60 * 60 * 1000;

    if (target < today) return -1;
    if (target === today) return 0;
    if (target === today + oneDay) return 1;
    return 2;
}
