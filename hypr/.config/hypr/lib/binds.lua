-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ BIND TRANSLATOR
--  Turns legacy keybind specs -- { type, mods, key, dispatcher, command } as stored in
--  settings.json -- into hl.bind() calls. The Settings UI keeps writing legacy specs, so
--  this file is the single place that knows how to speak both dialects.
--
--  Anything without a native mapping falls back to comp_dispatch in scripts/compositor.sh,
--  which translates a legacy dispatcher name into the Lua API. That means a dispatcher
--  added through the GUI later keeps working without touching this file.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local M = {}

-- Hyprland's legacy mod parser matched substrings, so SHIFT_L counted as SHIFT.
-- The Lua parser wants canonical names, so fold them here.
local MODS = {
    SHIFT = "SHIFT", SHIFT_L = "SHIFT", SHIFT_R = "SHIFT",
    CTRL = "CTRL", CTRL_L = "CTRL", CTRL_R = "CTRL", CONTROL = "CTRL",
    ALT = "ALT", ALT_L = "ALT", ALT_R = "ALT", MOD1 = "ALT",
    SUPER = "SUPER", SUPER_L = "SUPER", SUPER_R = "SUPER",
    MOD4 = "SUPER", WIN = "SUPER", LOGO = "SUPER",
    CAPS = "CAPS", CAPS_LOCK = "CAPS",
}

-- bind<flags> -> hl.bind options
local FLAGS = {
    e = "repeating", l = "locked",       m = "mouse",
    r = "release",   n = "non_consuming", t = "transparent",
    i = "ignore_mods", o = "long_press", p = "dont_inhibit",
}

local DIRS = {
    l = "left", r = "right", u = "up", d = "down", t = "up", b = "down",
    left = "left", right = "right", up = "up", down = "down",
}

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function xy(arg)
    local x, y = trim(arg):match("^(-?[%d%.]+)%s+(-?[%d%.]+)$")
    if x then return tonumber(x), tonumber(y) end
end

-- workspace args stay strings when they are selectors ("e+1", "special:magic")
local function ws(arg)
    arg = trim(arg)
    return tonumber(arg) or arg
end

-- "$mainMod SHIFT_L" + "F" -> "SUPER + SHIFT + F"
local function combo(mods, key, vars)
    local parts, seen = {}, {}
    for token in trim(mods):gmatch("%S+") do
        local name = token:gsub("^%$", "")
        if vars and vars[name] then name = vars[name] end
        name = name:upper()
        name = MODS[name] or name
        if not seen[name] then
            seen[name] = true
            parts[#parts + 1] = name
        end
    end
    parts[#parts + 1] = trim(key)
    return table.concat(parts, " + ")
end

-- Native mappings. A builder returning nil falls through to comp_dispatch (see below).
local BUILD = {
    exec = function(arg) return hl.dsp.exec_cmd(arg) end,
    killactive = function() return hl.dsp.window.close() end,
    closewindow = function() return hl.dsp.window.close() end,
    togglefloating = function() return hl.dsp.window.float({ action = "toggle" }) end,
    fullscreen = function() return hl.dsp.window.fullscreen() end,
    pin = function() return hl.dsp.window.pin() end,
    pseudo = function() return hl.dsp.window.pseudo() end,
    exit = function() return hl.dsp.exit() end,
    resizewindow = function() return hl.dsp.window.resize() end,

    resizeactive = function(arg)
        local x, y = xy(arg)
        if x then return hl.dsp.window.resize({ x = x, y = y, relative = true }) end
    end,

    -- bindm passes no argument: that is the click-drag move, not a directional one
    movewindow = function(arg)
        arg = trim(arg)
        if arg == "" then return hl.dsp.window.drag() end
        local dir = DIRS[arg:lower()]
        if dir then return hl.dsp.window.move({ direction = dir }) end
    end,

    movefocus = function(arg)
        local dir = DIRS[trim(arg):lower()]
        if dir then return hl.dsp.focus({ direction = dir }) end
    end,

    workspace = function(arg) return hl.dsp.focus({ workspace = ws(arg) }) end,
    movetoworkspace = function(arg) return hl.dsp.window.move({ workspace = ws(arg) }) end,
    togglespecialworkspace = function(arg) return hl.dsp.workspace.toggle_special(trim(arg)) end,

    ["exec-once"] = function(arg) return hl.dsp.exec_cmd(arg) end,
    focusmonitor = function(arg) return hl.dsp.focus({ monitor = trim(arg) }) end,
    submap = function(arg) return hl.dsp.submap(trim(arg)) end,

    movecursor = function(arg)
        local x, y = xy(arg)
        if x then return hl.dsp.cursor.move({ x = x, y = y }) end
    end,
}

-- `hyprctl dispatch <name> <args>` is a Lua syntax error under hyprland.lua, so the old
-- fallback produced binds that silently did nothing. Route unmapped dispatchers through
-- comp_dispatch in scripts/compositor.sh, which owns the legacy-name -> Lua translation
-- and complains on stderr instead of failing quietly.
local function shq(s)
    return "'" .. (tostring(s or ""):gsub("'", "'\\''")) .. "'"
end

local function fallback(dispatcher, arg)
    local cmd = table.concat({
        [[bash -c 'source "$HOME/.config/hypr/scripts/compositor.sh" && comp_dispatch "$1" "$2"' _]],
        shq(dispatcher), shq(trim(arg)),
    }, " ")
    return hl.dsp.exec_cmd(cmd)
end

local function options(bind_type)
    local opts = {}
    for c in (tostring(bind_type or "bind"):lower():match("^bind(.*)$") or ""):gmatch(".") do
        local flag = FLAGS[c]
        if flag then opts[flag] = true end
    end
    return opts
end

--- Register one legacy bind spec.
---@param spec table { type, mods, key, dispatcher, command }
---@param vars table|nil variable table, e.g. { mainMod = "SUPER" }
function M.bind(spec, vars)
    local keys = combo(spec.mods, spec.key, vars)
    if trim(spec.key) == "" then return false, "empty key" end

    local name = trim(spec.dispatcher)
    if name == "" then name = "exec" end
    local arg = spec.command

    if name == "exec" and trim(arg) == "" then return false, "exec with no command" end

    local dispatcher
    local builder = BUILD[name:lower()]
    if builder then
        -- A wrong native mapping must never cost you the bind, so fall back on error.
        local ok, built = pcall(builder, arg)
        if ok then dispatcher = built end
    end
    dispatcher = dispatcher or fallback(name, arg)

    local ok, err = pcall(hl.bind, keys, dispatcher, options(spec.type))
    if not ok then return false, tostring(err) end
    return true
end

--- Register a whole list of legacy bind specs.
--- One bad entry is skipped instead of aborting the config, which would drop every
--- other bind and drop Hyprland into emergency mode.
function M.apply(specs, vars)
    local failed = 0
    for _, spec in ipairs(specs or {}) do
        local ok, err = M.bind(spec, vars)
        if not ok then
            failed = failed + 1
            print(string.format("[binds] skipped %s + %s (%s): %s",
                tostring(spec.mods), tostring(spec.key), tostring(spec.dispatcher), tostring(err)))
        end
    end
    return failed
end

return M
