#!/bin/bash
# ==========================================================
# Sets the desktop wallpaper.
#
# To CHANGE the wallpaper permanently — just edit:
#   ~/.config/i3/wallpaper.conf
# and put the full path to a new image there, e.g.:
#   /home/user/Pictures/Wallpapers/my-photo.jpg
#
# Or press Win+Shift+W to have the system pick a random image
# from ~/Pictures/Wallpapers and remember the choice.
# ==========================================================

CONF="$HOME/.config/i3/wallpaper.conf"
DEFAULT="$HOME/Pictures/Wallpapers/void-green-default.png"

mkdir -p "$(dirname "$CONF")"
[ -f "$CONF" ] || echo "$DEFAULT" > "$CONF"

WALLPAPER="$(cat "$CONF" 2>/dev/null)"
[ -f "$WALLPAPER" ] || WALLPAPER="$DEFAULT"

feh --bg-fill "$WALLPAPER" 2>/dev/null
