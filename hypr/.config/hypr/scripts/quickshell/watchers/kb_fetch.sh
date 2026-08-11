#!/usr/bin/env bash
source "$HOME/.config/hypr/scripts/compositor.sh"
layout=$(comp_kb_layout | head -n1)
[[ -z "$layout" || "$layout" == "null" ]] && layout="US"
echo "${layout:0:2}" | tr '[:lower:]' '[:upper:]'
