#!/usr/bin/env bash
# Emits the active keyboard layout name (full xkb name, e.g. "English (US)", "Thai")
# Usage: kb_layout.sh get | kb_layout.sh watch

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true

ACTION="${1:-get}"

get_layout() {
    local name=""
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1; then
        name=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '((.keyboards[] | select(.main == true)) // .keyboards[0]) | .active_keymap // empty' 2>/dev/null | head -n1)
    fi
    [ -z "$name" ] && name="English (US)"
    echo "$name"
}

watch_layout() {
    local last="" cur
    last="$(get_layout)"
    echo "$last"
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v socat >/dev/null 2>&1; then
        # Loop so the watcher self-heals if socat ever drops the connection.
        while true; do
            LC_ALL=C socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" 2>/dev/null \
                | grep --line-buffered "^activelayout>>" \
                | while read -r _line; do
                    cur="$(get_layout)"
                    if [ "$cur" != "$last" ]; then
                        last="$cur"
                        echo "$cur"
                    fi
                done
            sleep 1
            cur="$(get_layout)"
            if [ "$cur" != "$last" ]; then
                last="$cur"
                echo "$cur"
            fi
        done
    else
        # Fallback: poll
        while true; do
            cur="$(get_layout)"
            if [ "$cur" != "$last" ]; then
                last="$cur"
                echo "$cur"
            fi
            sleep 0.5
        done
    fi
}

case "$ACTION" in
    get) get_layout ;;
    watch) watch_layout ;;
    *) get_layout ;;
esac
