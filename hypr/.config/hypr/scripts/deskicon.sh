#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Centered desktop Arch logo (standalone quickshell instance)
#  start  : launch if not already running   (used at autostart for always-on)
#  stop   : kill it
#  toggle : flip it on/off                   (bound to a key)
# ─────────────────────────────────────────────────────────────────────────────
ICON_QML="$HOME/.config/hypr/scripts/quickshell/deskicon/Icon.qml"
MATCH="quickshell.*deskicon/Icon.qml"

is_running() { pgrep -f "$MATCH" >/dev/null 2>&1; }

start() {
    is_running && return 0
    quickshell -p "$ICON_QML" >/dev/null 2>&1 &
    disown
}

stop() { pkill -f "$MATCH" >/dev/null 2>&1; }

case "${1:-toggle}" in
    start)  start ;;
    stop)   stop ;;
    toggle) if is_running; then stop; else start; fi ;;
    *) echo "usage: $0 {start|stop|toggle}" >&2; exit 1 ;;
esac
