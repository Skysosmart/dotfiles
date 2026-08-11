# Hyprland → Niri Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boot a fully configured Niri session alongside Hyprland with the Quickshell rice working under both compositors.

**Architecture:** Niri installs as a second SDDM session. Compositor-specific calls in the rice go through a shell-level shim (`compositor.sh`) plus per-call-site branches keyed on `$NIRI_SOCKET` / `$HYPRLAND_INSTANCE_SIGNATURE`, matching the rice's existing script-driven cache architecture. Hyprland paths must keep working after every task.

**Tech Stack:** Arch Linux, niri 26.04, xwayland-satellite 0.8.2, quickshell-git 0.3, bash + jq + socat, KDL config, GNU stow.

## Global Constraints

- Hyprland session must remain bootable and fully functional after every commit.
- All new config lives in `~/dotfiles` (stow packages); rice edits happen in the stowed tree so they land in git.
- Absolute paths in niri `spawn` args (niri does not do shell/tilde expansion).
- Niri IPC facts referenced here (action names, JSON fields, event names) date from niri ≤25.x docs; each task verifies against the installed 26.04 (`niri msg --help`, nested session) before relying on them.
- Every script change: `bash -n` the file, then test the Hyprland path in the live session before commit.

---

### Task 1: Install niri + xwayland-satellite

**Files:** none (system packages)

- [ ] **Step 1: Install**

```bash
sudo pacman -S --needed niri xwayland-satellite
```

- [ ] **Step 2: Verify session + binaries**

```bash
ls /usr/share/wayland-sessions/niri.desktop   # SDDM session entry
niri --version                                 # expect 26.04
niri msg --help | head -30                     # confirm msg subcommands
```

Expected: desktop file exists; version prints. If `niri.desktop` Exec is `niri-session`, systemd session integration is active (equivalent of the old `session.conf` dbus/systemd env update — nothing to port).

- [ ] **Step 3: Record IPC ground truth for later tasks**

```bash
niri msg --help; niri msg action --help 2>&1 | head -80
```

Confirm these exist (adjust later tasks' commands if names differ): `focus-workspace`, `move-window-to-workspace`, `close-window`, `toggle-window-floating`, `set-column-width`, `set-window-height`, `switch-layout`, `spawn`, `quit`, `focus-monitor-next`, plus `niri msg --json workspaces|windows|outputs|keyboard-layouts|event-stream`.

### Task 2: Niri stow package with full config.kdl

**Files:**
- Create: `~/dotfiles/niri/.config/niri/config.kdl`

**Interfaces:**
- Produces: keybinds that call the same scripts Hyprland binds call; `$NIRI_SOCKET` present in the session for all later tasks' branches.

- [ ] **Step 1: Write config.kdl**

```kdl
// Niri config — ported from ~/.config/hypr (2026-08-11 migration)

input {
    keyboard {
        xkb {
            layout "us,th"
            options "grp:alt_shift_toggle"
        }
    }
    touchpad {
        tap
        dwt
        natural-scroll
        drag true
        drag-lock
        click-method "clickfinger"
        scroll-factor 0.8
        accel-speed 0.2
        accel-profile "adaptive"
    }
    mouse {
        accel-speed 0.2
        accel-profile "adaptive"
    }
    // cursor no_warps=true equivalent: niri does not warp unless asked
    workspace-auto-back-and-forth false
}

output "eDP-1" {
    mode "1920x1080@144"
    position x=0 y=0
    scale 1
}

layout {
    gaps 4
    center-focused-column "never"
    default-column-width { proportion 0.5; }
    focus-ring { off; }
    border {
        width 2
        active-color "#89b4fa"     // static for Phase 1; matugen template is Phase 3
        inactive-color "#313244"
    }
}

prefer-no-csd
screenshot-path "~/Pictures/Screenshots/%Y-%m-%d %H-%M-%S.png"

environment {
    NIXOS_OZONE_WL "1"
    XDG_PICTURES_DIR "/home/zaru/Pictures"
    XDG_VIDEOS_DIR "/home/zaru/Videos"
    WALLPAPER_DIR "/home/zaru/Pictures/Wallpapers"
    SCRIPT_DIR "/home/zaru/.config/hypr/scripts"
    QT_QPA_PLATFORMTHEME "qt6ct"
    ELECTRON_OZONE_PLATFORM_HINT "auto"
    __NV_PRIME_RENDER_OFFLOAD "1"
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER "NVIDIA-G0"
    __GL_GSYNC_ALLOWED "0"
    __GL_VRR_ALLOWED "0"
    __GL_SHADER_DISK_CACHE "1"
    __GL_SHADER_DISK_CACHE_PATH "/home/zaru/.cache/nvidia"
    __GLX_VENDOR_LIBRARY_NAME "nvidia"
    LIBVA_DRIVER_NAME "nvidia"
}

spawn-at-startup "systemctl" "--user" "start" "hyprpolkitagent"
spawn-at-startup "awww-daemon"
spawn-at-startup "hypridle"
spawn-at-startup "quickshell" "-p" "/home/zaru/.config/hypr/scripts/quickshell/Shell.qml"
spawn-at-startup "/home/zaru/.config/hypr/scripts/quickshell/focustime/launch_daemon.sh"
spawn-at-startup "/home/zaru/.config/hypr/scripts/init.sh"
spawn-at-startup "/home/zaru/.config/hypr/scripts/settings_watcher.sh"
spawn-at-startup "playerctld"
spawn-at-startup "sh" "-c" "swayosd-server --top-margin 0.9 --style \"$HOME/.config/swayosd/style.css\""
spawn-at-startup "sh" "-c" "wl-paste --type text --watch cliphist store"
spawn-at-startup "sh" "-c" "wl-paste --type image --watch cliphist store"
spawn-at-startup "/home/zaru/.config/hypr/scripts/volume_listener.sh"
spawn-at-startup "/home/zaru/.config/hypr/scripts/update_notifier.sh"
spawn-at-startup "/home/zaru/.config/hypr/scripts/deskicon.sh" "start"
spawn-at-startup "/home/zaru/.config/hypr/scripts/audioviz.sh" "start"
spawn-at-startup "kdeconnect-indicator"

window-rule {
    geometry-corner-radius 4
    clip-to-geometry true
}
window-rule {
    match title="^app-launcher$"
    open-floating true
    default-column-width { fixed 1200; }
    default-window-height { fixed 600; }
}
window-rule {
    match title="^qs-master$"
    open-floating true
    open-focused false
}
window-rule {
    match app-id="^spotify$"
    opacity 0.70
}
window-rule {
    match app-id="^vesktop$"
    opacity 0.70
}

binds {
    // ── window management ──
    Alt+F4              { close-window; }
    Mod+Shift+F         { toggle-window-floating; }
    Mod+Left            { focus-column-left; }
    Mod+Right           { focus-column-right; }
    Mod+Up              { focus-window-up; }
    Mod+Down            { focus-window-down; }
    Mod+Ctrl+Left       { move-column-left; }
    Mod+Ctrl+Right      { move-column-right; }
    Mod+Ctrl+Up         { move-window-up; }
    Mod+Ctrl+Down       { move-window-down; }
    Mod+Shift+Left      { set-column-width "-50"; }
    Mod+Shift+Right     { set-column-width "+50"; }
    Mod+Shift+Up        { set-window-height "-50"; }
    Mod+Shift+Down      { set-window-height "+50"; }

    // ── apps ──
    Mod+Return          { spawn "kitty"; }
    Mod+F               { spawn "firefox"; }
    Mod+E               { spawn "nautilus"; }
    Mod+R               { spawn "bash" "/home/zaru/.config/hypr/scripts/reload.sh"; }

    // ── quickshell panels (same scripts as Hyprland binds) ──
    Mod+C               { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "clipboard"; }
    Mod+P               { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "movies"; }
    Mod+D               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "applauncher"; }
    Mod+Shift+S         { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "settings"; }
    Mod+Q               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "music"; }
    Mod+B               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "battery"; }
    Mod+Shift+B         { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "blackarch"; }
    Mod+W               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "wallpaper"; }
    Mod+Shift+W         { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "wallpaper" "Video"; }
    Mod+S               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "calendar"; }
    Mod+N               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "network"; }
    Mod+Shift+T         { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "focustime"; }
    Mod+V               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "volume"; }
    Mod+H               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "guide"; }
    Mod+G               { spawn "bash" "/home/zaru/.config/hypr/scripts/qs_manager.sh" "toggle" "gamebar"; }
    Mod+A               { spawn "bash" "/home/zaru/.config/hypr/scripts/deskvisuals.sh" "toggle"; }

    // ── hardware / OSD (work while locked) ──
    Caps_Lock                 allow-when-locked=true { spawn "sh" "-c" "sleep 0.1 && swayosd-client --caps-lock"; }
    XF86MonBrightnessDown     allow-when-locked=true { spawn "swayosd-client" "--brightness" "lower"; }
    XF86MonBrightnessUp       allow-when-locked=true { spawn "swayosd-client" "--brightness" "raise"; }
    XF86AudioMicMute          allow-when-locked=true { spawn "swayosd-client" "--input-volume" "mute-toggle"; }
    XF86AudioMute             allow-when-locked=true { spawn "swayosd-client" "--output-volume" "mute-toggle"; }
    XF86AudioLowerVolume      allow-when-locked=true { spawn "swayosd-client" "--output-volume" "lower"; }
    XF86AudioRaiseVolume      allow-when-locked=true { spawn "swayosd-client" "--output-volume" "raise"; }
    XF86AudioPause            allow-when-locked=true { spawn "playerctl" "play-pause"; }
    XF86AudioPlay             allow-when-locked=true { spawn "playerctl" "play-pause"; }
    Mod+Space                 allow-when-locked=true { spawn "playerctl" "play-pause"; }

    // ── screenshots / lock ──
    Print               { spawn "/home/zaru/.config/hypr/scripts/screenshot.sh"; }
    Shift+Print         { spawn "/home/zaru/.config/hypr/scripts/screenshot.sh" "--edit"; }
    Mod+Print           { spawn "/home/zaru/.config/hypr/scripts/screenshot.sh" "--full"; }
    Mod+Shift+Print     { spawn "/home/zaru/.config/hypr/scripts/screenshot.sh" "--full" "--edit"; }
    XF86PowerOff        allow-when-locked=true { spawn "bash" "/home/zaru/.config/hypr/scripts/lock.sh"; }
    Mod+L               { spawn "bash" "/home/zaru/.config/hypr/scripts/lock.sh"; }

    // ── workspaces (via qs_manager for popup-close side effect; niri branch added in Task 5) ──
    Mod+1 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "1"; }
    Mod+2 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "2"; }
    Mod+3 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "3"; }
    Mod+4 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "4"; }
    Mod+5 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "5"; }
    Mod+6 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "6"; }
    Mod+7 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "7"; }
    Mod+8 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "8"; }
    Mod+9 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "9"; }
    Mod+0 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "10"; }
    Mod+Shift+1 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "1" "move"; }
    Mod+Shift+2 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "2" "move"; }
    Mod+Shift+3 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "3" "move"; }
    Mod+Shift+4 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "4" "move"; }
    Mod+Shift+5 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "5" "move"; }
    Mod+Shift+6 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "6" "move"; }
    Mod+Shift+7 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "7" "move"; }
    Mod+Shift+8 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "8" "move"; }
    Mod+Shift+9 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "9" "move"; }
    Mod+Shift+0 { spawn "/home/zaru/.config/hypr/scripts/qs_manager.sh" "10" "move"; }

    Mod+Tab             { spawn "/home/zaru/.config/hypr/scripts/focus_next_monitor.sh"; }
    Mod+Shift+E         { quit; }
    Mod+Shift+Slash     { show-hotkey-overlay; }
}
```

Notes locked in here: Super+drag move/resize and 3-finger workspace gestures are niri built-ins (no `bindm`/`gesture` port needed; niri workspaces are vertical, so the gesture is 3-finger **vertical**). Custom Hyprland animations intentionally not ported (spec: out of scope).

- [ ] **Step 2: Stow and validate**

```bash
mkdir -p ~/dotfiles/niri/.config/niri   # then write config.kdl there
cd ~/dotfiles && stow niri
niri validate
```

Expected: `niri validate` exits 0. If it rejects any field (26.04 syntax drift), fix per its error message — it names the line and expected grammar.

- [ ] **Step 3: Smoke-test nested**

Run `niri` inside the current Hyprland session (opens as a window). In a terminal:

```bash
niri msg --json workspaces | jq .   # against the NESTED instance: prefix with the socket it prints
```

Verify the nested session draws, Mod+Return opens kitty inside it. Exit with Mod+Shift+E.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles && git add niri && git commit -m "niri: initial config.kdl stow package"
```

### Task 3: Blur reality check → Glass decision

**Files:**
- Possibly modify: `~/.config/hypr/scripts/quickshell/Glass.qml` (stowed path in `~/dotfiles`)

- [ ] **Step 1: Check niri 26.04 layer-rule/blur support**

```bash
niri validate 2>&1; man niri 2>/dev/null | grep -i blur; grep -ri blur /usr/share/doc/niri/ 2>/dev/null
```

Also add a probe `layer-rule { match namespace="^quickshell$"; blur; }` to config.kdl and run `niri validate` — acceptance/rejection is ground truth. Check release notes: https://github.com/YaLTeR/niri/releases (WebFetch).

- [ ] **Step 2: Apply outcome**

- **Blur supported:** add layer-rules to config.kdl mirroring rules.conf namespaces (`quickshell`, `volume_osd`, `brightness_osd`, `qs-master`, `desk-orb`, `qs-popups`, `qs-floating-overlay`, `qs-screenshot-overlay`), validate, done.
- **Blur absent:** in `Glass.qml`, raise the glass surface base opacity so text stays readable over unblurred content. Add a compositor-keyed property (pattern below) rather than forking the file:

```qml
readonly property bool hasBlur: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
// use: color alpha = hasBlur ? 0.10 : 0.65 at the existing glass fill sites
```

- [ ] **Step 3: Verify + commit**

Launch quickshell nested/under Hyprland — glass unchanged there. Commit: `git commit -m "niri: glass blur strategy"`.

### Task 4: Compositor shim for scripts

**Files:**
- Create: `~/.config/hypr/scripts/compositor.sh` (in stowed tree)

**Interfaces:**
- Produces (sourced functions): `comp_is_niri` (exit code), `comp_kb_layout` (stdout: active layout name), `comp_dispatch_exec CMD...`, `comp_next_kb_layout`, `comp_monitors_json` (stdout: JSON array).

- [ ] **Step 1: Write compositor.sh**

```bash
#!/usr/bin/env bash
# compositor.sh — sourced shim: one place that knows which compositor is running.

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
```

- [ ] **Step 2: Test Hyprland path live (current session)**

```bash
bash -n ~/.config/hypr/scripts/compositor.sh
source ~/.config/hypr/scripts/compositor.sh
comp_is_niri; echo "niri=$?"          # expect niri=1
comp_kb_layout                          # expect e.g. "English (US)"
comp_monitors_json | jq '.[0].name'    # expect "eDP-1"
```

- [ ] **Step 3: Commit** — `git commit -m "scripts: compositor shim"`

### Task 5: Port the workspace pipeline (qs_manager.sh + workspaces.sh)

**Files:**
- Modify: `qs_manager.sh` fast path (lines 17–25)
- Modify: `workspaces.sh` (`print_workspaces` + event loop)

**Interfaces:**
- Consumes: `compositor.sh` functions (Task 4).
- Produces: `workspaces.json` cache in the EXACT existing schema `[{id, state: "active"|"occupied"|"empty", tooltip}]` — TopBar reads this; schema must not change.

- [ ] **Step 1: qs_manager.sh fast path**

Replace lines 21–23 (`CMD=...`/`hyprctl --batch`) with:

```bash
    if [[ -n "$NIRI_SOCKET" ]]; then
        if [[ "$TARGET" == "move" ]]; then
            niri msg action move-window-to-workspace "$ACTION" >/dev/null 2>&1
        else
            niri msg action focus-workspace "$ACTION" >/dev/null 2>&1
        fi
    else
        CMD="workspace $ACTION"
        [[ "$TARGET" == "move" ]] && CMD="movetoworkspace $ACTION"
        hyprctl --batch "dispatch $CMD" >/dev/null 2>&1
    fi
```

- [ ] **Step 2: workspaces.sh — niri print + event branches**

In `print_workspaces()`, branch at the top:

```bash
print_workspaces() {
    if [[ -n "$NIRI_SOCKET" ]]; then
        spaces=$(timeout 2 niri msg --json workspaces 2>/dev/null)
        wins=$(timeout 2 niri msg --json windows 2>/dev/null)
        [ -z "$spaces" ] || [ -z "$wins" ] && return
        jq -n --argjson ws "$spaces" --argjson wins "$wins" --arg end "$SEQ_END" -c '
            ($ws | map(select(.is_focused)) | first.output // ($ws[0].output)) as $out |
            ($ws | map(select(.output == $out))) as $mine |
            [range(1; ($end|tonumber) + 1)] | map(
                . as $i |
                ($mine | map(select(.idx == $i)) | first) as $w |
                ($wins | map(select($w != null and .workspace_id == $w.id))) as $ww |
                { id: $i,
                  state: (if ($w != null and $w.is_active) then "active"
                          elif (($ww | length) > 0) then "occupied"
                          else "empty" end),
                  tooltip: (($ww | first.title) // "Empty") }
            )' > "$QS_RUN_WORKSPACES/workspaces.tmp"
        mv "$QS_RUN_WORKSPACES/workspaces.tmp" "$QS_RUN_WORKSPACES/workspaces.json"
        return
    fi
    # ... existing hyprctl body unchanged ...
}
```

Event loop — wrap the existing socat loop:

```bash
while true; do
    if [[ -n "$NIRI_SOCKET" ]]; then
        niri msg --json event-stream 2>/dev/null | while read -r line; do
            case "$line" in
                *Workspace*|*Window*)
                    while read -t 0.05 -r extra_line; do continue; done
                    print_workspaces ;;
            esac
        done
    else
        socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock - | while read -r line; do
            # ... existing case block unchanged ...
        done
    fi
    sleep 1
done
```

- [ ] **Step 3: Verify both paths**

Hyprland (now): `bash -n`, restart `workspaces.sh`, switch workspaces, `jq . $XDG_RUNTIME_DIR/quickshell/workspaces/workspaces.json` shows correct active id. Niri (nested): run `NIRI_SOCKET=<nested socket> bash workspaces.sh` once, inspect the JSON; field names (`is_focused`, `idx`, `workspace_id`) corrected here against real 26.04 output if they differ.

- [ ] **Step 4: Commit** — `git commit -m "scripts: dual-compositor workspace pipeline"`

### Task 6: Keyboard-layout pipeline + misc scripts

**Files:** `quickshell/watchers/kb_fetch.sh`, `quickshell/watchers/kb_wait.sh`, `exit.sh`, `focus_next_monitor.sh`, `settings_watcher.sh`

- [ ] **Step 1: kb_fetch.sh — rewrite via shim**

```bash
#!/usr/bin/env bash
source "$HOME/.config/hypr/scripts/compositor.sh"
layout=$(comp_kb_layout)
[[ -z "$layout" || "$layout" == "null" ]] && layout="US"
echo "${layout:0:2}" | tr '[:lower:]' '[:upper:]'
```

- [ ] **Step 2: kb_wait.sh — add niri branch before the sleep-10 fallback**

```bash
elif [ -n "$NIRI_SOCKET" ]; then
    niri msg --json event-stream 2>/dev/null \
        | grep --line-buffered "KeyboardLayout" > "$PIPE" &
```

- [ ] **Step 3: exit.sh / focus_next_monitor.sh / settings_watcher.sh**

`exit.sh:8`: `if [[ -n "$NIRI_SOCKET" ]]; then niri msg action quit --skip-confirmation; else hyprctl dispatch exit; fi`
`focus_next_monitor.sh`: niri branch = `niri msg action focus-monitor-next` (skip cursor-warp block; single monitor anyway).
`settings_watcher.sh:110,114`: `hyprctl reload` → guard with `[[ -z "$NIRI_SOCKET" ]] &&` (niri live-reloads config.kdl on write; nothing to do).

- [ ] **Step 4: Verify + commit**

`bash -n` all five; under Hyprland: Alt+Shift toggles layout and bar pill updates within a second (kb pipeline intact). Commit: `git commit -m "scripts: niri branches for kb/exit/monitor/reload"`.

### Task 7: QML call sites

**Files:** `TopBar.qml:1291`, `applauncher/appLauncher.qml:149`, `deskicon/Icon.qml:20`, `Lock.qml:187`, `wallpaper/WallpaperPicker.qml:97`, `settings/SettingsPopup.qml:1056,2516,2608-2609`, `Config.qml:230,280,295`

**Interfaces:**
- Consumes: `compositor.sh` (Task 4) via subprocess.

- [ ] **Step 1: Mechanical replacements**

All sites follow one pattern — route through the shim instead of hyprctl:

- `TopBar.qml:1291` → `Quickshell.execDetached(["bash", "-c", "source $HOME/.config/hypr/scripts/compositor.sh && comp_next_kb_layout"])`
- `appLauncher.qml:149` and `Icon.qml:20` → `Quickshell.execDetached(["bash", "-c", "source $HOME/.config/hypr/scripts/compositor.sh && comp_dispatch_exec " + execStr])` — keep the existing quoting of `execStr` exactly as the current line composes it.
- `Lock.qml:187` → `command: ["bash", "-c", "$HOME/.config/hypr/scripts/quickshell/watchers/kb_fetch.sh"]` (reuses Task 6 logic; identical output format).
- `WallpaperPicker.qml:97` and `Config.qml:295` → `["bash", "-c", "source $HOME/.config/hypr/scripts/compositor.sh && comp_monitors_json"]`. **Then normalize:** niri `outputs` JSON differs from hyprctl `monitors` (`logical.width` vs `width` etc.). In both QML files the parse callback maps fields; add after `JSON.parse`:

```js
if (data.length && data[0].logical !== undefined) {   // niri shape → hyprctl shape
    data = data.map(m => ({ name: m.name,
        width: m.logical ? m.logical.width : m.modes[m.current_mode].width,
        height: m.logical ? m.logical.height : m.modes[m.current_mode].height,
        refreshRate: m.modes && m.current_mode != null ? m.modes[m.current_mode].refresh_rate / 1000 : 60,
        x: m.logical ? m.logical.x : 0, y: m.logical ? m.logical.y : 0,
        scale: m.logical ? m.logical.scale : 1, transform: 0, focused: true }));
}
```

(Verify exact niri output field names against `niri msg --json outputs` from Task 1 before writing this mapper; adjust names to reality.)

- `SettingsPopup.qml:1056,2608,2609` (submap passthru/reset — no niri equivalent): wrap each in `if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "")`. The keybind-capture editor stays Hyprland-only, matching the spec's out-of-scope settings pipeline.
- `SettingsPopup.qml:2516` (generic dispatcher test button): same guard; niri path does nothing.
- `Config.qml:230,280` (`hyprctl keyword monitor` display applier): guard with the same env check; under niri show `notify-send "Display settings" "Edit config.kdl — niri reloads live"` instead.

- [ ] **Step 2: Verify under Hyprland**

Restart quickshell in the live session (`Mod+R` / reload.sh). Check: layout pill click switches layout; app launcher launches an app; wallpaper picker opens and lists eDP-1; settings popup opens.

- [ ] **Step 3: Commit** — `git commit -m "quickshell: compositor-agnostic call sites"`

### Task 8: First real Niri login (USER GATE)

**Files:** none

- [ ] **Step 1 (user):** Log out → pick **Niri** in SDDM → log in.
- [ ] **Step 2 (user+agent):** Run through the Phase 1+2 gate in the spec: bar up with correct workspaces; Mod+1..0 switch; Alt+Shift toggles th/us and the pill updates; launcher/clipboard/calendar open; Mod+L locks and unlocks; kitty/firefox launch; an X11 app runs (`xwayland-satellite` auto-managed — check `pgrep xwayland-satellite`).
- [ ] **Step 3:** Note every breakage; fix in this session under Niri (Hyprland fallback is one logout away). Re-verify Hyprland path afterward for each fix.

### Task 9: Polish + wrap-up

**Files:** various from Task 8 findings; `~/dotfiles` commit; memory update

- [ ] **Step 1:** Fix Task 8 findings (each: reproduce → fix → verify both compositors → commit).
- [ ] **Step 2:** Screenshot overlay + deskicon/audioviz/gamebar spot-check under Niri.
- [ ] **Step 3:** Final commit + push dotfiles. Update auto-memory: niri is a second session; rice is dual-compositor.

## Self-Review (done at write time)

- **Spec coverage:** stow package (T2), abstraction (T4, adapted from QML-singleton to shell shim per measured evidence — QML sites are all subprocess calls), 9 files (T5–T7), session integration (T1), blur risk (T3), gates (T8), polish (T9). Deviation from spec noted: `CompositorService` QML singleton replaced by `compositor.sh` — matches the rice's actual script-driven architecture; spec's intent (single switch point, no fork) preserved.
- **Placeholders:** none; every step has runnable content. Niri JSON field names flagged as verify-against-26.04 where my reference predates the release.
- **Consistency:** shim function names identical across T4 consumers (T5–T7); `workspaces.json` schema explicitly frozen.
