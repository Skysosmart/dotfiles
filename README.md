# dotfiles

My Arch Linux setup - a riced **Hyprland** + **quickshell** (Serpantinum) desktop with a Liquid-Glass theme, managed with [GNU stow](https://www.gnu.org/software/stow/).

## What's here

| Package | Contents |
|---------|----------|
| `hypr` | Hyprland Lua config (`hyprland.lua` + `config/*.lua`) |
| `serpantinum` | [Serpantinum](https://github.com/ilyamiro/serpantinum) shell: `~/.config/serpantinum/settings.json` + customized source in `~/.local/share/serpantinum` (Thai translation, Save button in settings, credits removed, Howdy face-unlock arming; fonts/sounds not tracked — run the upstream installer first) |
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
  The committed `serpantinum/settings.json` has the auto-detected `general.location`
  block (public IP + coordinates) stripped; the shell re-detects it.
- Serpantinum's bundled fonts and sounds (~160 MB) are gitignored; run the
  upstream installer first, then stow this package over it.
- `serpantinum/.local/share/serpantinum/patches/howdy-lock.patch` holds the
  Howdy face-unlock changes to `lock/Lock.qml` on their own, against the
  pristine upstream file kept beside it as `Lock.qml.pre-howdy-baseline`.
  The vendored `Lock.qml` already includes them — the patch is for *after an
  upstream upgrade*, when the tracked copy is based on an older Serpantinum:

  ```bash
  cd ~/.local/share/serpantinum
  patch -p1 --dry-run < ~/dotfiles/serpantinum/.local/share/serpantinum/patches/howdy-lock.patch
  ```

  Stock `Lock.qml` starts PAM the instant the screen locks, so with
  `pam_howdy` the webcam scans an empty desk; the patch stays idle until a key
  press or click signals you are there. Note QML allows only **one** handler
  per signal — a second `onInputActiveChanged` makes the whole shell fail to
  load (no bar, no wallpaper), so merge into the existing handler.
