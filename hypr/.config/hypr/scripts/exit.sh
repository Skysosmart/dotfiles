#!/usr/bin/env bash

systemctl --user stop graphical-session.target
systemctl --user stop graphical-session-pre.target

sleep 0.5

if [[ -n "$NIRI_SOCKET" ]]; then
    niri msg action quit --skip-confirmation
else
    source "$(dirname "${BASH_SOURCE[0]}")/compositor.sh"
    comp_dispatch exit
fi

