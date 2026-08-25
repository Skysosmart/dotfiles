#!/bin/bash

# Cycle focus to the next monitor
source "$(dirname "${BASH_SOURCE[0]}")/compositor.sh"
comp_dispatch focusmonitor "+1"

# Get the newly focused monitor's geometry
monitor=$(hyprctl monitors -j | jq '.[] | select(.focused == true)')
x=$(echo "$monitor" | jq '.x + (.width / 2 / .scale)' | bc)
y=$(echo "$monitor" | jq '.y + (.height / 2 / .scale)' | bc)

# Move cursor to the center of that monitor
comp_dispatch movecursor "$x $y"
