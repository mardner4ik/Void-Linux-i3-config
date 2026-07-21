#!/bin/bash
# Power menu shown via rofi, bound to Win+Shift+P.
# Uses loginctl (provided by elogind, which Void ships by default) so it
# works without systemd and without extra packages.

options="🔒 Lock\n🚪 Logout\n🔄 Reboot\n⏻  Shutdown\n💤 Suspend"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme ~/.config/rofi/config.rasi)

case "$chosen" in
    *Lock*)     i3lock -n -c 1b1d1f ;;
    *Logout*)   i3-msg exit ;;
    *Reboot*)   loginctl reboot ;;
    *Shutdown*) loginctl poweroff ;;
    *Suspend*)  loginctl suspend ;;
    *) exit 0 ;;
esac
