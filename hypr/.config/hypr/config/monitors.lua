-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ MONITORS
--  Specs are regenerated from settings.json into monitors_data.lua.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local monitors = require("config.monitors_data")

if #monitors == 0 then
    -- same fallback the old generator wrote: monitor = , preferred, auto, 1
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
else
    for _, m in ipairs(monitors) do
        hl.monitor(m)
    end
end
