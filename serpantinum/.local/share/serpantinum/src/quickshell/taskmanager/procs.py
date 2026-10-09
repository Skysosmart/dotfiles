#!/usr/bin/env python3
"""Stream memory/CPU usage and the process list as one JSON line per tick.

Used by TaskManagerPopup.qml, which only runs this while the window is open.
CPU percentages are normalised to the whole machine (100% = every core busy).
"""
import json
import os
import sys
import time

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
PAGE = os.sysconf("SC_PAGE_SIZE")
HZ = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count() or 1
MY_UID = os.getuid()
MY_PID = os.getpid()


def read_meminfo():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, _, rest = line.partition(":")
            info[key] = int(rest.split()[0]) * 1024
    return info


def read_cpu_times():
    with open("/proc/stat") as f:
        parts = f.readline().split()[1:]
    vals = [int(x) for x in parts]
    idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
    return sum(vals), idle


def read_procs():
    procs = {}
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        pid = int(name)
        try:
            with open(f"/proc/{pid}/stat") as f:
                raw = f.read()
            comm = raw[raw.index("(") + 1:raw.rindex(")")]
            fields = raw[raw.rindex(")") + 2:].split()
            rss_pages = int(fields[21])
            if rss_pages == 0:
                continue  # kernel threads and zombies
            ticks = int(fields[11]) + int(fields[12])
            uid = os.stat(f"/proc/{pid}").st_uid
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                cmd = f.read(400).replace(b"\0", b" ").decode("utf-8", "replace").strip()
        except (OSError, ValueError, IndexError):
            continue
        procs[pid] = {
            "pid": pid,
            "name": comm,
            "cmd": cmd,
            "rss": rss_pages * PAGE,
            "ticks": ticks,
            "mine": uid == MY_UID,
        }
    return procs


def main():
    prev_ticks = {}
    prev_total, prev_idle = read_cpu_times()
    prev_time = time.monotonic()
    first = True

    while True:
        procs = read_procs()
        total, idle = read_cpu_times()
        now = time.monotonic()
        dt = max(now - prev_time, 1e-3)

        d_total = total - prev_total
        cpu_pct = 0.0 if first or d_total <= 0 else 100.0 * (1 - (idle - prev_idle) / d_total)

        out = []
        for pid, p in procs.items():
            if pid == MY_PID:
                continue
            last = prev_ticks.get(pid)
            cpu = 0.0
            if last is not None and not first:
                cpu = max(0.0, (p["ticks"] - last) / HZ / dt * 100.0 / NCPU)
            out.append({
                "pid": pid,
                "name": p["name"],
                "cmd": p["cmd"],
                "rss": p["rss"],
                "cpu": round(cpu, 1),
                "mine": p["mine"],
            })

        mem = read_meminfo()
        print(json.dumps({
            "memTotal": mem.get("MemTotal", 0),
            "memUsed": mem.get("MemTotal", 0) - mem.get("MemAvailable", 0),
            "memCached": mem.get("Cached", 0) + mem.get("Buffers", 0),
            "swapTotal": mem.get("SwapTotal", 0),
            "swapUsed": mem.get("SwapTotal", 0) - mem.get("SwapFree", 0),
            "cpu": round(cpu_pct, 1),
            "cores": NCPU,
            "procs": out,
        }), flush=True)

        prev_ticks = {pid: p["ticks"] for pid, p in procs.items()}
        prev_total, prev_idle, prev_time = total, idle, now
        first = False
        time.sleep(INTERVAL)


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
