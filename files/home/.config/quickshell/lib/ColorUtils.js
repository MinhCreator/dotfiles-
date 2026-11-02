.pragma library

/**
 * Checks if a string represents a valid color in any QML-supported format.
 * Supports: hex (#RRGGBB, #AARRGGBB, #RGB), RGB, RGBA, HSL, HSLA, HSV, HSVA, CMYK, and named colors.
 *
 * @param {string} colorString - The string to check.
 * @returns {boolean} True if the string is a valid color format.
 */
function isColor(colorString) {
  if (!colorString || typeof colorString !== "string") {
    return false;
  }

  var str = colorString.trim();

  // Try Qt.color first (handles hex and named colors)
  try {
    var testColor = Qt.color(str);
    if (testColor.valid) {
      return true;
    }
  } catch (e) {
    // Continue to other format checks
  }

  // Check RGB format: "r, g, b" or "r g b"
  var rgbMatch = str.match(/^\s*(\d+)\s*[,\s]\s*(\d+)\s*[,\s]\s*(\d+)\s*$/);
  if (rgbMatch) {
    var r = parseInt(rgbMatch[1]);
    var g = parseInt(rgbMatch[2]);
    var b = parseInt(rgbMatch[3]);
    return r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255;
  }

  // Check RGBA format: "r, g, b, a"
  var rgbaMatch = str.match(
    /^\s*(\d+)\s*[,\s]\s*(\d+)\s*[,\s]\s*(\d+)\s*[,\s]\s*([\d.]+)\s*$/,
  );
  if (rgbaMatch) {
    var r = parseInt(rgbaMatch[1]);
    var g = parseInt(rgbaMatch[2]);
    var b = parseInt(rgbaMatch[3]);
    var a = parseFloat(rgbaMatch[4]);
    return (
      r >= 0 &&
      r <= 255 &&
      g >= 0 &&
      g <= 255 &&
      b >= 0 &&
      b <= 255 &&
      a >= 0 &&
      a <= 1
    );
  }

  // Check HSL format: "h s% l%" or "h, s%, l%"
  var hslMatch = str.match(/^\s*(\d+)\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*$/);
  if (hslMatch) {
    var h = parseInt(hslMatch[1]);
    var s = parseInt(hslMatch[2]);
    var l = parseInt(hslMatch[3]);
    return h >= 0 && h <= 360 && s >= 0 && s <= 100 && l >= 0 && l <= 100;
  }

  // Check HSLA format: "h, s%, l%, a"
  var hslaMatch = str.match(
    /^\s*(\d+)\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*[,\s]\s*([\d.]+)\s*$/,
  );
  if (hslaMatch) {
    var h = parseInt(hslaMatch[1]);
    var s = parseInt(hslaMatch[2]);
    var l = parseInt(hslaMatch[3]);
    var a = parseFloat(hslaMatch[4]);
    return (
      h >= 0 &&
      h <= 360 &&
      s >= 0 &&
      s <= 100 &&
      l >= 0 &&
      l <= 100 &&
      a >= 0 &&
      a <= 1
    );
  }

  // Check HSV format: "h s% v%" or "h, s%, v%"
  var hsvMatch = str.match(/^\s*(\d+)\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*$/);
  if (hsvMatch) {
    var h = parseInt(hsvMatch[1]);
    var s = parseInt(hsvMatch[2]);
    var v = parseInt(hsvMatch[3]);
    return h >= 0 && h <= 360 && s >= 0 && s <= 100 && v >= 0 && v <= 100;
  }

  // Check CMYK format: "c% m% y% k%" or "c%, m%, y%, k%"
  var cmykMatch = str.match(
    /^\s*(\d+)%\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*$/,
  );
  if (cmykMatch) {
    var c = parseInt(cmykMatch[1]);
    var m = parseInt(cmykMatch[2]);
    var y = parseInt(cmykMatch[3]);
    var k = parseInt(cmykMatch[4]);
    return (
      c >= 0 &&
      c <= 100 &&
      m >= 0 &&
      m <= 100 &&
      y >= 0 &&
      y <= 100 &&
      k >= 0 &&
      k <= 100
    );
  }

  return false;
}

/**
 * Converts a color string in any of the formats supported by isColor()
 * into a QML `color` value (via Qt.rgba), suitable for direct assignment
 * to a `color` property.
 *
 * @param {string} colorString - The string to convert.
 * @returns {color|undefined} A QML color, or undefined if invalid.
 */
function toQmlColor(colorString) {
  if (!colorString || typeof colorString !== "string") {
    return undefined;
  }

  var str = colorString.trim();

  // Hex / named colors: Qt.color already returns a QML color object
  try {
    var testColor = Qt.color(str);
    if (testColor.valid) {
      return testColor;
    }
  } catch (e) {
    // fall through
  }

  // RGB: "r, g, b" or "r g b"
  var rgbMatch = str.match(/^\s*(\d+)\s*[,\s]\s*(\d+)\s*[,\s]\s*(\d+)\s*$/);
  if (rgbMatch) {
    var r = parseInt(rgbMatch[1]);
    var g = parseInt(rgbMatch[2]);
    var b = parseInt(rgbMatch[3]);
    if (r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255) {
      return Qt.rgba(r / 255, g / 255, b / 255, 1);
    }
  }

  // RGBA: "r, g, b, a"
  var rgbaMatch = str.match(
    /^\s*(\d+)\s*[,\s]\s*(\d+)\s*[,\s]\s*(\d+)\s*[,\s]\s*([\d.]+)\s*$/,
  );
  if (rgbaMatch) {
    var r2 = parseInt(rgbaMatch[1]);
    var g2 = parseInt(rgbaMatch[2]);
    var b2 = parseInt(rgbaMatch[3]);
    var a2 = parseFloat(rgbaMatch[4]);
    if (
      r2 >= 0 && r2 <= 255 &&
      g2 >= 0 && g2 <= 255 &&
      b2 >= 0 && b2 <= 255 &&
      a2 >= 0 && a2 <= 1
    ) {
      return Qt.rgba(r2 / 255, g2 / 255, b2 / 255, a2);
    }
  }

  // HSL: "h, s%, l%" (also matches what isColor() treats as HSV — see note below)
  var hslMatch = str.match(/^\s*(\d+)\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*$/);
  if (hslMatch) {
    var h = parseInt(hslMatch[1]);
    var s = parseInt(hslMatch[2]);
    var l = parseInt(hslMatch[3]);
    if (h >= 0 && h <= 360 && s >= 0 && s <= 100 && l >= 0 && l <= 100) {
      return Qt.hsla(h / 360, s / 100, l / 100, 1);
    }
  }

  // HSLA: "h, s%, l%, a"
  var hslaMatch = str.match(
    /^\s*(\d+)\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*[,\s]\s*([\d.]+)\s*$/,
  );
  if (hslaMatch) {
    var h2 = parseInt(hslaMatch[1]);
    var s2 = parseInt(hslaMatch[2]);
    var l2 = parseInt(hslaMatch[3]);
    var a3 = parseFloat(hslaMatch[4]);
    if (
      h2 >= 0 && h2 <= 360 &&
      s2 >= 0 && s2 <= 100 &&
      l2 >= 0 && l2 <= 100 &&
      a3 >= 0 && a3 <= 1
    ) {
      return Qt.hsla(h2 / 360, s2 / 100, l2 / 100, a3);
    }
  }

  // CMYK: "c%, m%, y%, k%"
  var cmykMatch = str.match(
    /^\s*(\d+)%\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*[,\s]\s*(\d+)%\s*$/,
  );
  if (cmykMatch) {
    var c = parseInt(cmykMatch[1]) / 100;
    var m = parseInt(cmykMatch[2]) / 100;
    var y = parseInt(cmykMatch[3]) / 100;
    var k = parseInt(cmykMatch[4]) / 100;
    if (c >= 0 && c <= 1 && m >= 0 && m <= 1 && y >= 0 && y <= 1 && k >= 0 && k <= 1) {
      var rC = (1 - c) * (1 - k);
      var gC = (1 - m) * (1 - k);
      var bC = (1 - y) * (1 - k);
      return Qt.rgba(rC, gC, bC, 1);
    }
  }

  return undefined;
}

/**
 * Returns a color with the hue of color2 and the saturation, value, and alpha of color1.
 *
 * @param {string} color1 - The base color (any Qt.color-compatible string).
 * @param {string} color2 - The color to take hue from.
 * @returns {Qt.rgba} The resulting color.
 */
function colorWithHueOf(color1, color2) {
  var c1 = Qt.color(color1);
  var c2 = Qt.color(color2);
  // Qt.color hsvHue/hsvSaturation/hsvValue/alpha return 0-1
  var hue = c2.hsvHue;
  var sat = c1.hsvSaturation;
  var val = c1.hsvValue;
  var alpha = c1.a;
  return Qt.hsva(hue, sat, val, alpha);
}

/**
 * Returns a color with a saturation.
 *
 * @param {string} color1 - The base color (any Qt.color-compatible string).
 * @param {real} saturation - The color to take saturation from.
 * @returns {Qt.rgba} The resulting color.
 */
function colorWithSaturation(color1, saturation) {
  var c1 = Qt.color(color1);
  var hue = c1.hsvHue;
  var val = c1.hsvValue;
  var alpha = c1.a;
  return Qt.hsva(hue, saturation, val, alpha);
}

/**
 * Returns a color with the saturation of color2 and the hue/value/alpha of color1.
 *
 * @param {string} color1 - The base color (any Qt.color-compatible string).
 * @param {string} color2 - The color to take saturation from.
 * @returns {Qt.rgba} The resulting color.
 */
function colorWithSaturationOf(color1, color2) {
  var c1 = Qt.color(color1);
  var c2 = Qt.color(color2);
  var hue = c1.hsvHue;
  var sat = c2.hsvSaturation;
  var val = c1.hsvValue;
  var alpha = c1.a;
  return Qt.hsva(hue, sat, val, alpha);
}

/**
 * Returns a color with the given lightness and the hue, saturation, and alpha of the input color (using HSL).
 *
 * @param {string} color - The base color (any Qt.color-compatible string).
 * @param {number} lightness - The lightness value to use (0-1).
 * @returns {Qt.rgba} The resulting color.
 */
function colorWithLightness(color, lightness) {
  var c = Qt.color(color);
  return Qt.hsla(c.hslHue, c.hslSaturation, lightness, c.a);
}

/**
 * Returns a color with the lightness of color2 and the hue, saturation, and alpha of color1 (using HSL).
 *
 * @param {string} color1 - The base color (any Qt.color-compatible string).
 * @param {string} color2 - The color to take lightness from.
 * @returns {Qt.rgba} The resulting color.
 */
function colorWithLightnessOf(color1, color2) {
  var c2 = Qt.color(color2);
  return colorWithLightness(color1, c2.hslLightness);
}

/**
 * Adapts color1 to the accent (hue and saturation) of color2 using HSL, keeping lightness and alpha from color1.
 *
 * @param {string} color1 - The base color (any Qt.color-compatible string).
 * @param {string} color2 - The accent color.
 * @returns {Qt.rgba} The resulting color.
 */
function adaptToAccent(color1, color2) {
  var c1 = Qt.color(color1);
  var c2 = Qt.color(color2);
  var hue = c2.hslHue;
  var sat = c2.hslSaturation;
  var light = c1.hslLightness;
  var alpha = c1.a;
  return Qt.hsla(hue, sat, light, alpha);
}

/**
 * Mixes two colors by a given percentage.
 *
 * @param {string} color1 - The first color (any Qt.color-compatible string).
 * @param {string} color2 - The second color.
 * @param {number} percentage - The mix ratio (0-1). 1 = all color1, 0 = all color2.
 * @returns {Qt.rgba} The resulting mixed color.
 */
function mix(color1, color2, percentage = 0.5) {
  var c1 = Qt.color(color1);
  var c2 = Qt.color(color2);
  return Qt.rgba(
    percentage * c1.r + (1 - percentage) * c2.r,
    percentage * c1.g + (1 - percentage) * c2.g,
    percentage * c1.b + (1 - percentage) * c2.b,
    percentage * c1.a + (1 - percentage) * c2.a,
  );
}

/**
 * Transparentizes a color by a given percentage.
 *
 * @param {string} color - The color (any Qt.color-compatible string).
 * @param {number} percentage - The amount to transparentize (0-1).
 * @returns {Qt.rgba} The resulting color.
 */
function transparentize(color, percentage = 1) {
  var c = Qt.color(color);
  return Qt.rgba(c.r, c.g, c.b, c.a * percentage);
}

/**
 * Calculates the perceived brightness of a color using the relative luminance formula.
 * Uses the sRGB color space conversion as per WCAG guidelines.
 *
 * @param {string} color - The color (any Qt.color-compatible string).
 * @returns {number} The brightness value from 0 (darkest) to 1 (brightest).
 */
function getBrightness(color) {
  var c = Qt.color(color);

  // Convert RGB values to linear RGB
  var r = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4);
  var g = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4);
  var b = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4);

  // Calculate relative luminance
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

// ============================================================================
// TINTS GENERATION
// ============================================================================
// Helper: Convert hex color to RGB (0-1 range)
function hexToRgb(hex) {
  hex = hex.replace("#", "");
  return {
    r: parseInt(hex.substring(0, 2), 16) / 255,
    g: parseInt(hex.substring(2, 4), 16) / 255,
    b: parseInt(hex.substring(4, 6), 16) / 255,
  };
}

// Helper: Convert RGB to HLS
function rgbToHls(r, g, b) {
  var max = Math.max(r, g, b);
  var min = Math.min(r, g, b);
  var l = (max + min) / 2;

  var h = 0;
  var s = 0;

  if (max !== min) {
    var d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

    if (max === r) {
      h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
    } else if (max === g) {
      h = ((b - r) / d + 2) / 6;
    } else {
      h = ((r - g) / d + 4) / 6;
    }
  }

  return { h: h, l: l, s: s };
}

// Helper: HLS to RGB conversion helper
function hueToRgb(p, q, t) {
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}

// Helper: Convert HLS to RGB
function hlsToRgb(h, l, s) {
  var r, g, b;

  if (s === 0) {
    r = g = b = l;
  } else {
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    var p = 2 * l - q;
    r = hueToRgb(p, q, h + 1 / 3);
    g = hueToRgb(p, q, h);
    b = hueToRgb(p, q, h - 1 / 3);
  }

  return { r: r, g: g, b: b };
}

// Helper: Convert RGB to hex
function rgbToHex(r, g, b) {
  var toHex = function (val) {
    var clamped = Math.round(Math.max(0, Math.min(255, val * 255)));
    return clamped.toString(16).padStart(2, "0");
  };
  return "#" + toHex(r) + toHex(g) + toHex(b);
}

/**
 * Generates 16 tints from a color by varying lightness while keeping hue and saturation constant.
 *
 * @param {string} hexColor - The base color in hex format (e.g., "#3498db").
 * @param {number} minLightness - The minimum lightness value (0-1). Default: 0.08.
 * @param {number} maxLightness - The maximum lightness value (0-1). Default: 0.92.
 * @returns {Object} An object with keys "tint1" through "tint16" containing hex color strings.
 */
function generateTints(hexColor, minLightness, maxLightness) {
  minLightness = minLightness !== undefined ? minLightness : 0.08;
  maxLightness = maxLightness !== undefined ? maxLightness : 0.92;

  var STEPS = 16;
  var rgb = hexToRgb(hexColor);
  var hls = rgbToHls(rgb.r, rgb.g, rgb.b);

  var tints = {};

  for (var i = 0; i < STEPS; i++) {
    var l = minLightness + (i / (STEPS - 1)) * (maxLightness - minLightness);
    var newRgb = hlsToRgb(hls.h, l, hls.s);
    var hexColor = rgbToHex(newRgb.r, newRgb.g, newRgb.b);

    tints["color" + (i + 1)] = hexColor;
  }

  return tints;
}

/**
 * Converts a QML color object to a hexadecimal color string.
 *
 * @param {Object} qmlColor - A QML color object with r, g, b properties in 0-1 range.
 * @returns {string} A hex color string in format "#RRGGBB".
 */
function qmlColorToHex(qmlColor) {
  // Convert RGB values (0-1 range) to 0-255 range
  var r = Math.round(qmlColor.r * 255);
  var g = Math.round(qmlColor.g * 255);
  var b = Math.round(qmlColor.b * 255);

  // Convert to hex string
  return (
    "#" +
    ("0" + r.toString(16)).slice(-2) +
    ("0" + g.toString(16)).slice(-2) +
    ("0" + b.toString(16)).slice(-2)
  );
}

/**
 * Converts a color to a neon version by maximizing saturation and setting optimal lightness.
 *
 * @param {string} color - The base color (any Qt.color-compatible string).
 * @param {number} lightness - The lightness value (0-1). Default: 0.5 for vibrant neon.
 * @param {number} saturation - The saturation value (0-1). Default: 1.0 for maximum neon effect.
 * @returns {Qt.rgba} The resulting neon color.
 */
function makeNeon(color, lightness, saturation) {
  lightness = lightness !== undefined ? lightness : 0.5;
  saturation = saturation !== undefined ? saturation : 1.0;

  var c = Qt.color(color);
  return Qt.hsla(c.hslHue, saturation, lightness, c.a);
}
