#!/usr/bin/env python3

import cv2
import json
import sys
import numpy as np

# Configuration
CONFIG = {
    # Could not be changed
    "min_width": 50,
    "min_height": 50,
    "irregularity": 0.25,

    # Could be changed if necessary
    "size_similarity": 0.6,
    "containment_limit": 6,
    "overlap_limit": 1,
    "image_threshold": 0.99,
}


def find_rectangles(image_path):
    image = cv2.imread(image_path)
    if image is None:
        print(f"Error: Could not load image {image_path}", file=sys.stderr)
        sys.exit(1)

    orig_h, orig_w = image.shape[:2]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Multi-threshold edge detection
    edges = cv2.bitwise_or(cv2.Canny(gray, 30, 100), cv2.Canny(gray, 50, 150))

    # Dilate edges
    kernel = np.ones((3, 3), np.uint8)
    edges = cv2.dilate(edges, kernel, iterations=1)

    # Find and filter contours
    contours, _ = cv2.findContours(edges, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

    rectangles = []
    for contour in contours:
        x, y, w, h = cv2.boundingRect(contour)

        # Apply initial filters
        if (
            w < CONFIG["min_width"]
            or h < CONFIG["min_height"]
            or w >= orig_w * CONFIG["image_threshold"]
            and h >= orig_h * CONFIG["image_threshold"]
        ):
            continue

        aspect_ratio = w / h if h > 0 else 0
        if not (0.05 <= aspect_ratio <= 20):
            continue

        # Rectangularity check
        contour_area = cv2.contourArea(contour)
        if contour_area / (w * h) < CONFIG["irregularity"]:
            continue

        rectangles.append({"x": int(x), "y": int(y), "width": int(w), "height": int(h)})

    # Apply advanced filters
    rectangles = filter_overlapping(rectangles)
    rectangles = filter_similar_nested(rectangles)

    return sorted(rectangles, key=lambda r: r["width"] * r["height"], reverse=True)


def filter_overlapping(rectangles):
    """Remove rectangles with excessive containment/overlap"""
    rects = sorted(rectangles, key=lambda r: r["width"] * r["height"], reverse=True)

    for rect in rects:
        rect["_contains"], rect["_overlaps"] = 0, 0

    # Count containments and overlaps
    for _, rect in enumerate(rects):
        rect_area = rect["width"] * rect["height"]
        for other in rects:
            other_area = other["width"] * other["height"]
            if rect is other or other_area <= rect_area:
                continue

            if is_inside(rect, other):
                rect["_contains"] += 1
            elif overlap_ratio(rect, other) > 0.9:
                rect["_overlaps"] += 1

    # Filter and clean
    return [
        {k: v for k, v in r.items() if not k.startswith("_")}
        for r in rects
        if r["_contains"] < CONFIG["containment_limit"]
        and r["_overlaps"] < CONFIG["overlap_limit"]
    ]


def filter_similar_nested(rectangles):
    """Remove rectangles too similar in size to their direct container"""
    rects = sorted(rectangles, key=lambda r: r["width"] * r["height"], reverse=True)
    keep = []

    for i, rect in enumerate(rects):
        rect_area = rect["width"] * rect["height"]

        # Find smallest container
        container = min(
            (
                r
                for j, r in enumerate(rects)
                if i != j
                and r["width"] * r["height"] > rect_area
                and is_inside(rect, r)
            ),
            key=lambda r: r["width"] * r["height"],
            default=None,
        )

        # Check size similarity
        if (
            container is None
            or rect_area / (container["width"] * container["height"])
            < CONFIG["size_similarity"]
        ):
            keep.append(rect)

    return keep


def is_inside(inner, outer):
    """Check if inner is contained within outer"""
    return (
        inner["x"] >= outer["x"]
        and inner["y"] >= outer["y"]
        and inner["x"] + inner["width"] <= outer["x"] + outer["width"]
        and inner["y"] + inner["height"] <= outer["y"] + outer["height"]
    )


def overlap_ratio(rect1, rect2):
    """Calculate overlap ratio of rect1 with rect2"""
    x1, y1 = max(rect1["x"], rect2["x"]), max(rect1["y"], rect2["y"])
    x2 = min(rect1["x"] + rect1["width"], rect2["x"] + rect2["width"])
    y2 = min(rect1["y"] + rect1["height"], rect2["y"] + rect2["height"])

    intersection = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = rect1["width"] * rect1["height"]
    return intersection / area1 if area1 > 0 else 0


def main():
    if len(sys.argv) != 2:
        print("Usage: script.py /path/to/image", file=sys.stderr)
        sys.exit(1)

    print(json.dumps(find_rectangles(sys.argv[1])))


if __name__ == "__main__":
    main()
