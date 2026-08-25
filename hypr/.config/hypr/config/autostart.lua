-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ AUTOSTART
--  The command list is regenerated from settings.json into autostart_data.lua;
--  this file only decides when to run it.
--
--  hyprland.start replaces exec-once: the Lua config is re-executed on every
--  `hyprctl reload`, so running these at load time would spawn a second quickshell,
--  hypridle, playerctld ... on every settings change.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local commands = require("config.autostart_data")

hl.on("hyprland.start", function()
    for _, cmd in ipairs(commands) do
        hl.exec_cmd(cmd)
    end
end)
