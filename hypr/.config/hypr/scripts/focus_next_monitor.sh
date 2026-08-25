#!/bin/bash

# Cycle focus to the next monitor
if [[ -n "$NIRI_SOCKET" ]]; then
    # Niri handles cursor placement on focus change itself
    niri msg action focus-monitor-next
    exit 0
fi

source "$(dirname "${BASH_SOURCE[0]}")/compositor.sh"
comp_dispatch focusmonitor "+1"

# Get the newly focused monitor's geometry
monitor=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
x=$(echo "$monitor" | jq '.x + (.width / 2 / .scale)' | bc)
y=$(echo "$monitor" | jq '.y + (.height / 2 / .scale)' | bc)

# Move cursor to the center of that monitor
comp_dispatch movecursor "$x $y"
