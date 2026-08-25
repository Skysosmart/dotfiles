#!/usr/bin/env bash
# Verify every key we declare is live with the declared value, and that
# apply.sh is idempotent. Reports unmanaged keys as info, not failure.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HERE/subtrees.list"
DCONF_D="$HERE/dconf.d"

fail=0

echo "==> checking declared keys are live"
while read -r file path; do
    [[ -z "${file:-}" || "$file" == \#* ]] && continue
    declared="$DCONF_D/$file"
    [[ -r "$declared" ]] || continue
    live=$(mktemp)
    dconf dump "$path" > "$live"
    if ! python3 - "$declared" "$live" "$file" <<'PY'
import configparser, sys
def load(p):
    c = configparser.ConfigParser(delimiters=('=',), interpolation=None)
    c.optionxform = str
    c.read(p, encoding='utf-8')
    return {(s, k): v for s in c.sections() for k, v in c.items(s)}
declared, live, name = load(sys.argv[1]), load(sys.argv[2]), sys.argv[3]
bad = [(s, k, v, live.get((s, k))) for (s, k), v in declared.items() if live.get((s, k)) != v]
for s, k, want, got in bad:
    print("    MISMATCH %s [%s] %s: declared %r, live %r" % (name, s, k, want, got))
extra = [(s, k) for (s, k) in live if (s, k) not in declared]
for s, k in extra:
    print("    unmanaged %s [%s] %s" % (name, s, k))
sys.exit(1 if bad else 0)
PY
    then fail=$((fail+1)); fi
    rm -f "$live"
done < "$MANIFEST"

echo "==> checking apply.sh is idempotent"
# NB: do not name the loop variable `_` - it is a special bash variable and
# reading `$_` back inside the loop does not give you the filename.
snapshot() {
    while read -r file path; do
        [[ -z "${file:-}" || "$file" == \#* ]] && continue
        dconf dump "$path"
    done < "$MANIFEST"
}
before=$(mktemp); after=$(mktemp)
snapshot > "$before"
"$HERE/apply.sh" >/dev/null
snapshot > "$after"
if diff -q "$before" "$after" >/dev/null; then
    echo "    ok: re-applying changed nothing"
else
    echo "    FAIL: apply.sh is not idempotent"; diff "$before" "$after" || true; fail=$((fail+1))
fi
rm -f "$before" "$after"

if [[ "$fail" -eq 0 ]]; then
    echo "==> selftest PASSED"
else
    echo "==> selftest FAILED ($fail)"
    exit 1
fi
