#!/bin/bash
# Volume control via pamixer (PipeWire) — works regardless of sound card number.

case "$1" in
    up)   pamixer -i 5 --allow-boost ;;
    down) pamixer -d 5 ;;
    mute) pamixer -t ;;
esac

VOL=$(pamixer --get-volume 2>/dev/null)
MUTED=$(pamixer --get-mute 2>/dev/null)

if [ "$MUTED" = "true" ]; then
    dunstify -a "volume" -u low -i audio-volume-muted \
        -h string:x-dunst-stack-tag:volume \
        "🔇 Muted"
else
    dunstify -a "volume" -u low -i audio-volume-high \
        -h "int:value:${VOL}" -h string:x-dunst-stack-tag:volume \
        "🔊 Volume: ${VOL}%"
fi
