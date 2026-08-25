-- --------------------------------------------------------------------------------------
--
--   ██╗██╗  ██╗   ██╗ █████╗ ███╗   ███╗██╗██████╗  ██████╗
--   ██║██║  ╚██╗ ██╔╝██╔══██╗████╗ ████║██║██╔══██╗██╔═══██╗
--   ██║██║   ╚████╔╝ ███████║██╔████╔██║██║██████╔╝██║   ██║
--   ██║██║    ╚██╔╝  ██╔══██║██║╚██╔╝██║██║██╔══██╗██║   ██║
--   ██║███████╗██║   ██║  ██║██║ ╚═╝ ██║██║██║  ██║╚██████╔╝
--   ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝
--
--   Created by ilyamiro
--   https://github.com/ilyamiro/nixos-configuration
--
--   Lua config -- the .conf format is removed in Hyprland 0.57.
--   The old .conf tree is kept alongside as a rollback path; Hyprland prefers
--   this file whenever it exists.
-- --------------------------------------------------------------------------------------

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ MODULAR CONFIGURATION
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Dummy bind to force Hyprland to register the submap in memory.
-- Since you will never press this, all normal keystrokes fall through to Quickshell
hl.define_submap("passthru", function()
    hl.bind("SUPER + SHIFT + CTRL + ALT + F35", hl.dsp.exec_cmd("true"))
end)

-- --------------

require("config.monitors")
require("config.env")
require("config.session")
require("config.autostart")
require("config.settings")
require("config.rules")
require("config.keybindings")

-- Desktop centerpiece: centered BlackArch logo, wallpaper-gradient tinted (launched via settings.json .startup -> deskicon.sh)
-- Orb serpent emblem disabled in favor of the BlackArch logo -- uncomment to bring the orb back:
-- hl.on("hyprland.start", function()
--     hl.exec_cmd("quickshell -p ~/.config/hypr/scripts/quickshell/orb/Orb.qml")
-- end)
