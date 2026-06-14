#!/usr/bin/env python3
# Emits the BlackArch arsenal as JSON for the BlackArchPopup launcher:
#   {"categories": [{"name": "recon", "group": "blackarch-recon",
#                    "total": N, "installed": M,
#                    "tools": [{"name": "nmap", "installed": true}, ...]}, ...]}
# Two pacman calls total, so it's fast enough to run on every popup open.
import subprocess
import json
import sys


def run(args):
    try:
        out = subprocess.run(args, capture_output=True, text=True, timeout=20)
        return out.stdout
    except Exception:
        return ""


def main():
    # 1) all blackarch group names (the 53 categories). `pacman -Sg` lists group names.
    groups = []
    for line in run(["pacman", "-Sg"]).splitlines():
        g = line.strip()
        # keep only the sub-categories (blackarch-*), skip the umbrella "blackarch"
        if g.startswith("blackarch-"):
            groups.append(g)
    groups = sorted(set(groups))

    if not groups:
        print(json.dumps({"categories": []}))
        return

    # 2) installed package set
    installed = set()
    for line in run(["pacman", "-Qq"]).splitlines():
        p = line.strip()
        if p:
            installed.add(p)

    # 3) one call to expand every group -> "group package" pairs
    cat_map = {g: [] for g in groups}
    for line in run(["pacman", "-Sg"] + groups).splitlines():
        parts = line.split()
        if len(parts) >= 2:
            grp, pkg = parts[0], parts[1]
            if grp in cat_map:
                cat_map[grp].append(pkg)

    categories = []
    for g in groups:
        tools = sorted(set(cat_map[g]), key=str.lower)
        entries = [{"name": t, "installed": t in installed} for t in tools]
        inst = sum(1 for e in entries if e["installed"])
        categories.append({
            "name": g[len("blackarch-"):],   # short label
            "group": g,
            "total": len(entries),
            "installed": inst,
            "tools": entries,
        })

    print(json.dumps({"categories": categories}))


if __name__ == "__main__":
    main()
