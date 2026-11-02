#!/usr/bin/env python3
import os
import json
import shutil


def get_users():
    users = []
    try:
        with open("/etc/passwd", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) >= 7:
                    uid = int(parts[2])
                    if 1000 <= uid < 65534:
                        users.append({"name": parts[0], "uid": uid})
    except Exception:
        pass
    return sorted(users, key=lambda x: x["name"])


def try_exec_available(command):
    """Check if the TryExec command is available on PATH or as an absolute path."""
    if os.path.isabs(command):
        return os.path.isfile(command) and os.access(command, os.X_OK)
    return shutil.which(command) is not None


def get_sessions():
    sessions = []
    paths = ["/usr/share/wayland-sessions", "/usr/share/xsessions"]
    for path in paths:
        if not os.path.exists(path):
            continue
        for filename in os.listdir(path):
            if filename.endswith(".desktop"):
                filepath = os.path.join(path, filename)
                try:
                    with open(filepath, "r") as f:
                        name = ""
                        exec_cmd = ""
                        try_exec = ""
                        desktop_names = ""
                        for line in f:
                            if line.startswith("Name="):
                                name = line.split("=", 1)[1].strip()
                            elif line.startswith("Exec="):
                                exec_cmd = line.split("=", 1)[1].strip()
                            elif line.startswith("TryExec="):
                                try_exec = line.split("=", 1)[1].strip()
                            elif line.startswith("DesktopNames="):
                                desktop_names = line.split("=", 1)[1].strip()
                        if name and exec_cmd:
                            if try_exec and not try_exec_available(try_exec):
                                continue
                            sessions.append(
                                {
                                    "name": name,
                                    "exec": exec_cmd,
                                    "type": "wayland" if "wayland" in path else "x11",
                                    "sessionDesktop": filename[: -len(".desktop")],
                                    "desktopNames": [
                                        d.strip()
                                        for d in desktop_names.split(";")
                                        if d.strip()
                                    ],
                                }
                            )
                except Exception:
                    pass
    return sorted(sessions, key=lambda x: x["name"])


def main():
    data = {"users": get_users(), "sessions": get_sessions()}
    print(json.dumps(data))


if __name__ == "__main__":
    main()
