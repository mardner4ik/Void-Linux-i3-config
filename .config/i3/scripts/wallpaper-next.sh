#!/bin/bash
# Switches to a random wallpaper from ~/Pictures/Wallpapers and remembers
# the choice in ~/.config/i3/wallpaper.conf (persists across reboots).

DIR="$HOME/Pictures/Wallpapers"
CONF="$HOME/.config/i3/wallpaper.conf"

mkdir -p "$DIR" "$(dirname "$CONF")"

mapfile -t IMAGES < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \))

if [ "${#IMAGES[@]}" -eq 0 ]; then
    notify-send "Wallpaper" "Add some images to ~/Pictures/Wallpapers and try again" 2>/dev/null
    exit 1
fi

PICK="${IMAGES[$RANDOM % ${#IMAGES[@]}]}"
echo "$PICK" > "$CONF"
feh --bg-fill "$PICK"
notify-send "Wallpaper changed" "$(basename "$PICK")" 2>/dev/null
