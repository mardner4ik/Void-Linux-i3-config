#!/bin/bash
# Watches battery charge in the background and warns when it's low.
# On desktops without a battery this exits immediately — harmless.

BAT=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' 2>/dev/null | head -n1)
[ -z "$BAT" ] && exit 0

LAST_WARN=""

while true; do
    CAP=$(cat "$BAT/capacity" 2>/dev/null)
    STATUS=$(cat "$BAT/status" 2>/dev/null)

    if [ "$STATUS" = "Discharging" ]; then
        if [ -n "$CAP" ] && [ "$CAP" -le 5 ] && [ "$LAST_WARN" != "critical" ]; then
            dunstify -u critical -a "battery" "🪫 Critically low battery (${CAP}%)" "Plug in the charger now!"
            LAST_WARN="critical"
        elif [ -n "$CAP" ] && [ "$CAP" -le 15 ] && [ "$LAST_WARN" != "low" ]; then
            dunstify -u normal -a "battery" "🔋 Low battery (${CAP}%)" "Consider plugging in the charger"
            LAST_WARN="low"
        fi
    else
        LAST_WARN=""
    fi

    sleep 60
done
