#!/usr/bin/env bash
# Load the GNOME rice config into the live session. Idempotent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HERE/subtrees.list"
DCONF_D="$HERE/dconf.d"
KEYS="$HERE/keys.conf"

[[ -r "$MANIFEST" ]] || { echo "!! missing manifest: $MANIFEST" >&2; exit 1; }

echo "==> loading dconf subtrees"
while read -r file path; do
    [[ -z "${file:-}" || "$file" == \#* ]] && continue
    src="$DCONF_D/$file"
    [[ -r "$src" ]] || { echo "!! missing keyfile: $src" >&2; exit 1; }
    dconf load "$path" < "$src"
    printf '    %-30s -> %s\n' "$file" "$path"
done < "$MANIFEST"

if [[ -r "$KEYS" ]]; then
    echo "==> writing individual keys"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        key="${line%%=*}"
        val="${line#*=}"
        dconf write "$key" "$val"
        printf '    %s\n' "$key"
    done < "$KEYS"
fi

# An extension listed but not installed fails silently at login, so say so now.
echo "==> checking declared extensions are installed"
enabled=$(dconf read /org/gnome/shell/enabled-extensions 2>/dev/null || true)
missing=0
for uuid in $(printf '%s' "$enabled" | grep -oE "[A-Za-z0-9@._-]+@[A-Za-z0-9@._-]+" || true); do
    if [[ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]] \
    || [[ -d "/usr/share/gnome-shell/extensions/$uuid" ]]; then
        printf '    ok      %s\n' "$uuid"
    else
        printf '    MISSING %s\n' "$uuid" >&2
        missing=$((missing+1))
    fi
done
[[ "$missing" -eq 0 ]] || { echo "!! $missing extension(s) not installed - run ./bootstrap.sh" >&2; exit 1; }

echo "==> done. Log out and back in for shell changes to take effect."
