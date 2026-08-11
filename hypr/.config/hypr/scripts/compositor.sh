#!/usr/bin/env bash
# compositor.sh — sourced shim: the one place that knows which compositor is running.
# Niri detection via $NIRI_SOCKET, Hyprland otherwise.

comp_is_niri() { [[ -n "$NIRI_SOCKET" ]]; }

comp_kb_layout() {
    if comp_is_niri; then
        timeout 2 niri msg --json keyboard-layouts 2>/dev/null \
            | jq -r '.names[.current_idx] // empty'
    else
        LC_ALL=C timeout 2 hyprctl devices -j 2>/dev/null \
            | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty'
    fi
}

comp_next_kb_layout() {
    if comp_is_niri; then niri msg action switch-layout next
    else hyprctl switchxkblayout main next; fi
}

comp_dispatch_exec() {
    if comp_is_niri; then niri msg action spawn -- "$@"
    else hyprctl dispatch exec -- "$@"; fi
}

comp_monitors_json() {
    if comp_is_niri; then timeout 2 niri msg --json outputs 2>/dev/null
    else timeout 2 hyprctl monitors -j 2>/dev/null; fi
}
