import os
import json

paths = os.environ.get('PATH', '').split(':')
commands = set()
for path in paths:
    if os.path.isdir(path):
        try:
            for entry in os.scandir(path):
                if entry.is_file() and os.access(entry.path, os.X_OK):
                    commands.add(entry.name)
        except Exception:
            continue

print(json.dumps(sorted(list(commands))))
