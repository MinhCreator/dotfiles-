#!/usr/bin/env python3
import os
import sys
import json
import time
import threading
import requests
import re
import argparse
import concurrent.futures
import subprocess
from pathlib import Path

CACHE_ROOT = Path.home() / ".cache" / "bnsplit"
TEMP_ROOT = Path("/tmp/bnsplit")
WALLPAPER_DIR = Path.home() / "Pictures" / "Wallpapers"

WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)

_print_lock = threading.Lock()


def emit(line):
    with _print_lock:
        print(line, flush=True)


# ---------------------------------------------------------------------------
# Shared helpers (provider-agnostic): caching, thumbnails, save/download,
# wallpaper numbering. Every provider funnels its results through these.
# ---------------------------------------------------------------------------


def thumbs_dir_for(provider):
    d = CACHE_ROOT / f"{provider}-thumbnails"
    d.mkdir(parents=True, exist_ok=True)
    return d


def temp_dir_for(provider):
    d = TEMP_ROOT / provider
    d.mkdir(parents=True, exist_ok=True)
    return d


def thumb_path_for(provider, item_id, url):
    url_path = url.split("?")[0]
    ext = os.path.splitext(url_path)[1]
    if not ext:
        ext = ".jpg"  # Fallback
    return thumbs_dir_for(provider) / (item_id + ext)


def download_thumb(url, dest_path):
    """Download a thumbnail to dest_path atomically. Returns True on success."""
    if dest_path.exists() and dest_path.stat().st_size > 0:
        return True

    part_path = dest_path.with_suffix(dest_path.suffix + ".part")
    for attempt in range(3):
        try:
            r = requests.get(url, timeout=(5, 20))
            if r.status_code == 200 and r.content:
                with open(part_path, "wb") as f:
                    f.write(r.content)
                part_path.replace(dest_path)
                return True
        except Exception:
            pass
        finally:
            if part_path.exists():
                try:
                    part_path.unlink()
                except OSError:
                    pass
        if attempt < 2:
            time.sleep(0.5 * (2**attempt))
    return False


def download_thumbs_streaming(tasks):
    """Download (url, path, id) tasks concurrently, emitting one THUMB line per result."""

    def worker(task):
        thumb_url, thumb_path, item_id = task
        try:
            if download_thumb(thumb_url, thumb_path):
                emit(f"THUMB {item_id} ok {thumb_path}")
            else:
                emit(f"THUMB {item_id} fail")
        except Exception:
            # Guarantee exactly one THUMB line per task so no cell strands in "loading"
            emit(f"THUMB {item_id} fail")

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        list(executor.map(worker, tasks))


def get_next_wallpaper_name(extension, hidden=False):
    if not WALLPAPER_DIR.exists():
        WALLPAPER_DIR.mkdir(parents=True, exist_ok=True)

    max_num = 0
    pattern = re.compile(r"^\.(\d+)\." if hidden else r"^(\d+)\.")

    for f in WALLPAPER_DIR.iterdir():
        if f.is_file():
            match = pattern.match(f.name)
            if match:
                num = int(match.group(1))
                if num > max_num:
                    max_num = num

    next_num = max_num + 1
    # Padding: pad to 3 digits when below 100 (e.g. 007.png), otherwise just the number.
    name = f"{next_num:03d}{extension}"
    return f".{name}" if hidden else name


def detect_extension(path):
    """Return an image extension for numbering from the file content (the file may have no suffix)."""
    try:
        mime = subprocess.run(
            ["file", "--mime-type", "-b", str(path)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except Exception:
        mime = ""

    ext_by_mime = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/gif": ".gif",
        "image/bmp": ".bmp",
        "image/svg+xml": ".svg",
    }
    if mime in ext_by_mime:
        return ext_by_mime[mime]

    suffix = os.path.splitext(str(path))[1]
    return suffix if suffix else ".png"


def save_wallpaper(source_path, hidden=False):
    """Copy a local image into the wallpaper collection with the next number as its name."""
    source = Path(source_path)
    if not source.is_file():
        print(f"Source file not found: {source}", file=sys.stderr)
        sys.exit(1)

    import shutil

    name = get_next_wallpaper_name(detect_extension(source), hidden)
    dest = WALLPAPER_DIR / name
    shutil.copy2(source, dest)
    print(str(dest))


def download_wallpaper(url, dest_path):
    if dest_path.exists() and dest_path.stat().st_size > 0:
        return True

    try:
        r = requests.get(url, timeout=30, stream=True)
        r.raise_for_status()
        total = int(r.headers.get("Content-Length", 0) or 0)
        downloaded = 0
        last_reported = -1.0
        with open(dest_path, "wb") as f:
            for chunk in r.iter_content(chunk_size=8192):
                f.write(chunk)
                if total > 0:
                    downloaded += len(chunk)
                    fraction = min(1.0, downloaded / total)
                    if fraction - last_reported >= 0.01 or fraction >= 1.0:
                        last_reported = fraction
                        print(f"PROGRESS {fraction:.4f}", flush=True)
        return True
    except Exception as e:
        if dest_path.exists():
            dest_path.unlink()
        print(f"Error downloading {url}: {e}", file=sys.stderr)
        return False


def generic_download_command(provider, args):
    """Shared implementation for `<provider> download --url --id [--save]`."""
    ext = os.path.splitext(args.url.split("?")[0])[1]
    if not ext:
        ext = ".jpg"
    tmp_path = temp_dir_for(provider) / (args.id + ext)

    if args.save:
        name = get_next_wallpaper_name(ext)
        dest = WALLPAPER_DIR / name
        if tmp_path.exists() and tmp_path.stat().st_size > 0:
            import shutil

            shutil.copy2(tmp_path, dest)
            print(str(dest))
        elif download_wallpaper(args.url, dest):
            print(str(dest))
        else:
            sys.exit(1)
    else:
        if download_wallpaper(args.url, tmp_path):
            print(str(tmp_path))
        else:
            sys.exit(1)


# ---------------------------------------------------------------------------
# Wallhaven provider
# ---------------------------------------------------------------------------

WALLHAVEN_API_URL = "https://wallhaven.cc/api/v1/search"


def wallhaven_resolve_thumbs(data):
    """Resolve local thumb paths and build the download task list."""
    tasks = []
    for wp in data.get("data", []):
        thumb_url = (
            wp.get("thumbs", {}).get("original")
            or wp.get("thumbs", {}).get("large")
            or wp.get("thumbs", {}).get("small")
        )
        if thumb_url:
            thumb_path = thumb_path_for("wallhaven", wp["id"], thumb_url)
            wp["local_thumb"] = str(thumb_path)
            wp["thumb_url"] = thumb_url
            tasks.append((thumb_url, thumb_path, wp["id"]))
        else:
            wp["local_thumb"] = ""
            wp["thumb_url"] = ""
    return tasks


def wallhaven_fetch(args):
    params = {
        "q": args.query,
        "categories": args.categories,
        "purity": args.purity,
        "sorting": args.sorting,
        "order": args.order,
        "toprange": args.toprange,
        "atleast": args.atleast,
        "ratios": args.ratios,
        "page": args.page,
        "apikey": args.apikey,
    }
    params = {k: v for k, v in params.items() if v}

    try:
        response = requests.get(WALLHAVEN_API_URL, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
    except Exception as e:
        emit("META " + json.dumps({"error": str(e)}))
        return

    # Metadata first so the grid can render immediately
    tasks = wallhaven_resolve_thumbs(data)
    emit("META " + json.dumps(data))

    # Then stream thumbnails as they complete
    download_thumbs_streaming(tasks)


def wallhaven_thumbs(args):
    try:
        items = json.loads(args.items)
    except Exception:
        return
    tasks = []
    for item in items:
        wp_id = item.get("id", "")
        thumb_url = item.get("url", "")
        if wp_id and thumb_url:
            tasks.append(
                (thumb_url, thumb_path_for("wallhaven", wp_id, thumb_url), wp_id)
            )
    download_thumbs_streaming(tasks)


def wallhaven_add_subparsers(sub):
    fetch_parser = sub.add_parser("fetch")
    fetch_parser.add_argument("--query", default="")
    fetch_parser.add_argument("--categories", default="111")
    fetch_parser.add_argument("--purity", default="100")
    fetch_parser.add_argument("--sorting", default="date_added")
    fetch_parser.add_argument("--order", default="desc")
    fetch_parser.add_argument("--toprange", default="1M")
    fetch_parser.add_argument("--atleast", default="")
    fetch_parser.add_argument("--ratios", default="")
    fetch_parser.add_argument("--page", type=int, default=1)
    fetch_parser.add_argument("--apikey", default="")
    fetch_parser.set_defaults(func=wallhaven_fetch)

    thumbs_parser = sub.add_parser("thumbs")
    thumbs_parser.add_argument("--items", required=True)
    thumbs_parser.set_defaults(func=wallhaven_thumbs)

    download_parser = sub.add_parser("download")
    download_parser.add_argument("--url", required=True)
    download_parser.add_argument("--id", required=True)
    download_parser.add_argument("--save", action="store_true")
    download_parser.set_defaults(
        func=lambda args: generic_download_command("wallhaven", args)
    )


# ---------------------------------------------------------------------------
# Unsplash provider
# ---------------------------------------------------------------------------

UNSPLASH_API_URL = "https://api.unsplash.com"
UNSPLASH_CONTENT_FILTER = "low"  # forced, per spec: never exposed as a flag


def unsplash_headers(apikey):
    return {
        "Authorization": f"Client-ID {apikey}",
        "Accept-Version": "v1",
    }


def unsplash_resolve_thumbs(photos):
    """photos: a list of Unsplash photo objects. Mutates them with local_thumb/thumb_url
    and returns the download task list, mirroring wallhaven_resolve_thumbs."""
    tasks = []
    for photo in photos:
        urls = photo.get("urls", {}) or {}
        thumb_url = urls.get("thumb") or urls.get("small")
        photo_id = photo.get("id", "")
        if thumb_url and photo_id:
            thumb_path = thumb_path_for("unsplash", photo_id, thumb_url)
            photo["local_thumb"] = str(thumb_path)
            photo["thumb_url"] = thumb_url
            tasks.append((thumb_url, thumb_path, photo_id))
        else:
            photo["local_thumb"] = ""
            photo["thumb_url"] = ""
    return tasks


def unsplash_request(path, params, apikey):
    params = {k: v for k, v in params.items() if v not in (None, "")}
    response = requests.get(
        f"{UNSPLASH_API_URL}{path}",
        params=params,
        headers=unsplash_headers(apikey),
        timeout=10,
    )
    response.raise_for_status()
    return response.json()


def unsplash_topics(args):
    try:
        data = unsplash_request(
            "/topics",
            {
                "page": args.page,
                "per_page": args.per_page,
                "order_by": args.order_by,
            },
            args.apikey,
        )
    except Exception as e:
        emit("META " + json.dumps({"error": str(e)}))
        return

    emit("META " + json.dumps({"data": data}))


def unsplash_topic_photos(args):
    try:
        photos = unsplash_request(
            f"/topics/{args.topic}/photos",
            {
                "page": args.page,
                "per_page": args.per_page,
                "order_by": args.order_by,
                "orientation": args.orientation,
            },
            args.apikey,
        )
    except Exception as e:
        emit("META " + json.dumps({"error": str(e)}))
        return

    tasks = unsplash_resolve_thumbs(photos)
    emit("META " + json.dumps({"data": photos}))
    download_thumbs_streaming(tasks)


def unsplash_fetch(args):
    """Search photos: the unsplash equivalent of wallhaven's `fetch`."""
    try:
        data = unsplash_request(
            "/search/photos",
            {
                "query": args.query,
                "page": args.page,
                "per_page": args.per_page,
                "order_by": args.order_by,
                "color": args.color,
                "orientation": args.orientation,
                "content_filter": UNSPLASH_CONTENT_FILTER,
            },
            args.apikey,
        )
    except Exception as e:
        emit("META " + json.dumps({"error": str(e)}))
        return

    photos = data.get("results", [])
    tasks = unsplash_resolve_thumbs(photos)
    emit("META " + json.dumps(data))
    download_thumbs_streaming(tasks)


def unsplash_thumbs(args):
    try:
        items = json.loads(args.items)
    except Exception:
        return
    tasks = []
    for item in items:
        item_id = item.get("id", "")
        thumb_url = item.get("url", "")
        if item_id and thumb_url:
            tasks.append(
                (thumb_url, thumb_path_for("unsplash", item_id, thumb_url), item_id)
            )
    download_thumbs_streaming(tasks)


def unsplash_add_subparsers(sub):
    topics_parser = sub.add_parser("topics")
    topics_parser.add_argument("--page", type=int, default=1)
    topics_parser.add_argument("--per_page", type=int, default=10)
    topics_parser.add_argument(
        "--order_by",
        default="position",
        choices=["featured", "latest", "oldest", "position"],
    )
    topics_parser.add_argument("--apikey", default="")
    topics_parser.set_defaults(func=unsplash_topics)

    topic_photos_parser = sub.add_parser("topic-photos")
    topic_photos_parser.add_argument("--topic", required=True, help="Topic id or slug")
    topic_photos_parser.add_argument("--page", type=int, default=1)
    topic_photos_parser.add_argument("--per_page", type=int, default=10)
    topic_photos_parser.add_argument(
        "--order_by", default="latest", choices=["latest", "oldest", "popular"]
    )
    topic_photos_parser.add_argument(
        "--orientation",
        default="landscape",
        choices=["landscape", "portrait", "squarish"],
    )
    topic_photos_parser.add_argument("--apikey", default="")
    topic_photos_parser.set_defaults(func=unsplash_topic_photos)

    fetch_parser = sub.add_parser("fetch")
    fetch_parser.add_argument("--query", required=True)
    fetch_parser.add_argument("--page", type=int, default=1)
    fetch_parser.add_argument("--per_page", type=int, default=10)
    fetch_parser.add_argument(
        "--order_by", default="relevant", choices=["relevant", "latest"]
    )
    fetch_parser.add_argument(
        "--color",
        default="",
        choices=[
            "",
            "black_and_white",
            "black",
            "white",
            "yellow",
            "orange",
            "red",
            "purple",
            "magenta",
            "green",
            "teal",
            "blue",
        ],
    )
    fetch_parser.add_argument(
        "--orientation",
        default="landscape",
        choices=["landscape", "portrait", "squarish"],
    )
    fetch_parser.add_argument("--apikey", default="")
    fetch_parser.set_defaults(func=unsplash_fetch)

    thumbs_parser = sub.add_parser("thumbs")
    thumbs_parser.add_argument("--items", required=True)
    thumbs_parser.set_defaults(func=unsplash_thumbs)

    download_parser = sub.add_parser("download")
    download_parser.add_argument("--url", required=True)
    download_parser.add_argument("--id", required=True)
    download_parser.add_argument("--save", action="store_true")
    download_parser.set_defaults(
        func=lambda args: generic_download_command("unsplash", args)
    )


# ---------------------------------------------------------------------------
# Top-level CLI: script.py <provider> <command> --args
# (+ top-level `save --source` shared by all providers)
# ---------------------------------------------------------------------------

PROVIDERS = {
    "wallhaven": wallhaven_add_subparsers,
    "unsplash": unsplash_add_subparsers,
}


def main():
    parser = argparse.ArgumentParser()
    provider_sub = parser.add_subparsers(dest="provider")

    for name, add_subparsers in PROVIDERS.items():
        provider_parser = provider_sub.add_parser(name)
        command_sub = provider_parser.add_subparsers(dest="command")
        add_subparsers(command_sub)

    save_parser = provider_sub.add_parser("save", help="Copy a local image into the wallpaper collection")
    save_parser.add_argument("--source", required=True)
    save_parser.add_argument("--hidden", action="store_true")
    save_parser.set_defaults(func=lambda args: save_wallpaper(args.source, args.hidden))

    args = parser.parse_args()

    if not args.provider:
        parser.print_help()
        return

    if args.provider == "save":
        if not hasattr(args, "func"):
            parser.print_help()
            return
        args.func(args)
        return

    if not getattr(args, "command", None):
        parser.parse_args([args.provider, "--help"])
        return

    if not hasattr(args, "func"):
        parser.print_help()
        return

    args.func(args)


if __name__ == "__main__":
    main()
