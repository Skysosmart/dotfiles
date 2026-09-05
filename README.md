# dotfiles

My Arch Linux setup — a riced **Hyprland** + **quickshell** (Serpantinum) desktop with a Liquid-Glass theme, managed with [GNU stow](https://www.gnu.org/software/stow/).

## What's here

| Package | Contents |
|---------|----------|
| `hypr` | Hyprland Lua config (`hyprland.lua` + `config/*.lua`) |
| `serpantinum` | [Serpantinum](https://github.com/ilyamiro/serpantinum) shell: `~/.config/serpantinum/settings.json` + customized source in `~/.local/share/serpantinum` (Thai translation, Save button in settings, credits removed; fonts/sounds not tracked — run the upstream installer first) |
| `quickshell` | quickshell `ii` shell (QML widgets, services, assets) |
| `illogical-impulse` | shell `config.json` / settings |
| `kitty` | kitty terminal |
| `nvim` | Neovim |
| `cava`, `fastfetch`, `foot`, `fuzzel`, `wlogout`, `swayosd`, `mpv`, `easyeffects`, `matugen`, `kde-material-you-colors` | per-app configs |
| `gtk` / `qt` | GTK & Qt theming (Kvantum, qt5ct/qt6ct) |
| `xdg-misc` | starship, fontconfig, mimeapps, app `*-flags.conf`, kde globals |
| `zsh`, `zshrc.d`, `shell` | zsh config + home shell rc files (`.zshrc`, `.bashrc`, …) |
| `git` | `.gitconfig` |
| `packages` | `pacman -Qqe` (explicit) and `pacman -Qqm` (AUR) package lists |

## Fresh install

```bash
git clone <this-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh          # installs packages, then stows everything
```

## Manual stow

```bash
cd ~/dotfiles
stow */               # link everything (except packages/)
stow kitty nvim hypr  # or just specific packages
stow -D kitty         # remove a package's symlinks
```

If stow reports a conflict, the target file already exists — move it aside
(`mv ~/.config/kitty ~/.config/kitty.bak`) and re-run.

## Notes

- Secrets, tokens, browser/app state and caches are intentionally **not** tracked.
  AI features (e.g. OpenRouter/Gemini in the quickshell sidebar) read their keys
  from the system keyring / env vars, not from these files.
- The 23 MB of quickshell `guide/previews` screenshots are gitignored; the shell
  regenerates them.
