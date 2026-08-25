# GNOME 50 Rice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a self-contained `gnome/` stow package that turns the GNOME 50 session into a minimal, keyboard-driven, PaperWM-tiled desktop with ~30 keybinds ported from the niri layout — touching nothing belonging to the Hyprland rice.

**Architecture:** GNOME config lives in dconf, which stow cannot manage. The package therefore stores plain-text keyfiles under `dconf.d/`, one per **non-overlapping** dconf subtree, plus a `keys.conf` for two individual keys whose parent directories are too broad to dump safely. `apply.sh` loads them, `dump.sh` writes live state back, `selftest.sh` proves the two agree. Extensions install out-of-repo at pinned versions; `bootstrap.sh` asserts each declares shell-version 50.

**Tech Stack:** bash, GNU stow 2.4.1, dconf/gsettings, GNOME Shell 50.4, PaperWM v50.0.1, shellcheck 0.11.0, python3 (for the selftest comparator).

**Spec:** `docs/superpowers/specs/2026-08-25-gnome-rice-design.md`

## Global Constraints

- Repo is `/home/zaru/dotfiles`, currently on branch **`remove-niri`**. Do not check out `main` — it lacks the Lua-migration snapshot and the working tree is symlinked live into `~/.config`, so switching would break the running Hyprland config.
- **Touch nothing under `hypr/`, `matugen/`, or `quickshell/`.** Not one file. This rice is independent by design.
- Every script starts `#!/usr/bin/env bash` + `set -euo pipefail`, matching `install.sh`.
- Every script must pass `shellcheck` and `bash -n` before its task is committed.
- Shell theme name is exactly **`Zaru-Dark`**.
- Terminal is **`kitty`**. Browser is **`firefox`**. File manager is **`nautilus`**.
- Extension pins: PaperWM **`v50.0.1`**, Clipboard Indicator AUR **`71-1`**, `gnome-shell-extensions` **`50.3-1`**, `gnome-shell-extension-appindicator` **`1:65-1`**.
- Extension UUIDs (exact strings):
  - `paperwm@paperwm.github.com`
  - `user-theme@gnome-shell-extensions.gcampax.github.com`
  - `appindicatorsupport@rgcjonas.gmail.com`
  - `clipboard-indicator@tudmotu.com`
- `dconf load` **merges** — it does not reset the target path. Clearing a GNOME default therefore requires writing an explicit empty value `@as []`, never omitting the key.

## File Structure

```
gnome/.config/gnome-rice/
├── subtrees.list                    # file <-> dconf path manifest; apply+dump both read it
├── keys.conf                        # individual keys whose parent dir is too broad to dump
├── apply.sh                         # load dconf.d + keys.conf into the live session
├── dump.sh                          # live session -> dconf.d + keys.conf
├── selftest.sh                      # managed-key verification + idempotence
├── bootstrap.sh                     # packages, pinned extensions, shell-version assertions
├── README.md
└── dconf.d/
    ├── 10-interface.ini             # /org/gnome/desktop/interface/
    ├── 15-background.ini            # /org/gnome/desktop/background/
    ├── 20-wm-preferences.ini        # /org/gnome/desktop/wm/preferences/
    ├── 30-wm-keybindings.ini        # /org/gnome/desktop/wm/keybindings/
    ├── 40-shell-keybindings.ini     # /org/gnome/shell/keybindings/
    ├── 45-mutter-keybindings.ini    # /org/gnome/mutter/keybindings/
    ├── 50-media-keys.ini            # /org/gnome/settings-daemon/plugins/media-keys/
    ├── 70-paperwm.ini               # /org/gnome/shell/extensions/paperwm/keybindings/
    ├── 75-user-theme.ini            # /org/gnome/shell/extensions/user-theme/
    └── 80-clipboard.ini             # /org/gnome/shell/extensions/clipboard-indicator/
gnome/.themes/Zaru-Dark/gnome-shell/gnome-shell.css
```

**Why these subtrees:** they are mutually non-overlapping. `/org/gnome/shell/` is deliberately *absent* — dumping it would sweep up `favorite-apps`, `welcome-dialog-last-shown-version` and `command-history`, which would churn in git on every login. Its one key we care about (`enabled-extensions`) lives in `keys.conf` instead. Same reasoning for `/org/gnome/mutter/` vs `dynamic-workspaces`.

---

### Task 1: Manifest and README

**Files:**
- Create: `gnome/.config/gnome-rice/subtrees.list`
- Create: `gnome/.config/gnome-rice/README.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `subtrees.list`, a whitespace-separated `<filename> <dconf-path>` table read by `apply.sh`, `dump.sh` and `selftest.sh`. Lines beginning `#` and blank lines are comments. Every path starts and ends with `/`.

- [ ] **Step 1: Write the failing check**

Create `/tmp/check-manifest.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
M="$HOME/dotfiles/gnome/.config/gnome-rice/subtrees.list"
[[ -r "$M" ]] || { echo "FAIL: no manifest at $M"; exit 1; }
n=0
while read -r file path; do
    [[ -z "${file:-}" || "$file" == \#* ]] && continue
    [[ "$path" == /* && "$path" == */ ]] || { echo "FAIL: bad path '$path'"; exit 1; }
    [[ "$file" == *.ini ]] || { echo "FAIL: bad filename '$file'"; exit 1; }
    n=$((n+1))
done < "$M"
[[ "$n" -eq 10 ]] || { echo "FAIL: expected 10 subtrees, got $n"; exit 1; }
echo "PASS: $n subtrees, all well-formed"
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `bash /tmp/check-manifest.sh`
Expected: `FAIL: no manifest at /home/zaru/dotfiles/gnome/.config/gnome-rice/subtrees.list`

- [ ] **Step 3: Create the manifest**

`gnome/.config/gnome-rice/subtrees.list`:

```
# <keyfile in dconf.d/>        <dconf subtree>
# Subtrees MUST NOT overlap - dump.sh would duplicate keys between files.
10-interface.ini               /org/gnome/desktop/interface/
15-background.ini              /org/gnome/desktop/background/
20-wm-preferences.ini          /org/gnome/desktop/wm/preferences/
30-wm-keybindings.ini          /org/gnome/desktop/wm/keybindings/
40-shell-keybindings.ini       /org/gnome/shell/keybindings/
45-mutter-keybindings.ini      /org/gnome/mutter/keybindings/
50-media-keys.ini              /org/gnome/settings-daemon/plugins/media-keys/
70-paperwm.ini                 /org/gnome/shell/extensions/paperwm/keybindings/
75-user-theme.ini              /org/gnome/shell/extensions/user-theme/
80-clipboard.ini               /org/gnome/shell/extensions/clipboard-indicator/
```

- [ ] **Step 4: Write the README**

`gnome/.config/gnome-rice/README.md`:

```markdown
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
```

- [ ] **Step 5: Run the check to verify it passes**

Run: `bash /tmp/check-manifest.sh`
Expected: `PASS: 10 subtrees, all well-formed`

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/subtrees.list gnome/.config/gnome-rice/README.md
git commit -m "gnome: add gnome-rice package manifest and README"
```

---

### Task 2: apply.sh, dump.sh and selftest.sh

**Files:**
- Create: `gnome/.config/gnome-rice/apply.sh`
- Create: `gnome/.config/gnome-rice/dump.sh`
- Create: `gnome/.config/gnome-rice/selftest.sh`

**Interfaces:**
- Consumes: `subtrees.list` from Task 1.
- Produces: `apply.sh` (loads `dconf.d/*.ini` per subtree, then `keys.conf`, then verifies every UUID in `enabled-extensions` is installed); `dump.sh` (inverse); `selftest.sh` (exit 0 = every managed key present with the declared value, and `apply.sh` is idempotent). All three take no arguments.

Note: these are written *before* the config data, so Task 2 tests them against a temporary fixture. Tasks 4–7 then supply the real keyfiles.

- [ ] **Step 1: Write apply.sh**

```bash
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
```

- [ ] **Step 2: Write dump.sh**

```bash
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
```

- [ ] **Step 3: Write selftest.sh**

```bash
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

[[ "$fail" -eq 0 ]] && echo "==> selftest PASSED" || { echo "==> selftest FAILED ($fail)"; exit 1; }
```

- [ ] **Step 4: Make executable and run the static gate — expect it to fail on missing keyfiles**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
chmod +x apply.sh dump.sh selftest.sh
bash -n apply.sh dump.sh selftest.sh && shellcheck apply.sh dump.sh selftest.sh
./apply.sh
```
Expected: shellcheck clean; `apply.sh` exits 1 with `!! missing keyfile: .../dconf.d/10-interface.ini`.

- [ ] **Step 5: Prove the machinery works against a temporary fixture**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
mkdir -p dconf.d
# capture the CURRENT live state into every keyfile, so apply.sh is a no-op
./dump.sh
./apply.sh
./selftest.sh
```
Expected: `dump.sh` writes 10 files. `apply.sh` then succeeds — at this point `enabled-extensions` is still empty (`@as []`), so the extension loop iterates zero times and nothing is reported MISSING. `selftest.sh` reports `==> selftest PASSED`, because dump-then-apply is by construction a no-op.

This proves the machinery round-trips before any real config exists. Task 3 installs the extensions; Task 4 is what first makes `apply.sh` assert against them.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/apply.sh gnome/.config/gnome-rice/dump.sh gnome/.config/gnome-rice/selftest.sh
git commit -m "gnome: add apply/dump/selftest machinery for the dconf config"
```

---

### Task 3: bootstrap.sh

**Files:**
- Create: `gnome/.config/gnome-rice/bootstrap.sh`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `bootstrap.sh`, which installs the two repo extensions via pacman, PaperWM from upstream at tag `v50.0.1`, Clipboard Indicator via yay at `71-1`, then asserts each of the four UUIDs is installed **and** declares shell-version `50`. Accepts `--check` to run only the assertions.

- [ ] **Step 1: Write the failing assertion run**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
./bootstrap.sh --check
```
Expected: `bash: ./bootstrap.sh: No such file or directory`

- [ ] **Step 2: Write bootstrap.sh**

```bash
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
```

- [ ] **Step 3: Static gate**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
chmod +x bootstrap.sh
bash -n bootstrap.sh && shellcheck bootstrap.sh
```
Expected: both clean.

- [ ] **Step 4: Run it for real, then verify**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
./bootstrap.sh
./bootstrap.sh --check
```
Expected: final line `==> all 4 extensions present and GNOME 50 compatible`. `sudo` will prompt for a password — that is expected and must be entered by the user.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/bootstrap.sh
git commit -m "gnome: add bootstrap.sh with pinned extensions and shell-version assertions"
```

---

### Task 4: Appearance, workspaces and enabled extensions

**Files:**
- Create: `gnome/.config/gnome-rice/dconf.d/10-interface.ini`
- Create: `gnome/.config/gnome-rice/dconf.d/15-background.ini`
- Create: `gnome/.config/gnome-rice/dconf.d/20-wm-preferences.ini`
- Create: `gnome/.config/gnome-rice/keys.conf`

**Interfaces:**
- Consumes: `apply.sh`/`selftest.sh` (Task 2), installed extensions (Task 3).
- Produces: the four UUIDs live in `enabled-extensions`; workspaces become static and number 9.

- [ ] **Step 1: Write the failing check**

```bash
dconf read /org/gnome/mutter/dynamic-workspaces
dconf read /org/gnome/desktop/wm/preferences/num-workspaces
```
Expected: empty output for both (unset = GNOME defaults: dynamic workspaces, 4 static). This is the bug being fixed — with dynamic workspaces, `Super+5` on an empty desktop does nothing.

- [ ] **Step 2: Write 10-interface.ini**

These match the values already live, so GTK apps do not shift when the rice is applied:

```ini
[/]
color-scheme='prefer-dark'
gtk-theme='adw-gtk3-dark'
icon-theme='WhiteSur-dark'
cursor-theme='Bibata-Modern-Ice'
font-name='Roboto Flex 11'
```

- [ ] **Step 3: Write 15-background.ini**

```ini
[/]
picture-uri='file:///usr/share/backgrounds/gnome/adwaita-d.jxl'
picture-uri-dark='file:///usr/share/backgrounds/gnome/adwaita-d.jxl'
picture-options='zoom'
```

- [ ] **Step 4: Write 20-wm-preferences.ini**

```ini
[/]
num-workspaces=9
```

- [ ] **Step 5: Write keys.conf**

```
# Individual keys whose parent dconf directory is too broad to dump safely.
# dump.sh refreshes these values but never adds names - add new lines by hand.
/org/gnome/shell/enabled-extensions=['paperwm@paperwm.github.com', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'appindicatorsupport@rgcjonas.gmail.com', 'clipboard-indicator@tudmotu.com']
/org/gnome/mutter/dynamic-workspaces=false
```

- [ ] **Step 6: Apply and verify**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
./apply.sh
dconf read /org/gnome/mutter/dynamic-workspaces
dconf read /org/gnome/desktop/wm/preferences/num-workspaces
```
Expected: `apply.sh` ends with all four extensions `ok`; the two reads print `false` and `9`.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/dconf.d/10-interface.ini \
        gnome/.config/gnome-rice/dconf.d/15-background.ini \
        gnome/.config/gnome-rice/dconf.d/20-wm-preferences.ini \
        gnome/.config/gnome-rice/keys.conf
git commit -m "gnome: appearance, 9 static workspaces, enable the four extensions"
```

---

### Task 5: PaperWM keybindings

**Files:**
- Create: `gnome/.config/gnome-rice/dconf.d/70-paperwm.ini`

**Interfaces:**
- Consumes: PaperWM installed (Task 3), `apply.sh` (Task 2).
- Produces: the full scrolling-tiler bind set. Later tasks must not bind `Super+r`, `Super+c`, `Super+d`, `Super+a`, `Super+[`, `Super+]`, `Super+-`, `Super+=`, or `Super`+arrow combinations.

- [ ] **Step 1: Write the failing check**

```bash
dconf read /org/gnome/shell/extensions/paperwm/keybindings/toggle-maximize-width
```
Expected: empty (unset — PaperWM's built-in default `<Super>f` applies, which collides with launching firefox).

- [ ] **Step 2: Write 70-paperwm.ini**

```ini
[/]
switch-left=['<Super>Left', '<Super>h']
switch-right=['<Super>Right']
switch-up=['<Super>Up', '<Super>k']
switch-down=['<Super>Down', '<Super>j']
switch-first=['<Super>Home']
switch-last=['<Super>End']
move-left=['<Super><Shift>Left', '<Super><Shift>h']
move-right=['<Super><Shift>Right', '<Super><Shift>l']
move-up=['<Super><Shift>Up', '<Super><Shift>k']
move-down=['<Super><Shift>Down', '<Super><Shift>j']
switch-monitor-left=['<Super><Ctrl>Left']
switch-monitor-right=['<Super><Ctrl>Right']
switch-monitor-above=['<Super><Ctrl>Up']
switch-monitor-below=['<Super><Ctrl>Down']
move-monitor-left=['<Super><Ctrl><Shift>Left']
move-monitor-right=['<Super><Ctrl><Shift>Right']
move-monitor-above=['<Super><Ctrl><Shift>Up']
move-monitor-below=['<Super><Ctrl><Shift>Down']
switch-up-workspace=['<Super>Page_Up']
switch-down-workspace=['<Super>Page_Down']
move-up-workspace=['<Super><Ctrl>Page_Up']
move-down-workspace=['<Super><Ctrl>Page_Down']
cycle-width=['<Super>r']
cycle-height=['<Super><Ctrl>r']
center-horizontally=['<Super>c']
toggle-maximize-width=['<Super>d']
paper-toggle-fullscreen=['<Super><Shift>f']
resize-w-dec=['<Super>minus']
resize-w-inc=['<Super>equal']
resize-h-dec=['<Super><Shift>minus']
resize-h-inc=['<Super><Shift>plus']
slurp-in=['<Super>bracketleft']
barf-out=['<Super>bracketright']
toggle-scratch-window=['<Super>a']
toggle-scratch=['<Super><Shift>v']
new-window=@as []
take-window=@as []
close-window=@as []
```

`new-window`, `take-window` and `close-window` are cleared so `Super+Return`, `Super+t` and window-closing belong to the launcher and GNOME WM bindings instead — one owner per key.

**`Super+l` is deliberately absent.** It stays bound to lock (Task 7), matching the explicit note in the niri config. The vim focus row is `h`/`j`/`k` only; this asymmetry is intentional.

- [ ] **Step 3: Apply and verify**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
./apply.sh
dconf read /org/gnome/shell/extensions/paperwm/keybindings/toggle-maximize-width
dconf read /org/gnome/shell/extensions/paperwm/keybindings/new-window
```
Expected: `['<Super>d']` and `@as []`.

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/dconf.d/70-paperwm.ini
git commit -m "gnome: PaperWM keybinds at niri parity, six conflicts resolved"
```

---

### Task 6: GNOME binds and cleared defaults

**Files:**
- Create: `gnome/.config/gnome-rice/dconf.d/30-wm-keybindings.ini`
- Create: `gnome/.config/gnome-rice/dconf.d/40-shell-keybindings.ini`
- Create: `gnome/.config/gnome-rice/dconf.d/45-mutter-keybindings.ini`

**Interfaces:**
- Consumes: `apply.sh` (Task 2). Must not re-bind anything claimed by Task 5.
- Produces: window close, 9 workspace switch + 9 move binds, overview, screenshot, and the eight cleared GNOME defaults.

- [ ] **Step 1: Write the failing check**

```bash
gsettings get org.gnome.shell.keybindings toggle-application-view
gsettings get org.gnome.mutter.keybindings toggle-tiled-left
```
Expected: `['<Super>a']` and `['<Super>Left']` — GNOME's defaults, which currently steal the float-window and focus-column-left binds.

- [ ] **Step 2: Write 30-wm-keybindings.ini**

```ini
[/]
close=['<Super>q', '<Alt>F4']
switch-to-workspace-1=['<Super>1']
switch-to-workspace-2=['<Super>2']
switch-to-workspace-3=['<Super>3']
switch-to-workspace-4=['<Super>4']
switch-to-workspace-5=['<Super>5']
switch-to-workspace-6=['<Super>6']
switch-to-workspace-7=['<Super>7']
switch-to-workspace-8=['<Super>8']
switch-to-workspace-9=['<Super>9']
move-to-workspace-1=['<Super><Ctrl>1']
move-to-workspace-2=['<Super><Ctrl>2']
move-to-workspace-3=['<Super><Ctrl>3']
move-to-workspace-4=['<Super><Ctrl>4']
move-to-workspace-5=['<Super><Ctrl>5']
move-to-workspace-6=['<Super><Ctrl>6']
move-to-workspace-7=['<Super><Ctrl>7']
move-to-workspace-8=['<Super><Ctrl>8']
move-to-workspace-9=['<Super><Ctrl>9']
minimize=@as []
toggle-maximized=@as []
unmaximize=@as []
maximize=@as []
switch-input-source=@as []
switch-input-source-backward=@as []
```

`switch-input-source` is cleared because it owns `Super+Space` by default. The Thai toggle is `Alt+Shift` and is unaffected.

- [ ] **Step 3: Write 40-shell-keybindings.ini**

```ini
[/]
toggle-overview=['<Super>grave']
show-screenshot-ui=['<Super><Shift>s']
toggle-application-view=@as []
toggle-message-tray=@as []
```

- [ ] **Step 4: Write 45-mutter-keybindings.ini**

```ini
[/]
toggle-tiled-left=@as []
toggle-tiled-right=@as []
```

- [ ] **Step 5: Apply and verify the clears took**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
./apply.sh
gsettings get org.gnome.shell.keybindings toggle-application-view
gsettings get org.gnome.mutter.keybindings toggle-tiled-left
gsettings get org.gnome.desktop.wm.keybindings close
```
Expected: `@as []`, `@as []`, `['<Super>q', '<Alt>F4']`.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/dconf.d/30-wm-keybindings.ini \
        gnome/.config/gnome-rice/dconf.d/40-shell-keybindings.ini \
        gnome/.config/gnome-rice/dconf.d/45-mutter-keybindings.ini
git commit -m "gnome: workspace/close/overview binds and clear 8 colliding defaults"
```

---

### Task 7: Launchers and extension settings

**Files:**
- Create: `gnome/.config/gnome-rice/dconf.d/50-media-keys.ini`
- Create: `gnome/.config/gnome-rice/dconf.d/75-user-theme.ini`
- Create: `gnome/.config/gnome-rice/dconf.d/80-clipboard.ini`

**Interfaces:**
- Consumes: `apply.sh` (Task 2), Clipboard Indicator installed (Task 3).
- Produces: four app launchers, lock, logout, clipboard history on `Super+v`, and selects the `Zaru-Dark` shell theme created in Task 8.

- [ ] **Step 1: Write the failing check**

```bash
dconf read /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings
```
Expected: empty (no custom launchers exist yet, so `Super+Return` does nothing).

- [ ] **Step 2: Write 50-media-keys.ini**

GNOME has no first-class "run this command" binding, so each launcher costs three keys under a `customN` subdirectory, plus registration in the `custom-keybindings` list:

```ini
[/]
screensaver=['<Super>l']
logout=['<Super><Shift>e']
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/']

[custom-keybindings/custom0]
name='Terminal'
command='kitty'
binding='<Super>Return'

[custom-keybindings/custom1]
name='Terminal (alt)'
command='kitty'
binding='<Super>t'

[custom-keybindings/custom2]
name='Firefox'
command='firefox'
binding='<Super>f'

[custom-keybindings/custom3]
name='Files'
command='nautilus'
binding='<Super>e'
```

- [ ] **Step 3: Write 75-user-theme.ini**

```ini
[/]
name='Zaru-Dark'
```

- [ ] **Step 4: Write 80-clipboard.ini**

```ini
[/]
enable-keybindings=true
toggle-menu=['<Super>v']
```

- [ ] **Step 5: Apply and verify**

```bash
cd ~/dotfiles/gnome/.config/gnome-rice
./apply.sh
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ | head -20
dconf read /org/gnome/shell/extensions/clipboard-indicator/toggle-menu
```
Expected: four `[custom-keybindings/customN]` sections present; `['<Super>v']`.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add gnome/.config/gnome-rice/dconf.d/50-media-keys.ini \
        gnome/.config/gnome-rice/dconf.d/75-user-theme.ini \
        gnome/.config/gnome-rice/dconf.d/80-clipboard.ini
git commit -m "gnome: app launchers, lock/logout, clipboard history, select Zaru-Dark"
```

---

### Task 8: Zaru-Dark shell theme

**Files:**
- Create: `gnome/.themes/Zaru-Dark/gnome-shell/gnome-shell.css`

**Interfaces:**
- Consumes: User Themes extension (Task 3), `name='Zaru-Dark'` (Task 7).
- Produces: the shell stylesheet. Static, hand-authored, never generated — no matugen template feeds it.

- [ ] **Step 1: Write the failing check**

```bash
gnome-extensions info user-theme@gnome-shell-extensions.gcampax.github.com | grep -i state
ls ~/.themes/Zaru-Dark/gnome-shell/gnome-shell.css
```
Expected: extension `ENABLED`, but `ls` reports no such file — so the theme name is selected with nothing behind it and the shell silently falls back to Adwaita.

- [ ] **Step 2: Write the stylesheet**

Deliberately small: panel, popups, quick settings and the overview backdrop. GNOME churns shell CSS class names between releases, so a small surface is a small thing to repair.

```css
/* Zaru-Dark — GNOME 50 shell theme.
 * Hand-authored and static. Not generated by matugen; the GNOME session is
 * deliberately independent of the Hyprland colour pipeline.
 * Warm accent chosen to sit alongside the shared GTK palette. */

/* ---- palette ---- */
stage {
    /* base #16130f, raised #221d17, accent #ffb59e */
    color: #f2e9e1;
    font-size: 11pt;
}

/* ---- top panel ---- */
#panel {
    background-color: rgba(22, 19, 15, 0.92);
    border-bottom: 1px solid rgba(255, 181, 158, 0.12);
    height: 32px;
}

#panel .panel-button {
    color: #f2e9e1;
    border-radius: 8px;
}

#panel .panel-button:hover {
    background-color: rgba(255, 181, 158, 0.14);
}

#panel .panel-button:active,
#panel .panel-button:checked {
    background-color: rgba(255, 181, 158, 0.24);
    color: #ffd9cb;
}

/* ---- popups & quick settings ---- */
.popup-menu-content,
.quick-settings {
    background-color: rgba(34, 29, 23, 0.97);
    border: 1px solid rgba(255, 181, 158, 0.16);
    border-radius: 14px;
    padding: 6px;
}

.popup-menu-item:hover,
.popup-menu-item:focus {
    background-color: rgba(255, 181, 158, 0.16);
    border-radius: 8px;
}

.quick-toggle:checked,
.quick-menu-toggle:checked {
    background-color: #ffb59e;
    color: #16130f;
}

/* ---- overview ---- */
#overviewGroup {
    background-color: #16130f;
}

.window-picker .window-caption {
    background-color: rgba(34, 29, 23, 0.94);
    color: #f2e9e1;
    border-radius: 8px;
}

/* ---- notifications & osd ---- */
.notification-banner,
.osd-window {
    background-color: rgba(34, 29, 23, 0.97);
    border: 1px solid rgba(255, 181, 158, 0.16);
    border-radius: 14px;
    color: #f2e9e1;
}

/* ---- PaperWM indicators ---- */
.paperwm-selection {
    border: 2px solid #ffb59e;
    border-radius: 10px;
}
```

- [ ] **Step 3: Verify the file is in place and selected**

```bash
ls -l ~/dotfiles/gnome/.themes/Zaru-Dark/gnome-shell/gnome-shell.css
dconf read /org/gnome/shell/extensions/user-theme/name
```
Expected: the file exists; the read prints `'Zaru-Dark'`. (It resolves through the symlink only after Task 9 stows the package.)

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add gnome/.themes/Zaru-Dark/gnome-shell/gnome-shell.css
git commit -m "gnome: add Zaru-Dark shell theme"
```

---

### Task 9: Stow the package and verify end to end

**Files:**
- Modify: none in the repo. This task creates the symlinks and runs full verification.

**Interfaces:**
- Consumes: everything from Tasks 1–8.
- Produces: `~/.config/gnome-rice` and `~/.themes/Zaru-Dark` symlinks, and a passing `selftest.sh`.

- [ ] **Step 1: Confirm nothing is stowed yet**

```bash
ls -ld ~/.config/gnome-rice ~/.themes/Zaru-Dark 2>&1
```
Expected: `No such file or directory` for both.

- [ ] **Step 2: Stow the package**

```bash
cd ~/dotfiles
stow -t ~ gnome -v
ls -ld ~/.config/gnome-rice ~/.themes/Zaru-Dark
```
Expected: both are symlinks into `~/dotfiles/gnome/...`.

- [ ] **Step 3: Run the full verification**

```bash
cd ~/.config/gnome-rice
./bootstrap.sh --check
./selftest.sh
```
Expected: `==> all 4 extensions present and GNOME 50 compatible`, then `==> selftest PASSED`.

- [ ] **Step 4: Confirm dump.sh produces no diff**

```bash
cd ~/.config/gnome-rice
./dump.sh
git -C ~/dotfiles diff --stat gnome/
```
Expected: no changes, or only `unmanaged` keys GNOME set on its own. Any real diff means a declared value did not apply — investigate before continuing.

- [ ] **Step 5: Commit any legitimate dump drift**

```bash
cd ~/dotfiles
git add gnome/
git diff --cached --stat
git commit -m "gnome: capture post-apply dconf state" || echo "nothing to commit - clean"
```

- [ ] **Step 6: Log out and back into GNOME, then verify manually**

This cannot be automated. Log out, log back into the GNOME session, and check:

- [ ] PaperWM is tiling — windows scroll horizontally, never overlap
- [ ] The `Zaru-Dark` panel is dark with the warm accent (not Adwaita grey)
- [ ] `Super`+`Return` and `Super`+`t` open kitty; `Super`+`f` firefox; `Super`+`e` nautilus
- [ ] `Super`+`q` closes; `Super`+`l` locks; `Super`+`Shift`+`e` logs out
- [ ] `Super`+arrows and `Super`+`h`/`j`/`k` move focus; `Super`+`Shift`+arrows move windows
- [ ] `Super`+`1`..`9` switch workspaces, `Super`+`Ctrl`+`1`..`9` move windows to them
- [ ] `Super`+`v` opens clipboard history (NOT the message tray)
- [ ] `Super`+`a` floats a window (NOT the app grid)
- [ ] `Super`+`Left`/`Right` scroll columns (NOT GNOME's half-screen tiling)
- [ ] `Super`+`grave` opens the overview; `Super`+`Shift`+`s` the screenshot UI

- [ ] **Step 7: Report results**

If any bind misbehaves, the cause is almost always a GNOME default that was not cleared. Find the thief with:

```bash
gsettings list-recursively | grep -i "'<Super>x'"
```
replacing `x` with the offending key, then add the clear to the relevant `dconf.d` file and re-apply.
