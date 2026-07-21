#!/bin/bash
# Toggle microphone mute/unmute via pamixer (PipeWire).

pamixer --default-source -t

MUTED=$(pamixer --default-source --get-mute 2>/dev/null)

if [ "$MUTED" = "true" ]; then
    dunstify -a "mic" -u low -i microphone-sensitivity-muted \
        -h string:x-dunst-stack-tag:mic \
        "🔇 Microphone muted"
else
    dunstify -a "mic" -u low -i microphone-sensitivity-high \
        -h string:x-dunst-stack-tag:mic \
        "🎙️ Microphone unmuted"
fi
