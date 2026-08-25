#!/usr/bin/env bash
# Install everything the GNOME rice needs, at pinned versions, then verify.
set -euo pipefail

PAPERWM_TAG="v50.0.1"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
SHELL_MAJOR="50"

UUIDS=(
    "paperwm@paperwm.github.com"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "appindicatorsupport@rgcjonas.gmail.com"
    "clipboard-indicator@tudmotu.com"
)

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

if [[ "$check_only" -eq 0 ]]; then
    echo "==> repo packages"
    sudo pacman -S --needed gnome-shell-extensions gnome-shell-extension-appindicator

    echo "==> Clipboard Indicator (AUR)"
    command -v yay >/dev/null || { echo "!! yay not found" >&2; exit 1; }
    yay -S --needed gnome-shell-extension-clipboard-indicator

    echo "==> PaperWM $PAPERWM_TAG (upstream; the AUR -git package is stuck at v47)"
    mkdir -p "$EXT_DIR"
    target="$EXT_DIR/paperwm@paperwm.github.com"
    if [[ -d "$target/.git" ]]; then
        git -C "$target" fetch --tags --depth 1 origin "$PAPERWM_TAG"
    else
        rm -rf "$target"
        git clone --depth 1 --branch "$PAPERWM_TAG" \
            https://github.com/paperwm/PaperWM.git "$target"
    fi
    git -C "$target" checkout --detach "$PAPERWM_TAG"
fi

echo "==> verifying installed extensions"
fail=0
for uuid in "${UUIDS[@]}"; do
    meta=""
    for base in "$EXT_DIR" /usr/share/gnome-shell/extensions; do
        [[ -r "$base/$uuid/metadata.json" ]] && { meta="$base/$uuid/metadata.json"; break; }
    done
    if [[ -z "$meta" ]]; then
        printf '    MISSING  %s\n' "$uuid" >&2; fail=$((fail+1)); continue
    fi
    if python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
sys.exit(0 if '$SHELL_MAJOR' in [str(x) for x in d.get('shell-version',[])] else 1)" "$meta"; then
        printf '    ok       %s\n' "$uuid"
    else
        printf '    NO GNOME %s  (%s does not declare shell-version %s)\n' \
            "$uuid" "$meta" "$SHELL_MAJOR" >&2
        fail=$((fail+1))
    fi
done

[[ "$fail" -eq 0 ]] || { echo "!! $fail extension problem(s)" >&2; exit 1; }
echo "==> all ${#UUIDS[@]} extensions present and GNOME $SHELL_MAJOR compatible"
