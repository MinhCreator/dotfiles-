#!/usr/bin/env python3
"""
Determines the best position (x, y = top-left corner) to place a
rectangular widget on a wallpaper, by combining:
  - a visual saliency map (eye-catching zones -> to avoid)
  - local texture/variance (flat zones -> preferred, better readability)
  - a composition bonus based on the rule of thirds (aesthetics)
  - a safety margin to stay away from screen edges

Also computes the average perceived brightness of the chosen zone and
derives a recommended text color (light/dark) for good contrast.

Usage:
    python3 widget_placement.py /path/to/wallpaper.jpg
    python3 widget_placement.py /path/to/wallpaper.jpg --screen-width 2560 --screen-height 1440
    python3 widget_placement.py /path/to/wallpaper.jpg --widget-width 400 --widget-height 150

Output: JSON on stdout, e.g.:
    {"x": 1490, "y": 60, "brightness": 187.3, "textColor": "dark"}
"""

import sys
import json
import argparse
import hashlib
import os
from pathlib import Path

CACHE_DIR = str(
    Path.home() / ".config" / "quickshell" / "scripts" / "cache" / "desktop_widget_fetcher"
)

# ---- Default config ---------------------------------------------------------

DEFAULT_SCREEN_W, DEFAULT_SCREEN_H = 1920, 1080
DEFAULT_WIDGET_W, DEFAULT_WIDGET_H = 350, 120

STRIDE = 10  # sliding window step (px) -- smaller = more precise but slower

# Safety margins (keeps the widget away from screen edges)
MARGIN_TOP = 60
MARGIN_BOTTOM = 60
MARGIN_LEFT = 60
MARGIN_RIGHT = 60

# Brightness threshold (0-255) to decide light/dark text
BRIGHTNESS_THRESHOLD = 140

# Score weights (tune by eye if needed)
W_SALIENCY = 2  # penalizes visually busy zones
W_BRIGHTNESS = 0.0  # penalizes bright zones (tune by eye)
W_TEXTURE = 3  # penalizes zones with strong local contrast (unreadable text)
W_THIRDS = 0.25  # bonus for being close to a rule-of-thirds intersection

# ---- Functions ----------------------------------------------------------------


def compute_saliency(img):
    """Returns a normalized [0,1] saliency map, same size as img (grayscale)."""
    saliency = cv2.saliency.StaticSaliencySpectralResidual_create()
    success, sal_map = saliency.computeSaliency(img)
    if not success:
        raise RuntimeError("Saliency computation failed")
    sal_map = (sal_map - sal_map.min()) / (sal_map.max() - sal_map.min() + 1e-9)
    return sal_map.astype(np.float32)


def compute_texture(img_gray):
    """Returns a normalized [0,1] local variance map (Sobel gradient magnitude)."""
    sobelx = cv2.Sobel(img_gray, cv2.CV_32F, 1, 0, ksize=3)
    sobely = cv2.Sobel(img_gray, cv2.CV_32F, 0, 1, ksize=3)
    grad_mag = cv2.magnitude(sobelx, sobely)
    grad_mag = (grad_mag - grad_mag.min()) / (grad_mag.max() - grad_mag.min() + 1e-9)
    return grad_mag.astype(np.float32)


def compute_brightness_map(img_gray):
    """Returns a normalized [0,1] brightness map."""
    bright = img_gray.astype(np.float32)
    bright = (bright - bright.min()) / (bright.max() - bright.min() + 1e-9)
    return bright


def load_thirds_map(w, h):
    """Rule-of-thirds bonus map, memoized per screen size (depends only
    on dimensions, never on the image). Identical bytes on every load."""
    path = os.path.join(CACHE_DIR, f"thirds-{w}x{h}.npy")
    try:
        m = np.load(path)
        if m.shape == (h, w):
            return m.astype(np.float32, copy=False)
    except (OSError, ValueError):
        pass
    os.makedirs(CACHE_DIR, exist_ok=True)
    m = thirds_bonus_map(w, h)
    try:
        np.save(path, m)
    except OSError:
        pass
    return m


def thirds_bonus_map(w, h):
    """
    Rule-of-thirds bonus map: the closer a position is to one of the 4
    intersections (1/3, 2/3), the higher the bonus.
    Returns a [0,1] map, 1 = exactly on an intersection.
    """
    xs = np.arange(w)
    ys = np.arange(h)
    xv, yv = np.meshgrid(xs, ys)

    thirds_x = [w / 3, 2 * w / 3]
    thirds_y = [h / 3, 2 * h / 3]

    max_dist = np.sqrt((w / 3) ** 2 + (h / 3) ** 2)

    best = np.zeros((h, w), dtype=np.float32)
    for tx in thirds_x:
        for ty in thirds_y:
            dist = np.sqrt((xv - tx) ** 2 + (yv - ty) ** 2)
            score = 1.0 - np.clip(dist / max_dist, 0, 1)
            best = np.maximum(best, score)
    return best


def find_best_position(image_path, screen_w, screen_h, widget_w, widget_h):
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    # Resize to the target resolution if needed, so returned coordinates
    # match the requested screen size
    if img.shape[1] != screen_w or img.shape[0] != screen_h:
        img = cv2.resize(img, (screen_w, screen_h), interpolation=cv2.INTER_AREA)

    img_gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    saliency_map = compute_saliency(img)
    texture_map = compute_texture(img_gray)
    thirds_map = load_thirds_map(screen_w, screen_h)
    brightness_map = compute_brightness_map(img_gray)

    # Integral images for fast window sums (O(1) per zone)
    sal_integral = cv2.integral(saliency_map)
    tex_integral = cv2.integral(texture_map)
    thirds_integral = cv2.integral(thirds_map)
    bright_integral = cv2.integral(brightness_map)

    x_min = MARGIN_LEFT
    x_max = screen_w - MARGIN_RIGHT - widget_w
    y_min = MARGIN_TOP
    y_max = screen_h - MARGIN_BOTTOM - widget_h

    if x_max < x_min or y_max < y_min:
        raise ValueError(
            "Widget size is too large for the given screen size and margins"
        )

    # Candidate top-left corners, same y-outer/x-inner order as the old
    # loop so ties break identically (strictly-less = first wins).
    xs = np.arange(x_min, x_max + 1, STRIDE)
    ys = np.arange(y_min, y_max + 1, STRIDE)
    xx, yy = np.meshgrid(xs, ys)
    fx = xx.ravel()
    fy = yy.ravel()

    def window_sums(integral):
        return (
            integral[fy + widget_h, fx + widget_w]
            - integral[fy, fx + widget_w]
            - integral[fy + widget_h, fx]
            + integral[fy, fx]
        )

    area = widget_w * widget_h
    # Same per-window arithmetic as the old loop, term for term, over
    # the same y-outer/x-inner order: identical scores, identical ties.
    sal_avg = window_sums(sal_integral) / area
    tex_avg = window_sums(tex_integral) / area
    thirds_avg = window_sums(thirds_integral) / area
    bright_avg = window_sums(bright_integral) / area
    scores = (
        W_SALIENCY * sal_avg
        + W_TEXTURE * tex_avg
        + W_BRIGHTNESS * bright_avg
        - W_THIRDS * thirds_avg
    )

    best = int(np.argmin(scores))
    best_pos = (int(fx[best]), int(fy[best]))
    return best_pos, img


def compute_brightness(img, x, y, widget_w, widget_h):
    """
    Computes the average perceived luminance (0-255) of the widget zone,
    and derives a recommended text color ("light" or "dark").
    img is in BGR format (OpenCV default).
    """
    zone = img[y : y + widget_h, x : x + widget_w]
    b = zone[:, :, 0].astype(np.float32)
    g = zone[:, :, 1].astype(np.float32)
    r = zone[:, :, 2].astype(np.float32)

    luminance = 0.299 * r + 0.587 * g + 0.114 * b
    brightness = float(np.mean(luminance))

    text_color = "dark" if brightness > BRIGHTNESS_THRESHOLD else "light"
    return brightness, text_color


def parse_args():
    parser = argparse.ArgumentParser(
        description="Find the best position for a widget on a wallpaper."
    )
    parser.add_argument("image_path", help="Path to the wallpaper image")
    parser.add_argument(
        "--screen-width",
        type=int,
        default=DEFAULT_SCREEN_W,
        help=f"Screen width in px (default: {DEFAULT_SCREEN_W})",
    )
    parser.add_argument(
        "--screen-height",
        type=int,
        default=DEFAULT_SCREEN_H,
        help=f"Screen height in px (default: {DEFAULT_SCREEN_H})",
    )
    parser.add_argument(
        "--widget-width",
        type=int,
        default=DEFAULT_WIDGET_W,
        help=f"Widget width in px (default: {DEFAULT_WIDGET_W})",
    )
    parser.add_argument(
        "--widget-height",
        type=int,
        default=DEFAULT_WIDGET_H,
        help=f"Widget height in px (default: {DEFAULT_WIDGET_H})",
    )
    parser.add_argument(
        "--content-hash",
        default="",
        help="Precomputed sha256 of the image (skips rehashing for cache lookup)",
    )
    return parser.parse_args()


def cache_key(content_hash, screen_w, screen_h, widget_w, widget_h):
    return (
        f"v2-{content_hash[:16]}-{screen_w}x{screen_h}-{widget_w}x{widget_h}.json"
    )


def file_hash(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    args = parse_args()

    content_hash = args.content_hash or file_hash(args.image_path)
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_path = os.path.join(
        CACHE_DIR,
        cache_key(
            content_hash,
            args.screen_width,
            args.screen_height,
            args.widget_width,
            args.widget_height,
        ),
    )
    try:
        with open(cache_path) as f:
            print(f.read())
        return
    except (OSError, ValueError):
        pass

    global cv2, np
    import cv2
    import numpy as np

    try:
        (x, y), img = find_best_position(
            args.image_path,
            args.screen_width,
            args.screen_height,
            args.widget_width,
            args.widget_height,
        )
        brightness, text_color = compute_brightness(
            img, x, y, args.widget_width, args.widget_height
        )
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

    result = json.dumps(
        {
            "x": x,
            "y": y,
            "brightness": round(brightness, 1),
            "textColor": text_color,
        }
    )
    print(result, flush=True)
    try:
        with open(cache_path, "w") as f:
            f.write(result)
    except OSError:
        pass


if __name__ == "__main__":
    main()
