#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Toggle the desktop BlackArch logo AND its audio-wave ring together, in sync.
#  Bound to Super+A. If either is currently showing, hide BOTH; otherwise show
#  BOTH. Delegates to the existing per-widget scripts so launch/daemonize logic
#  lives in one place.
#      show/start : bring the logo + wave back
#      hide/stop  : make the logo + wave disappear
#      toggle     : flip both together (default)
# ─────────────────────────────────────────────────────────────────────────────
DESKICON="$HOME/.config/hypr/scripts/deskicon.sh"
AUDIOVIZ="$HOME/.config/hypr/scripts/audioviz.sh"

LOGO_MATCH="quickshell.*deskicon/Icon.qml"
WAVE_MATCH="quickshell.*audioviz/AudioViz.qml"

either_running() {
    pgrep -f "$LOGO_MATCH" >/dev/null 2>&1 || pgrep -f "$WAVE_MATCH" >/dev/null 2>&1
}

show() { bash "$DESKICON" start; bash "$AUDIOVIZ" start; }
hide() { bash "$DESKICON" stop;  bash "$AUDIOVIZ" stop;  }

case "${1:-toggle}" in
    start|show) show ;;
    stop|hide)  hide ;;
    toggle)     if either_running; then hide; else show; fi ;;
    *) echo "usage: $0 {toggle|show|hide}" >&2; exit 1 ;;
esac
