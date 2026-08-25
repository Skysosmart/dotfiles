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

# Hyprland's Lua config reinterprets `hyprctl dispatch <args>` as the Lua expression
# hl.dispatch(<args>), so the legacy space-separated form ("dispatch exec -- firefox")
# is a syntax error and silently launches nothing. Mirror Hyprland's own selection
# rule: the Lua config wins whenever hyprland.lua exists.
comp_hypr_lua_config() {
    local dir="${HYPRLAND_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr}"
    [[ -f "$dir/hyprland.lua" ]]
}

# Render an arbitrary command string as a Lua double-quoted literal. Long brackets
# ([[..]]) would break on an exec string that contains ]], so escape instead.
comp_lua_str() {
    local s=$1
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '"%s"' "$s"
}

# Legacy dispatcher name + args -> Lua dispatcher expression, or non-zero if unmapped.
# Covers every dispatcher the Settings UI offers plus the ones these scripts use.
# Mirrors the BUILD table in lib/binds.lua; keep the two in step.
comp_lua_dispatch_expr() {
    local name="${1,,}" arg="${2-}" x y dir
    _dir() {
        case "${1,,}" in
            l|left)  dir=left ;;  r|right) dir=right ;;
            u|t|up)  dir=up ;;    d|b|down) dir=down ;;
            *) return 1 ;;
        esac
    }
    # workspace selectors stay strings ("e+1", "special:magic"); plain numbers stay numbers
    _ws() { if [[ "$arg" =~ ^-?[0-9]+$ ]]; then printf '%s' "$arg"; else comp_lua_str "$arg"; fi; }
    _xy() { read -r x y <<<"$arg"; [[ "$x" =~ ^-?[0-9.]+$ && "$y" =~ ^-?[0-9.]+$ ]]; }

    case "$name" in
        exec|exec-once)         printf 'hl.dsp.exec_cmd(%s)' "$(comp_lua_str "$arg")" ;;
        killactive|closewindow) printf 'hl.dsp.window.close()' ;;
        togglefloating)         printf 'hl.dsp.window.float({action="toggle"})' ;;
        fullscreen)             printf 'hl.dsp.window.fullscreen()' ;;
        pin)                    printf 'hl.dsp.window.pin()' ;;
        pseudo)                 printf 'hl.dsp.window.pseudo()' ;;
        exit)                   printf 'hl.dsp.exit()' ;;
        workspace)              printf 'hl.dsp.focus({workspace=%s})' "$(_ws)" ;;
        movetoworkspace)        printf 'hl.dsp.window.move({workspace=%s})' "$(_ws)" ;;
        togglespecialworkspace) printf 'hl.dsp.workspace.toggle_special(%s)' "$(comp_lua_str "$arg")" ;;
        focusmonitor)           printf 'hl.dsp.focus({monitor=%s})' "$(comp_lua_str "$arg")" ;;
        submap)                 printf 'hl.dsp.submap(%s)' "$(comp_lua_str "$arg")" ;;
        movefocus)              _dir "$arg" || return 1; printf 'hl.dsp.focus({direction="%s"})' "$dir" ;;
        movewindow)
            if [[ -z "${arg// }" ]]; then printf 'hl.dsp.window.drag()'
            else _dir "$arg" || return 1; printf 'hl.dsp.window.move({direction="%s"})' "$dir"; fi ;;
        resizewindow)           printf 'hl.dsp.window.resize()' ;;
        resizeactive)           _xy || return 1; printf 'hl.dsp.window.resize({x=%s,y=%s,relative=true})' "$x" "$y" ;;
        movecursor)             _xy || return 1; printf 'hl.dsp.cursor.move({x=%s,y=%s})' "$x" "$y" ;;
        *) return 1 ;;
    esac
}

# Issue a dispatcher by its legacy name. Use this instead of `hyprctl dispatch <name> <args>`,
# which is a Lua syntax error under hyprland.lua and fails silently.
comp_dispatch() {
    local name=$1 arg=${2-} expr
    if comp_hypr_lua_config; then
        if expr=$(comp_lua_dispatch_expr "$name" "$arg"); then
            hyprctl dispatch "$expr"
            return
        fi
        # Better a visible complaint than a keybind that quietly does nothing.
        printf 'comp_dispatch: no Lua mapping for dispatcher %s\n' "$name" >&2
        return 1
    fi
    hyprctl dispatch "$name" $arg
}

comp_dispatch_exec() {
    # hyprctl exec runs the string through a shell; niri's spawn-sh matches that
    if comp_is_niri; then niri msg action spawn-sh -- "$*"
    elif comp_hypr_lua_config; then
        hyprctl dispatch "hl.dsp.exec_cmd($(comp_lua_str "$*"))"
    else hyprctl dispatch exec -- "$@"; fi
}

# Apply monitor layout live. `hyprctl keyword` is refused outright by the Lua parser
# ("keyword can't work with non-legacy parsers. Use eval."), so this builds hl.monitor{}
# calls instead -- the same shape config/monitors.lua uses at startup.
# Each argument is a legacy spec: name,WIDTHxHEIGHT@RATE,XxY,scale[,transform,N]
comp_apply_monitors() {
    (( $# )) || return 0
    comp_is_niri && return 0   # niri reloads config.kdl on its own

    local spec name mode pos scale rest
    if ! comp_hypr_lua_config; then
        local batch=""
        for spec in "$@"; do batch+="keyword monitor $spec ; "; done
        hyprctl --batch "${batch% ; }"
        return
    fi

    local lua=""
    for spec in "$@"; do
        IFS=',' read -r name mode pos scale rest <<<"$spec"
        lua+="hl.monitor({output=$(comp_lua_str "$name"),mode=$(comp_lua_str "$mode")"
        lua+=",position=$(comp_lua_str "$pos"),scale=$(comp_lua_str "$scale")"
        # trailing "transform,N" -- hl.monitor wants it as a number
        [[ -n "$rest" ]] && lua+=",transform=${rest##*,}"
        lua+="}) "
    done
    hyprctl eval "$lua"
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
                  transform: ({"Normal":0,"90":1,"180":2,"270":3,
                               "Flipped":4,"Flipped90":5,"Flipped180":6,"Flipped270":7}
                              [(.logical.transform // "Normal")] // 0),
                  focused: false,
                  availableModes: ((.modes // []) | map("\(.width)x\(.height)@\(.refresh_rate/1000)Hz"))
                })
            | if length > 0 then .[0].focused = true else . end'
    else
        timeout 2 hyprctl monitors -j 2>/dev/null
    fi
}
