#!/usr/bin/env bash
# Restore this Arch Linux setup on a fresh machine.
#   1. Installs packages from packages/ (official repos + AUR via yay)
#   2. Symlinks all configs into place with GNU stow
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

echo "==> Dotfiles: $DOTFILES_DIR"

# --- 1. packages ---------------------------------------------------------
if command -v pacman >/dev/null 2>&1; then
  read -rp "Install packages from packages/pkglist-*.txt? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    sudo pacman -S --needed - < packages/pkglist-explicit.txt || true
    if command -v yay >/dev/null 2>&1; then
      yay -S --needed - < packages/pkglist-aur.txt || true
    else
      echo "!! yay not found; skipping AUR packages (packages/pkglist-aur.txt)"
    fi
  fi
fi

# --- 2. stow symlinks ----------------------------------------------------
if ! command -v stow >/dev/null 2>&1; then
  echo "==> Installing GNU stow"
  sudo pacman -S --needed stow
fi

# Every top-level dir except packages/ is a stow package.
packages=()
for d in */; do
  d="${d%/}"
  [[ "$d" == "packages" ]] && continue
  packages+=("$d")
done

echo "==> Stowing: ${packages[*]}"
# --adopt would pull existing files INTO the repo; we want the repo to win,
# so back up conflicts and restow.
for p in "${packages[@]}"; do
  stow -v --target="$HOME" --restow "$p" || {
    echo "!! conflict in '$p' — resolve manually or move the existing file aside, then re-run"
  }
done

echo "==> Done. Restart the shell / Hyprland session to apply."
