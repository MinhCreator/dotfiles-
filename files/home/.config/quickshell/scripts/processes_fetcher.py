#!/usr/bin/env python3
"""
Continuously streams a JSON array of process info to stdout, once per second,
using the same accounting approach btop uses:

  - CPU% is computed from the delta of process CPU time between two samples,
    divided by wall-clock elapsed time and normalized by logical core count
    (0-100 total, like btop's default view).
  - Memory is RSS, formatted as human-readable MB/GB, with the raw byte
    count included as mem_bytes for exact sorting.
  - Threads, user, pid, short program name and full command line are included.

This is meant to run as a long-lived process (spawned once), not re-executed
every tick — psutil needs to keep its internal per-PID CPU-time cache alive
across samples to produce btop-accurate CPU% numbers. Re-running the script
from scratch every second (as one-shot) would make every cpu_percent() read
as 0.0 on the first call.

Output: one JSON array printed per line, flushed immediately, forever.
Schema per process:
    {"pid": "1234", "program": "firefox", "command": "/usr/lib/firefox ...",
     "threads": 42, "user": "kai", "mem": "512.3MB", "mem_bytes": 537185484,
     "cpu": 3.2}
"""

import json
import sys
import time

import psutil

INTERVAL = 1.0
NUM_CORES = psutil.cpu_count(logical=True) or 1

# --- "lazy sort" emulation (like btop's cpu_lazy) -------------------------
# btop doesn't re-sort the list every single tick based on raw instantaneous
# CPU%, because that makes rows jitter/swap constantly when two processes
# have close values. Instead it sorts using a smoothed (EMA) value, so the
# order settles down and only reshuffles when a process's usage genuinely
# and sustainedly changes, while the *displayed* number stays instantaneous.
EMA_ALPHA = 0.35  # higher = follows recent values more closely, lower = smoother/lazier
_cpu_ema: dict[int, float] = {}


def human_mem(bytes_val: float) -> str:
    """Format bytes the way btop does: MB by default, GB once it's large."""
    mb = bytes_val / (1024 * 1024)
    if mb >= 1024:
        return f"{mb / 1024:.1f}GB"
    return f"{mb:.1f}MB"


def snapshot(procs: dict[int, psutil.Process]) -> list[dict]:
    # Pick up newly spawned processes, drop dead ones.
    for pid in psutil.pids():
        if pid not in procs:
            try:
                p = psutil.Process(pid)
                p.cpu_percent(None)  # prime the internal cpu-time cache
                procs[pid] = p
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

    result = []
    dead = []

    for pid, p in procs.items():
        try:
            with p.oneshot():
                # psutil returns 0-100*NUM_CORES (like `top`'s default).
                # btop normalizes to 0-100 total by dividing by core count.
                cpu = p.cpu_percent(None) / NUM_CORES

                # Update this pid's smoothed value for sorting purposes only.
                prev_ema = _cpu_ema.get(pid, cpu)
                ema = EMA_ALPHA * cpu + (1 - EMA_ALPHA) * prev_ema
                _cpu_ema[pid] = ema

                mem_bytes = p.memory_info().rss
                threads = p.num_threads()
                user = p.username()
                name = p.name()
                cmdline = p.cmdline()

            command = " ".join(cmdline) if cmdline else f"[{name}]"

            result.append(
                {
                    "pid": str(pid),
                    "program": name,
                    "command": command,
                    "threads": threads,
                    "user": user,
                    "mem": human_mem(mem_bytes),
                    "mem_bytes": mem_bytes,
                    "cpu": round(cpu, 1),
                    "_sort_key": ema,  # smoothed value, stripped before output
                }
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            dead.append(pid)

    for pid in dead:
        procs.pop(pid, None)
        _cpu_ema.pop(pid, None)

    # "Lazy" sort: order by smoothed CPU (EMA), not the raw instantaneous
    # value, so the list doesn't jitter/reshuffle every tick. The displayed
    # "cpu" field is still the real instantaneous number.
    result.sort(key=lambda x: x["_sort_key"], reverse=True)
    for row in result:
        del row["_sort_key"]
    return result


def main() -> None:
    procs: dict[int, psutil.Process] = {}

    # First pass just primes cpu_percent() caches; btop does the same thing
    # on startup before showing real numbers.
    snapshot(procs)
    time.sleep(INTERVAL)

    while True:
        data = snapshot(procs)
        sys.stdout.write(json.dumps(data) + "\n")
        sys.stdout.flush()
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
