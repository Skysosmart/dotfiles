# gnome-rice

Config for the GNOME 50 session. Independent of the Hyprland rice: nothing here
reads or writes anything under `~/.config/hypr`, and no matugen template feeds it.

## Usage

    ./bootstrap.sh    # once per machine: packages + pinned extensions
    ./apply.sh        # load this config into the live session (idempotent)
    ./dump.sh         # capture live tweaks back into dconf.d/ before committing
    ./selftest.sh     # verify managed keys applied and apply.sh is idempotent

## How it works

`subtrees.list` maps each keyfile in `dconf.d/` to one non-overlapping dconf
subtree. `keys.conf` holds individual keys whose parent directory is too broad to
dump without capturing unrelated state.

`dconf load` MERGES - it never resets a subtree. So clearing a GNOME default
requires an explicit empty value (`key=@as []`), not an omitted key.

## Shared with Hyprland, unavoidably

GTK theming is per-user, not per-session: `~/.config/gtk-{3,4}.0/gtk.css` and the
`org.gnome.desktop.interface` keys are read by every GTK app whichever session
started it. Those stay owned by matugen. This package owns only GNOME's own shell
chrome, its extensions and its keybinds.
