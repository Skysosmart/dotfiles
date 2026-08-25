-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--  ◈ WINDOW & LAYER RULES
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

hl.layer_rule({ name = "lr1", match = { namespace = "^(volume_osd)$" },     no_anim = true })
hl.layer_rule({ name = "lr2", match = { namespace = "^(brightness_osd)$" }, no_anim = true })
hl.layer_rule({ name = "lr3", match = { namespace = "hyprpicker" },         no_anim = true })
hl.layer_rule({ name = "lr4", match = { namespace = "qsdock" },             no_anim = true })

hl.layer_rule({
    name  = "lr5",
    match = { namespace = "ext-session-lock" },
    blur         = true,
    ignore_alpha = 0.2,
})

-- ───────── Liquid Glass: frosted backdrop blur for quickshell surfaces ─────────
-- default namespace covers the top bar + standalone popups (qs -p ...)
local GLASS = {
    ["glass-default"]    = "^(quickshell)$",
    ["glass-volosd"]     = "^(volume_osd)$",
    ["glass-brightosd"]  = "^(brightness_osd)$",
    ["glass-master"]     = "^(qs-master)$",
    ["glass-orb"]        = "^(desk-orb)$",
    ["glass-popups"]     = "^(qs-popups)$",
    ["glass-floating"]   = "^(qs-floating-overlay)$",
    ["glass-screenshot"] = "^(qs-screenshot-overlay)$",
}

for name, namespace in pairs(GLASS) do
    hl.layer_rule({
        name  = name,
        match = { namespace = namespace },
        blur         = true,
        ignore_alpha = 0.1,
    })
end

-- ─────────────────────────────
-- Window rules
-- ─────────────────────────────

-- ───────── App Launcher ─────────
hl.window_rule({
    name  = "app_launcher",
    match = { title = "^(app-launcher)$" },
    float     = true,
    center    = true,
    size      = "1200 600",
    animation = "slide",
})

-- ───────── MASTER QUICKSHELL CONTAINER ─────────
hl.window_rule({
    name  = "master_rule",
    match = { title = "^(qs-master)$" },
    float            = true,
    no_shadow        = true,
    no_initial_focus = true,
})

-- ───────── App transparency ─────────
hl.window_rule({
    name  = "spotify_opacity",
    match = { class = "^(spotify)$" },
    opacity = "0.70 0.60",
})

hl.window_rule({
    name  = "vesktop_opacity",
    match = { class = "^(vesktop)$" },
    opacity = "0.70 0.60",
})
