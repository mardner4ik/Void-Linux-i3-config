#!/bin/bash
# ==========================================================
# Clean session exit — bound to Super+Shift+E and used by the
# "Logout" entry in power-menu.sh.
#
# Just calling "i3-msg exit" kills i3 but leaves the helper
# daemons it started (dunst, picom, nm-applet, udiskie, the
# polkit agent, clipmenud, xss-lock) running as orphans for a
# moment while the X server shuts down underneath them — that's
# what produces the wall of "Can't open display: (null)" /
# "Gtk-WARNING" errors after logout. Stopping them first avoids
# that entirely.
#
# Usage:
#   i3-exit.sh              -> asks for confirmation via rofi
#   i3-exit.sh --no-confirm -> logs out immediately (power-menu.sh already confirmed)
# ==========================================================

if [ "${1:-}" != "--no-confirm" ]; then
    CHOICE=$(printf "🚪 Log out\n✖ Cancel" | rofi -dmenu -i -p "Log out?" -theme ~/.config/rofi/config.rasi)
    [ "$CHOICE" != "🚪 Log out" ] && exit 0
fi

# Stop X-connected helper daemons in a safe order (locker first, so it
# can't grab the keyboard on the way out and get stuck).
for p in xss-lock clipmenud udiskie nm-applet dunst picom polkit-gnome-authentication-agent-1; do
    pkill -TERM -f "$p" >/dev/null 2>&1
done

# Give them a brief moment to actually terminate before i3 (and the X
# session under it) goes away.
sleep 0.3

i3-msg exit
