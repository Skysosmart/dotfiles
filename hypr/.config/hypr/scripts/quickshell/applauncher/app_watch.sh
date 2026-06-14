#!/usr/bin/env bash
# Watch every standard "installed apps" directory for .desktop changes and emit a
# line on each event. The world launcher (deskicon/Icon.qml) listens to this and
# re-runs app_fetcher.py so newly installed/removed apps appear on the globe live.

dirs=(
    /usr/share/applications
    /usr/local/share/applications
    "$HOME/.local/share/applications"
    /var/lib/flatpak/exports/share/applications
    "$HOME/.local/share/flatpak/exports/share/applications"
    "$HOME/.nix-profile/share/applications"
    /run/current-system/sw/share/applications
)

# Only watch directories that actually exist (inotifywait errors on missing paths).
existing=()
for d in "${dirs[@]}"; do
    [ -d "$d" ] && existing+=("$d")
done
[ ${#existing[@]} -eq 0 ] && exit 0

# -m: keep running, -q: quiet, -r: recurse into subdirs (fetcher globs recursively too).
exec inotifywait -m -q -r \
    -e create -e delete -e moved_to -e moved_from -e close_write \
    --format '%w%f' "${existing[@]}"
