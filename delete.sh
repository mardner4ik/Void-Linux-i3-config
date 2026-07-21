#!/bin/bash
# ==================================================================
#  Void Linux + i3 — UNINSTALLER (Swamp Green Edition)
#  Reverses everything install.sh did: packages, services, dotfiles,
#  wallpaper, Plymouth/GRUB changes, PipeWire routing symlinks.
# ==================================================================

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()    { echo -e "  ${GREEN}✔${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
step()  { echo -e "\n${GREEN}${BOLD}→ $1${NC}"; }

echo -e "${RED}${BOLD}=== Void Linux + i3 — Uninstaller ===${NC}"
echo "This removes everything install.sh set up: packages, services,"
echo "dotfiles copied to your home folder, the wallpaper, and any"
echo "Plymouth/GRUB boot-splash changes."

pkg_installed() { xbps-query "$1" >/dev/null 2>&1; }

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    echo -e "${RED}${BOLD}This needs root privileges, but you're not root and sudo isn't installed.${NC}"
    echo "Either run this script as root (e.g. 'su -' then re-run ./delete.sh),"
    echo "or install sudo first as root: xbps-install -Sy sudo"
    exit 1
fi

if [ -t 0 ] && command -v dialog >/dev/null 2>&1; then
    dialog --clear --backtitle "Void Linux i3 Uninstall" \
        --title "Confirm uninstall" \
        --yesno "This will remove all packages and config files that install.sh set up (i3, Xorg, PipeWire, NetworkManager, your chosen file manager/browser/login manager, Plymouth, dotfiles, wallpaper).\n\nThis cannot be undone. Continue?" 12 68 < /dev/tty
    CONFIRM=$?
    clear
    if [ "$CONFIRM" -ne 0 ]; then
        echo "Aborted — nothing was changed."
        exit 0
    fi
else
    read -r -p "Type 'yes' to confirm you want to remove everything install.sh set up: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted — nothing was changed."
        exit 0
    fi
fi

remove_pkgs() {
    local title="$1"; shift
    step "$title"
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            if $SUDO xbps-remove -Ry "$pkg" >/tmp/xbps_remove_"$pkg".log 2>&1; then
                ok "$pkg removed"
            else
                warn "$pkg could not be removed (log: /tmp/xbps_remove_$pkg.log)"
            fi
        else
            ok "$pkg not installed, nothing to do"
        fi
    done
}

disable_service() {
    local svc="$1"
    if [ -L "/var/service/$svc" ]; then
        $SUDO rm -f "/var/service/$svc"
        ok "$svc service disabled"
    fi
}

# ------------------------------------------------------------------
# 1. Stop/disable services started by install.sh
# ------------------------------------------------------------------
step "Disabling services"
disable_service "lightdm"
disable_service "sddm"
disable_service "NetworkManager"

# ------------------------------------------------------------------
# 2. Revert Plymouth boot splash + GRUB changes (if any were made)
# ------------------------------------------------------------------
if [ -f /etc/dracut.conf.d/plymouth.conf ] || pkg_installed plymouth; then
    step "Reverting boot splash screen (Plymouth)"

    [ -f /etc/dracut.conf.d/plymouth.conf ] && $SUDO rm -f /etc/dracut.conf.d/plymouth.conf && ok "Removed the plymouth dracut module config"

    if [ -f /etc/default/grub.bak-plymouth ]; then
        $SUDO mv /etc/default/grub.bak-plymouth /etc/default/grub
        ok "Restored /etc/default/grub from the pre-Plymouth backup"

        GRUB_CFG=""
        for c in /boot/grub/grub.cfg /boot/grub2/grub.cfg; do
            [ -f "$c" ] && GRUB_CFG="$c" && break
        done
        if command -v update-grub >/dev/null 2>&1; then
            $SUDO update-grub >/tmp/grub_revert.log 2>&1 && ok "GRUB configuration regenerated" || warn "update-grub failed (log: /tmp/grub_revert.log)"
        elif [ -n "$GRUB_CFG" ] && command -v grub-mkconfig >/dev/null 2>&1; then
            $SUDO grub-mkconfig -o "$GRUB_CFG" >/tmp/grub_revert.log 2>&1 && ok "GRUB configuration regenerated" || warn "grub-mkconfig failed (log: /tmp/grub_revert.log)"
        else
            warn "Could not regenerate GRUB config automatically — check /etc/default/grub manually"
        fi
    else
        warn "No GRUB backup found (/etc/default/grub.bak-plymouth) — leaving /etc/default/grub untouched"
    fi

    remove_pkgs "Removing Plymouth" plymouth plymouth-data

    step "Rebuilding initramfs without Plymouth"
    if command -v dracut >/dev/null 2>&1; then
        $SUDO dracut --force --regenerate-all >/tmp/dracut_revert.log 2>&1 \
            && ok "Initramfs rebuilt" \
            || warn "dracut failed to rebuild the initramfs (log: /tmp/dracut_revert.log)"
    fi
fi

# ------------------------------------------------------------------
# 3. Remove login manager packages (whichever was installed)
# ------------------------------------------------------------------
remove_pkgs "Login manager" lightdm lightdm-gtk-greeter sddm

# ------------------------------------------------------------------
# 4. Remove file manager / browser (whichever was chosen at install)
# ------------------------------------------------------------------
remove_pkgs "File manager" ranger nnn lf pcmanfm
remove_pkgs "Web browser" firefox chromium qutebrowser

# ------------------------------------------------------------------
# 5. Remove quality-of-life / niceties / visualizer
# ------------------------------------------------------------------
remove_pkgs "System niceties" dunst picom udiskie playerctl brightnessctl xss-lock i3lock polkit polkit-gnome papirus-icon-theme noto-fonts-emoji clipmenu
remove_pkgs "Audio visualizer" cava

# ------------------------------------------------------------------
# 6. Remove network stack
# ------------------------------------------------------------------
remove_pkgs "Network (NetworkManager)" NetworkManager network-manager-applet

# ------------------------------------------------------------------
# 7. Undo PipeWire routing symlinks, then remove PipeWire packages
# ------------------------------------------------------------------
step "Removing PipeWire routing symlinks"
$SUDO rm -f /etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf
$SUDO rm -f /etc/alsa/conf.d/50-pipewire.conf /etc/alsa/conf.d/99-pipewire-default.conf
rm -f ~/.config/pipewire/pipewire.conf.d/10-wireplumber.conf
rmdir ~/.config/pipewire/pipewire.conf.d 2>/dev/null
rmdir ~/.config/pipewire 2>/dev/null
ok "PipeWire routing symlinks removed"

remove_pkgs "Sound and microphone (PipeWire)" pipewire alsa-pipewire pavucontrol pamixer

warn "Standalone pulseaudio was removed during install and is not reinstalled automatically — install it yourself if you need it back"
warn "Your user account was left in the audio/video/input groups — remove manually with '${SUDO:+sudo }gpasswd -d \$USER <group>' if you don't want that"

# ------------------------------------------------------------------
# 8. Remove base i3 environment + Xorg
# ------------------------------------------------------------------
remove_pkgs "Base i3 environment" i3-gaps i3status i3 rofi alacritty feh maim xclip dejavu-fonts-ttf acpi xdg-user-dirs dialog
remove_pkgs "Xorg (X Window System)" xorg xrandr xrdb xsetroot setxkbmap

# ------------------------------------------------------------------
# 9. Remove dotfiles copied by install.sh
# ------------------------------------------------------------------
step "Removing config files from your home folder"
rm -rf ~/.config/i3 ~/.config/rofi ~/.config/dunst ~/.config/cava ~/.config/i3status ~/.config/picom
rm -f ~/.xinitrc ~/.Xresources
ok "Removed ~/.config/{i3,rofi,dunst,cava,i3status,picom}, ~/.xinitrc, ~/.Xresources"

# ------------------------------------------------------------------
# 10. Remove wallpaper installed by install.sh
# ------------------------------------------------------------------
step "Removing default wallpaper"
rm -f ~/Pictures/Wallpapers/void-green-default.png
rmdir ~/Pictures/Wallpapers 2>/dev/null
ok "Removed the default wallpaper (other wallpapers you added yourself are left in place)"

# ------------------------------------------------------------------
# 11. Clean up any packages left orphaned by the removals above
# ------------------------------------------------------------------
if [ -t 0 ] && command -v dialog >/dev/null 2>&1; then
    dialog --clear --backtitle "Void Linux i3 Uninstall" \
        --title "Clean orphaned packages" \
        --yesno "Remove packages that are now orphaned (no longer required by anything else)?\n\nRecommended, but review the list if you're unsure — it can include shared dependencies." 10 66 < /dev/tty
    CLEAN=$?
    clear
else
    CLEAN=1
fi

if [ "$CLEAN" -eq 0 ]; then
    step "Removing orphaned packages"
    $SUDO xbps-remove -Oy >/tmp/xbps_orphans.log 2>&1 && ok "Orphaned packages removed" || warn "Orphan cleanup failed or nothing to remove (log: /tmp/xbps_orphans.log)"
else
    step "Orphaned packages"
    warn "Skipped — run '${SUDO:+sudo }xbps-remove -Oy' later if you want to clean them up"
fi

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}=== Done! ===${NC}"
echo "Removed:"
echo "  • Xorg, i3, and the base window-manager environment"
echo "  • PipeWire (sound/mic) and its routing symlinks"
echo "  • NetworkManager"
echo "  • dunst, picom, udiskie, polkit, i3lock, clipmenu, cava, and other niceties"
echo "  • Your chosen file manager, web browser, and login manager"
echo "  • Plymouth boot splash and its GRUB/dracut changes (if it was set up)"
echo "  • Dotfiles from ~/.config, ~/.xinitrc, ~/.Xresources"
echo "  • The default wallpaper"
echo ""
echo "Not touched: your personal files, other wallpapers you added, and your"
echo "audio/video/input group memberships (remove those manually if you want)."
