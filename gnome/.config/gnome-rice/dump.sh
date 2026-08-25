#!/usr/bin/env bash
# Capture live GNOME state back into dconf.d/ and keys.conf.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HERE/subtrees.list"
DCONF_D="$HERE/dconf.d"
KEYS="$HERE/keys.conf"

[[ -r "$MANIFEST" ]] || { echo "!! missing manifest: $MANIFEST" >&2; exit 1; }
mkdir -p "$DCONF_D"

echo "==> dumping dconf subtrees"
while read -r file path; do
    [[ -z "${file:-}" || "$file" == \#* ]] && continue
    dconf dump "$path" > "$DCONF_D/$file"
    printf '    %-30s <- %s\n' "$file" "$path"
done < "$MANIFEST"

# Key NAMES come from the existing keys.conf; adding a new one means adding a
# line by hand first. Refresh values only.
if [[ -r "$KEYS" ]]; then
    echo "==> refreshing individual keys"
    tmp=$(mktemp)
    while IFS= read -r line; do
        if [[ -z "$line" || "$line" == \#* ]]; then
            printf '%s\n' "$line" >> "$tmp"
            continue
        fi
        key="${line%%=*}"
        printf '%s=%s\n' "$key" "$(dconf read "$key")" >> "$tmp"
        printf '    %s\n' "$key"
    done < "$KEYS"
    mv "$tmp" "$KEYS"
fi

echo "==> done. Review with: git -C ~/dotfiles diff gnome/"
