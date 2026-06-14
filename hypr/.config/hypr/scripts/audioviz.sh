#!/usr/bin/env bash
QML="$HOME/.config/hypr/scripts/quickshell/audioviz/AudioViz.qml"
MATCH="quickshell.*audioviz/AudioViz.qml"
is_running() { pgrep -f "$MATCH" >/dev/null 2>&1; }
case "${1:-toggle}" in
    start)  is_running || { setsid -f quickshell -p "$QML" >/dev/null 2>&1; } ;;
    stop)   pkill -f "$MATCH" ;;
    toggle) if is_running; then pkill -f "$MATCH"; else setsid -f quickshell -p "$QML" >/dev/null 2>&1; fi ;;
esac
