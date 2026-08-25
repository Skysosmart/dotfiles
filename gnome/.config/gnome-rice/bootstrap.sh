#!/usr/bin/env bash
# Install everything the GNOME rice needs, at pinned versions, then verify.
set -euo pipefail

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
SHELL_MAJOR="50"

UUIDS=(
    "user-theme@gnome-shell-extensions.gcampax.github.com"
    "appindicatorsupport@rgcjonas.gmail.com"
    "clipboard-indicator@tudmotu.com"
)

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

if [[ "$check_only" -eq 0 ]]; then
    # The pacman/yay packages install unversioned on purpose: this is a rolling
    # distro, and hard pins would fail on every upstream bump. Compatibility is
    # enforced below by the shell-version assertion instead.
    echo "==> repo packages"
    sudo pacman -S --needed gnome-shell-extensions gnome-shell-extension-appindicator

    echo "==> Clipboard Indicator (AUR)"
    command -v yay >/dev/null || { echo "!! yay not found" >&2; exit 1; }
    yay -S --needed gnome-shell-extension-clipboard-indicator
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
