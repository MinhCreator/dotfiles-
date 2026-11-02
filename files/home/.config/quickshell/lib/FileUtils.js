.pragma library

/**
 * Trims the File protocol off the input string
 * @param {string} str
 * @returns {string}
 */
function trimFileProtocol(str) {
  return str.startsWith("file://") ? str.slice(7) : str;
}

/**
 * Extracts the file name from a file path
 * @param {string} str
 * @returns {string}
 */
function fileNameForPath(str) {
  if (typeof str !== "string") return "";
  const trimmed = trimFileProtocol(str);
  return trimmed.split(/[\\/]/).pop();
}

/**
 * Removes the file extension from a file path or name
 * @param {string} str
 * @returns {string}
 */
function trimFileExt(str) {
  if (typeof str !== "string") return "";
  const trimmed = trimFileProtocol(str);
  const lastDot = trimmed.lastIndexOf(".");
  if (lastDot > -1 && lastDot > trimmed.lastIndexOf("/")) {
    return trimmed.slice(0, lastDot);
  }
  return trimmed;
}

/**
 * Checks if a string is a valid Linux file/folder path using regex
 * @param {string} path
 * @returns {bool}
 */
function isValidPath(path) {
  if (typeof path !== "string") return false;

  const trimmed = trimFileProtocol(path);

  // Linux path regex: starts with / or ~, contains valid characters
  // Valid characters: letters, numbers, spaces, dots, hyphens, underscores, forward slashes
  const linuxPathRegex = /^(\/|~)([\w\s.\-\/])*$/;
  return linuxPathRegex.test(trimmed);
}
