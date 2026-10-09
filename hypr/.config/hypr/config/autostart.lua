hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  hl.exec_cmd("systemctl --user enable --now easyeffects")
  hl.exec_cmd("serpantinumd start")
  hl.exec_cmd("blueman-applet")   -- Bluetooth pairing agent; the shell panel pairs via Quickshell, which has none
  hl.exec_cmd("/home/zaru/.local/bin/sober-antiafk --wait 300")   -- Roblox anti-AFK; waits for Sober
  hl.exec_cmd("/home/zaru/.local/bin/canva-pinch-zoom")   -- smooth pinch-zoom for Canva (Wine has no pinch)
end)
