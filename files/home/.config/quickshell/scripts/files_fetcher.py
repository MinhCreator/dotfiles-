#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import urllib.parse


def format_size(size_bytes):
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1048576:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1073741824:
        return f"{size_bytes / 1048576:.1f} MB"
    else:
        return f"{size_bytes / 1073741824:.1f} GB"


def get_zoxide_scores():
    scores = {}
    try:
        res = subprocess.run(["zoxide", "query", "-ls"], capture_output=True, text=True)
        for line in res.stdout.splitlines():
            parts = line.strip().split(None, 1)
            if len(parts) == 2:
                try:
                    score = float(parts[0])
                    path = parts[1]
                    scores[path + "_score"] = score
                except:
                    continue
    except:
        pass
    return scores


def resolve_path_query(query):
    """Return (directory, name_prefix) if the query is a path, else None."""
    if query == "~" or query.startswith("~/"):
        query = os.path.expanduser(query)
    if not query.startswith("/"):
        return None

    if query.endswith("/") or query == os.path.expanduser("~"):
        base_dir, prefix = query.rstrip("/") or "/", ""
    else:
        base_dir, prefix = os.path.split(query)
        base_dir = base_dir or "/"

    if not os.path.isdir(base_dir):
        return None
    return base_dir, prefix


def get_metadata(paths, z_scores):
    if not paths:
        return []

    unique_paths = list(dict.fromkeys(paths))
    valid_paths = [p for p in unique_paths if os.path.exists(p)]
    if not valid_paths:
        return []

    try:
        cmd = [
            "gio",
            "info",
            "-a",
            "standard::display-name,standard::icon,standard::content-type,standard::size",
        ] + valid_paths
        process = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        stdout, _ = process.communicate()

        results = []
        current_item = None

        for line in stdout.splitlines():
            clean_line = line.strip()
            if line.startswith("display name:"):
                if current_item and "path" in current_item:
                    results.append(current_item)
                current_item = {"name": line.split(":", 1)[1].strip()}
            elif line.startswith("uri:") and current_item is not None:
                uri = line.split(":", 1)[1].strip()

                local_path = uri
                if local_path.startswith("file://"):
                    local_path = urllib.parse.unquote(local_path[7:])

                current_item["path"] = local_path
                current_item["zoxide_score"] = z_scores.get(local_path + "_score", 0.0)

            elif "standard::icon:" in clean_line and current_item is not None:
                icons = clean_line.split("standard::icon:", 1)[1].strip()
                current_item["icon"] = icons.split(",")[0].strip()
            elif "standard::content-type:" in clean_line and current_item is not None:
                current_item["mime"] = clean_line.split("standard::content-type:", 1)[
                    1
                ].strip()
            elif "standard::size:" in clean_line and current_item is not None:
                try:
                    size = int(clean_line.split("standard::size:", 1)[1].strip())
                    current_item["size_bytes"] = size
                    current_item["size"] = format_size(size)
                except:
                    current_item["size"] = "0 B"

        if current_item and "path" in current_item:
            results.append(current_item)

        for item in results:
            item["is_dir"] = item.get("mime") == "inode/directory"

        return results
    except Exception as _:
        return []


def get_file_details(path):
    local_path = path
    if local_path.startswith("file://"):
        local_path = urllib.parse.unquote(local_path[7:])

    if not os.path.exists(local_path):
        return {"error": f"File not found: {local_path}"}

    try:
        metadata_list = get_metadata([local_path], {})
        if not metadata_list:
            return {"error": "Could not get metadata"}
        metadata = metadata_list[0]
        readable = False
        preview = ""
        mime = metadata.get("mime", "")

        if not metadata["is_dir"]:
            readable_mimes = [
                "application/json",
                "application/xml",
                "application/javascript",
                "application/x-shellscript",
                "application/x-sh",
                "application/x-yaml",
                "application/toml",
                "application/x-ruby",
                "application/x-python",
                "application/x-perl",
            ]
            if mime.startswith("text/") or mime in readable_mimes:
                readable = True
                try:
                    with open(local_path, "r", errors="ignore") as f:
                        preview = f.read(8192)
                except:
                    pass

        metadata["readable"] = readable
        metadata["preview"] = preview

        if readable:
            metadata["lines"] = preview.count("\n") + 1
            metadata["chars"] = len(preview)

        if metadata["is_dir"]:
            try:
                metadata["file_count"] = len(os.listdir(local_path))
            except:
                metadata["file_count"] = 0

        return metadata
    except Exception as e:
        return {"error": str(e)}


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "--details" and len(sys.argv) > 2:
            print(json.dumps(get_file_details(sys.argv[2])))
            return
        if sys.argv[1] == "--zoxide":
            z_scores = get_zoxide_scores()
            paths = [k[:-6] for k in z_scores.keys() if k.endswith("_score")]
            paths = sorted(paths, key=lambda x: z_scores[x + "_score"], reverse=True)[
                :100
            ]
            print(json.dumps(get_metadata(paths, z_scores)))
            return

    query = sys.argv[1] if len(sys.argv) > 1 else ""
    home = os.path.expanduser("~")

    z_scores = get_zoxide_scores()
    paths = []

    try:
        path_query = resolve_path_query(query)
        if path_query:
            base_dir, prefix = path_query
            cmd = [
                "fd",
                "--type",
                "f",
                "--type",
                "d",
                "--max-depth",
                "1",
                "--no-ignore",
                "--fixed-strings",
                "--ignore-case",
                "--max-results",
                "300",
                "--exclude",
                ".git",
            ]
            if prefix.startswith("."):
                cmd.append("--hidden")
            if prefix:
                cmd.append(prefix)
            else:
                cmd.append("")  # empty pattern: match everything
            cmd += ["--search-path", base_dir]
        else:
            cmd = [
                "fd",
                "--full-path",
                "--type",
                "f",
                "--type",
                "d",
                "--max-results",
                "300",
                "--exclude",
                ".git",
                "--exclude",
                "node_modules",
                "--exclude",
                ".local/share/Trash",
                query,
                home,
            ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        paths = [p.rstrip("/") or "/" for p in res.stdout.splitlines()]

        if not path_query:
            z_paths_set = {k[:-6] for k in z_scores.keys() if k.endswith("_score")}
            paths = [p for p in paths if p not in z_paths_set]
    except:
        pass

    metadata = [
        m for m in get_metadata(paths, z_scores) if "%" not in m.get("path", "")
    ]
    print(json.dumps(metadata))


if __name__ == "__main__":
    main()
