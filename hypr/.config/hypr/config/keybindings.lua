-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ KEYBINDINGS
--  Static core binds live here; the ones editable in the Settings UI are
--  regenerated from settings.json into keybinds_data.lua and translated by lib/binds.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local vars  = require("config.variables")
local binds = require("lib.binds")

-- ───────── Static Core Binds ─────────
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.bind(vars.mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(vars.mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ───────── Dynamic Settings Binds ─────────
binds.apply(require("config.keybinds_data"), vars)
