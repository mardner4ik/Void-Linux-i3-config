#!/bin/bash
echo "Встановлення болотного конфігу Void Linux..."
sudo xbps-install -S i3-gaps i3status rofi alacritty feh maim xclip dejavu-fonts-ttf alsa-utils alsa-plugins -y
mkdir -p ~/.config
cp -r .config/* ~/.config/
cp .xinitrc ~/
cp .Xresources ~/
echo "Готово! Натисніть Win+Shift+R для перезапуску i3."
