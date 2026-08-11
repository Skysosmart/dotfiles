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
    # hyprctl exec runs the string through a shell; niri spawn does not — match via sh -c
    if comp_is_niri; then niri msg action spawn -- sh -c "$*"
    else hyprctl dispatch exec -- "$@"; fi
}

# Always emits hyprctl-monitors-shaped JSON:
# [{name, width, height, refreshRate, x, y, scale, transform, focused, availableModes}]
comp_monitors_json() {
    if comp_is_niri; then
        timeout 2 niri msg --json outputs 2>/dev/null | jq '
            (if type == "object" then [.[]] else . end)
            | map(
                (.modes[.current_mode] // {}) as $cm |
                {
                  name: .name,
                  width: ($cm.width // (.logical.width // 0)),
                  height: ($cm.height // (.logical.height // 0)),
                  refreshRate: (($cm.refresh_rate // 60000) / 1000),
                  x: (.logical.x // 0),
                  y: (.logical.y // 0),
                  scale: (.logical.scale // 1),
                  transform: ({"normal":0,"90":1,"180":2,"270":3,
                               "flipped":4,"flipped-90":5,"flipped-180":6,"flipped-270":7}
                              [(.logical.transform // "normal")] // 0),
                  focused: false,
                  availableModes: ((.modes // []) | map("\(.width)x\(.height)@\(.refresh_rate/1000)Hz"))
                })
            | if length > 0 then .[0].focused = true else . end'
    else
        timeout 2 hyprctl monitors -j 2>/dev/null
    fi
}
