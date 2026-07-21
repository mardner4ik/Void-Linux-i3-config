#!/bin/bash
# Screen brightness control via brightnessctl (needs the "video" group, set up by install.sh).

case "$1" in
    up)   brightnessctl set +5% >/dev/null 2>&1 ;;
    down) brightnessctl set 5%- >/dev/null 2>&1 ;;
esac

PERCENT=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
[ -z "$PERCENT" ] && exit 0

dunstify -a "brightness" -u low -i display-brightness-symbolic \
    -h "int:value:${PERCENT}" -h string:x-dunst-stack-tag:brightness \
    "☀️ Brightness: ${PERCENT}%"
