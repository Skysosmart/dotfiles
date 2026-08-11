#!/usr/bin/env bash
# Prints the dominant *vivid* colour (#RRGGBB) of the CURRENT wallpaper.
# Works for static (awww) and live/video (mpvpaper) wallpapers. Result is cached
# keyed on the analysed image's mtime, so repeat calls are a cheap `cat`.

SRC_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
LIVE_DIR="${LIVE_WALLPAPER_DIR:-$HOME/Pictures/LiveWallpapers}"
QS_CACHE_DIR="$HOME/.cache/quickshell"
THUMBS="$QS_CACHE_DIR/wallpaper_picker/thumbs"
CACHE="$QS_CACHE_DIR/audioviz"
OUT="$CACHE/dominant_color"
mkdir -p "$CACHE"

emit_cached() { [ -f "$OUT" ] && cat "$OUT"; }

# --- resolve the current wallpaper source -----------------------------------
CURRENT_SRC=""
if pgrep -a mpvpaper >/dev/null 2>&1; then
    CURRENT_SRC=$(pgrep -a mpvpaper | grep -o "$LIVE_DIR/[^' ]*" | head -n1)
elif command -v awww >/dev/null 2>&1; then
    CURRENT_SRC=$(awww query 2>/dev/null | grep -o "$SRC_DIR/[^ ]*" | head -n1)
fi
[ -z "$CURRENT_SRC" ] && { emit_cached; exit 0; }

# --- pick an analysable still ------------------------------------------------
BASE=$(basename "$CURRENT_SRC"); EXT="${BASE##*.}"
if [[ "${EXT,,}" =~ ^(mp4|mkv|mov|webm)$ ]]; then
    IMG="$THUMBS/000_$BASE"                       # reuse the picker's poster frame
    if [ ! -f "$IMG" ]; then
        IMG="$CACHE/frame.jpg"
        ffmpeg -y -nostdin -ss 5 -i "$CURRENT_SRC" -frames:v 1 "$IMG" >/dev/null 2>&1
    fi
else
    IMG="$CURRENT_SRC"
fi
[ -f "$IMG" ] || { emit_cached; exit 0; }

# --- cache check -------------------------------------------------------------
KEY="$IMG:$(stat -c %Y "$IMG" 2>/dev/null)"
if [ -f "$OUT.key" ] && [ "$(cat "$OUT.key")" = "$KEY" ] && [ -f "$OUT" ]; then
    cat "$OUT"; exit 0
fi

# --- quantise + pick the most prevalent vivid colour -------------------------
COLOR=$(magick "$IMG" -resize 160x160 -depth 8 -fuzz 6% -colors 16 \
            -format "%c" histogram:info:- 2>/dev/null | python3 -c '
import sys, re, colorsys
besthsv=None; bestscore=-1.0
for line in sys.stdin:
    m=re.search(r"(\d+):\s*\([^)]*\)\s*#([0-9A-Fa-f]{6})", line)
    if not m: continue
    cnt=int(m.group(1)); hx=m.group(2)
    r=int(hx[0:2],16)/255.0; g=int(hx[2:4],16)/255.0; b=int(hx[4:6],16)/255.0
    h,s,v=colorsys.rgb_to_hsv(r,g,b)
    if v<0.12: continue                         # skip near-black
    w=cnt*(0.06+3.0*s*s)*(0.35+min(v,0.9))      # prevalence, but strongly favour saturated hues
    if w>bestscore: bestscore=w; besthsv=(h,s,v)
if besthsv:
    h,s,v=besthsv
    v=max(v,0.62)                               # keep the ring visible off dark wallpapers
    r,g,b=colorsys.hsv_to_rgb(h,s,v)
    print("#%02X%02X%02X"%(round(r*255),round(g*255),round(b*255)))
')

[ -z "$COLOR" ] && { emit_cached; exit 0; }
printf '%s' "$COLOR" > "$OUT"; printf '%s' "$KEY" > "$OUT.key"
printf '%s' "$COLOR"
