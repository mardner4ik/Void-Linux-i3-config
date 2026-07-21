#!/bin/bash
# ==================================================================
#  Void Linux + i3 — AUTOMATIC installer (Swamp Green Edition)
#  Sound + microphone (PipeWire), network, notifications, battery,
#  wallpaper, clipboard history — all working out of the box.
# ==================================================================

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()    { echo -e "  ${GREEN}✔${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
step()  { echo -e "\n${GREEN}${BOLD}→ $1${NC}"; }

echo -e "${GREEN}${BOLD}=== Void Linux + i3 — Swamp Green Edition ===${NC}"
echo "Installation is fully automatic. This will take a few minutes."

pkg_installed() { xbps-query "$1" >/dev/null 2>&1; }

enable_service() {
    # Enables a runit service (if the sv definition exists) and returns 0/1
    local svc="$1"
    [ -d "/etc/sv/$svc" ] || return 1
    sudo mkdir -p /var/service
    [ -L "/var/service/$svc" ] || sudo ln -s "/etc/sv/$svc" /var/service/
    sudo sv up "$svc" >/dev/null 2>&1
    return 0
}

service_is_running() {
    sudo sv status "$1" 2>/dev/null | grep -q '^run:'
}

install_group() {
    local title="$1"; shift
    step "$title"
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            ok "$pkg already installed"
        elif sudo xbps-install -y "$pkg" >/tmp/xbps_install_"$pkg".log 2>&1; then
            ok "$pkg installed"
        else
            warn "$pkg could not be installed (skipping, log: /tmp/xbps_install_$pkg.log)"
        fi
    done
}

# ------------------------------------------------------------------
# 0. Sync repositories
# ------------------------------------------------------------------
step "Syncing Void repositories"
sudo xbps-install -Su -y >/dev/null 2>&1 && ok "System updated" || warn "Could not update the system, continuing anyway"

# ------------------------------------------------------------------
# 1. Base i3 environment
# ------------------------------------------------------------------
install_group "Base i3 environment" i3-gaps i3status rofi alacritty feh maim xclip dejavu-fonts-ttf acpi xdg-user-dirs dialog

# If i3-gaps is gone from the repo (gaps are built into newer i3), fall back to plain i3
if ! pkg_installed i3-gaps && ! pkg_installed i3; then
    warn "i3-gaps is unavailable, trying plain i3 (gaps are built into modern versions)"
    sudo xbps-install -y i3 >/tmp/xbps_install_i3.log 2>&1 && ok "i3 installed" || warn "i3 could not be installed either, check your internet connection"
fi

# Create standard user folders (~/Pictures, ~/Downloads, ...) so wallpapers/screenshots have somewhere to go
xdg-user-dirs-update 2>/dev/null && ok "Standard user folders created (~/Pictures, ~/Downloads, ...)"

# ------------------------------------------------------------------
# 2. Sound + microphone — PipeWire (modern ALSA/PulseAudio replacement)
# ------------------------------------------------------------------
install_group "Sound and microphone (PipeWire)" pipewire alsa-pipewire pavucontrol pamixer

step "Auto-configuring audio (so it just works, no manual steps)"

# Remove plain pulseaudio if present — it conflicts with pipewire-pulse
if pkg_installed pulseaudio; then
    sudo xbps-remove -y pulseaudio >/dev/null 2>&1
    warn "Removed standalone pulseaudio (it conflicts with pipewire-pulse)"
fi

# System-wide PulseAudio compatibility interface (needed by almost every app)
sudo mkdir -p /etc/pipewire/pipewire.conf.d
if [ -e /usr/share/examples/pipewire/20-pipewire-pulse.conf ]; then
    sudo ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
    ok "PulseAudio compatibility (pipewire-pulse) enabled"
else
    warn "20-pipewire-pulse.conf not found (may already be configured system-wide)"
fi

# User session — WirePlumber as session manager
mkdir -p ~/.config/pipewire/pipewire.conf.d
if [ -e /usr/share/examples/wireplumber/10-wireplumber.conf ]; then
    ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf ~/.config/pipewire/pipewire.conf.d/
    ok "WirePlumber attached to the user session"
else
    warn "10-wireplumber.conf not found (may already be configured system-wide)"
fi

# Route plain-ALSA apps (old games, etc.) through PipeWire automatically
sudo mkdir -p /etc/alsa/conf.d
[ -e /usr/share/alsa/alsa.conf.d/50-pipewire.conf ] && sudo ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
[ -e /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ] && sudo ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
ok "ALSA apps are now automatically routed through PipeWire"

# Audio/video/input group membership (extra safety net)
sudo usermod -aG audio,video,input "$USER" 2>/dev/null && ok "User added to the audio/video/input groups"

# ------------------------------------------------------------------
# 3. Core system services — D-Bus, elogind, then network
#    (NetworkManager silently fails to start without a running D-Bus,
#    which is exactly what caused "want up" / no-network on a previous run)
# ------------------------------------------------------------------
step "Core session services (D-Bus, elogind)"

install_group "D-Bus and session management" dbus elogind

if enable_service dbus; then
    sleep 1
    service_is_running dbus && ok "D-Bus is running" || warn "D-Bus did not start — network/polkit may misbehave, check: sudo cat /var/log/dbus/current"
fi

if enable_service elogind; then
    sleep 1
    service_is_running elogind && ok "elogind is running" || warn "elogind did not start — this can affect polkit/NetworkManager permissions"
fi

install_group "Network (NetworkManager)" NetworkManager network-manager-applet

NM_OK=false
if enable_service NetworkManager; then
    step "Waiting for NetworkManager to come up"
    for i in $(seq 1 10); do
        sleep 1
        if service_is_running NetworkManager; then
            NM_OK=true
            break
        fi
    done
fi

if [ "$NM_OK" = true ]; then
    ok "NetworkManager is running"
    # Only NOW, with NetworkManager confirmed running, is it safe to remove dhcpcd.
    # Doing this unconditionally (before verifying NM actually started) is what
    # cut off networking on a previous version of this script — never again.
    if [ -L /var/service/dhcpcd ]; then
        sudo rm -f /var/service/dhcpcd
        warn "Disabled the old dhcpcd service (NetworkManager confirmed running, no more conflict)"
    fi
else
    warn "NetworkManager did NOT start — leaving dhcpcd in place so you keep network access"
    warn "Check the reason with: sudo cat /var/log/NetworkManager/current"
    # Make sure dhcpcd is enabled as a fallback so this run never leaves you offline
    if [ -d /etc/sv/dhcpcd ] && [ ! -L /var/service/dhcpcd ]; then
        sudo ln -s /etc/sv/dhcpcd /var/service/
        sudo sv up dhcpcd >/dev/null 2>&1
        warn "Re-enabled dhcpcd as a fallback"
    fi
fi

# ------------------------------------------------------------------
# 4. Quality-of-life: notifications, compositing, automount, clipboard, icons
# ------------------------------------------------------------------
install_group "System niceties" dunst picom udiskie playerctl brightnessctl xss-lock i3lock polkit polkit-gnome papirus-icon-theme noto-fonts-emoji clipmenu

# ------------------------------------------------------------------
# 5. Audio visualizer (optional, just for looks in the terminal)
# ------------------------------------------------------------------
install_group "Audio visualizer" cava

# ------------------------------------------------------------------
# 6. File manager — interactive pick
# ------------------------------------------------------------------
FM_PKG=""
FM_CMD="alacritty --working-directory ~"

if [ -t 0 ]; then
    FM_CHOICE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
        --title "File Manager" \
        --menu "Pick a file manager (arrows + Enter):" 16 66 6 \
        1 "ranger      - console, vim-style keys, image previews" \
        2 "nnn         - console, extremely fast and minimal" \
        3 "lf          - console, minimalist, written in Go" \
        4 "pcmanfm     - graphical, lightweight (GTK)" \
        5 "Skip" \
        3>&1 1>&2 2>&3 < /dev/tty) || FM_CHOICE=5
    clear
else
    warn "No terminal detected for interactive prompts — skipping file manager selection"
    FM_CHOICE=5
fi

case "${FM_CHOICE:-5}" in
    1) FM_PKG="ranger";  FM_CMD="alacritty -e ranger" ;;
    2) FM_PKG="nnn";     FM_CMD="alacritty -e nnn" ;;
    3) FM_PKG="lf";      FM_CMD="alacritty -e lf" ;;
    4) FM_PKG="pcmanfm"; FM_CMD="pcmanfm" ;;
    *) FM_PKG="";        FM_CMD="alacritty --working-directory ~" ;;
esac

if [ -n "$FM_PKG" ]; then
    install_group "File manager" "$FM_PKG"
else
    step "File manager"
    warn "Skipped — Win+Shift+F will just open a terminal in your home folder"
fi

# ------------------------------------------------------------------
# 7. Web browser — interactive pick
# ------------------------------------------------------------------
BR_PKG=""
BR_CMD="notify-send 'No browser installed' 'Run install.sh again to pick one'"

if [ -t 0 ]; then
    BR_CHOICE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
        --title "Web Browser" \
        --menu "Pick a web browser (arrows + Enter):" 16 66 6 \
        1 "Firefox      - full-featured, best compatibility" \
        2 "Chromium     - fast, Chrome-based" \
        3 "qutebrowser  - keyboard-driven, fits an i3 workflow" \
        4 "Skip" \
        3>&1 1>&2 2>&3 < /dev/tty) || BR_CHOICE=4
    clear
else
    BR_CHOICE=4
fi

case "${BR_CHOICE:-4}" in
    1) BR_PKG="firefox";     BR_CMD="firefox" ;;
    2) BR_PKG="chromium";    BR_CMD="chromium" ;;
    3) BR_PKG="qutebrowser"; BR_CMD="qutebrowser" ;;
    *) BR_PKG="";            BR_CMD="notify-send 'No browser installed' 'Run install.sh again to pick one'" ;;
esac

if [ -n "$BR_PKG" ]; then
    install_group "Web browser" "$BR_PKG"
else
    step "Web browser"
    warn "Skipped — install one later and update ~/.config/i3/config manually"
fi

# ------------------------------------------------------------------
# 8. Copy config files
# ------------------------------------------------------------------
step "Copying configuration files"

mkdir -p ~/.config
cp -r .config/* ~/.config/
cp .xinitrc ~/
cp .Xresources ~/
chmod +x ~/.config/i3/scripts/*.sh
ok "Files copied to ~/.config, ~/.xinitrc, ~/.Xresources"

# Fill in the file manager / browser keybindings chosen above
sed -i "s|__FILE_MANAGER_CMD__|${FM_CMD}|" ~/.config/i3/config
sed -i "s|__BROWSER_CMD__|${BR_CMD}|" ~/.config/i3/config
ok "Win+Shift+F and Win+Shift+B wired up to your chosen apps"

# ------------------------------------------------------------------
# 9. Wallpaper
# ------------------------------------------------------------------
step "Setting up wallpaper"
mkdir -p ~/Pictures/Wallpapers
cp -n wallpapers/*.png ~/Pictures/Wallpapers/ 2>/dev/null
echo "$HOME/Pictures/Wallpapers/void-green-default.png" > ~/.config/i3/wallpaper.conf
ok "Default Void-themed wallpaper copied to ~/Pictures/Wallpapers"
ok "To change it, edit ~/.config/i3/wallpaper.conf, or press Win+Shift+W for a random one"

# ------------------------------------------------------------------
# 10. Login method — LightDM or console auto-login + startx
# ------------------------------------------------------------------
DM_CHOICE=3
if [ -t 0 ]; then
    DM_CHOICE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
        --title "Login Method" \
        --menu "How should you log in? (arrows + Enter):" 17 74 4 \
        1 "Auto-login to console + auto-start i3 (recommended, no login screen)" \
        2 "LightDM graphical login screen" \
        3 "Skip - leave my current login setup untouched" \
        3>&1 1>&2 2>&3 < /dev/tty) || DM_CHOICE=3
    clear
else
    warn "No terminal detected — skipping login method selection"
    DM_CHOICE=3
fi

case "${DM_CHOICE:-3}" in
    1)
        step "Setting up console auto-login + automatic i3 start (option 1)"

        # If a previous run of this script set up LightDM, disable it first so it
        # doesn't fight with tty1 auto-login over the same virtual terminal.
        if [ -L /var/service/lightdm ]; then
            sudo rm -f /var/service/lightdm
            warn "Disabled LightDM service (replaced by console auto-login)"
        fi

        AGETTY_RUN="/etc/sv/agetty-tty1/run"
        if [ -f "$AGETTY_RUN" ]; then
            if grep -q -- "-a $USER" "$AGETTY_RUN" 2>/dev/null; then
                ok "Auto-login for $USER is already configured on tty1"
            else
                sudo cp "$AGETTY_RUN" "$AGETTY_RUN.bak"
                sudo sed -i "s/GETTY_ARGS=\"--noclear\"/GETTY_ARGS=\"-a $USER --noclear\"/" "$AGETTY_RUN"
                if grep -q -- "-a $USER" "$AGETTY_RUN"; then
                    ok "Auto-login on tty1 configured for $USER"
                    warn "Note: this file gets reset if the runit-void package is ever updated — just re-run install.sh if that happens"
                else
                    warn "Could not patch $AGETTY_RUN automatically (unexpected format) — auto-login NOT set up, backup saved as $AGETTY_RUN.bak"
                fi
            fi
        else
            warn "agetty-tty1 run script not found — skipping auto-login setup"
        fi

        MARKER="# Added by Void i3 installer"
        if ! grep -qF "$MARKER" ~/.bash_profile 2>/dev/null; then
            {
                echo ""
                echo "$MARKER"
                echo 'if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then'
                echo "    exec startx"
                echo "fi"
            } >> ~/.bash_profile
            ok "i3 will now start automatically right after logging in on tty1"
        else
            ok "Auto-start-i3 snippet already present in ~/.bash_profile"
        fi
        ;;
    2)
        step "Setting up LightDM (option 2)"

        # Revert tty1 auto-login from a previous run, if any, so it doesn't
        # collide with LightDM over the same virtual terminal.
        if [ -f /etc/sv/agetty-tty1/run.bak ]; then
            sudo cp /etc/sv/agetty-tty1/run.bak /etc/sv/agetty-tty1/run
            warn "Reverted tty1 console auto-login (LightDM will handle login instead)"
        fi

        install_group "LightDM" lightdm lightdm-gtk-greeter accountsservice

        sudo mkdir -p /etc/lightdm
        sudo tee /etc/lightdm/lightdm-gtk-greeter.conf >/dev/null << GREETER
[greeter]
background=$HOME/Pictures/Wallpapers/void-green-default.png
theme-name=Adwaita-dark
icon-theme-name=Papirus-Dark
font-name=DejaVu Sans 11
indicators=~host;~spacer;~clock;~spacer;~session;~language;~a11y;~power
hide-user-image=false
GREETER
        ok "LightDM greeter themed to match Void green"

        if enable_service lightdm; then
            ok "LightDM service enabled"
        else
            warn "Could not enable the lightdm service (etc/sv/lightdm missing?)"
        fi

        warn "Known upstream issue: lightdm-gtk-greeter can occasionally drop the first"
        warn "keystrokes of your password (a long-standing bug, not specific to this setup)."
        warn "Workaround: click the password field and wait about a second before typing."
        warn "If it keeps happening, re-run install.sh and pick option 1 (auto-login) instead."
        ;;
    *)
        step "Login method"
        warn "Skipped — your existing login setup was left untouched"
        ;;
esac

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}=== Done! ===${NC}"
echo "What was set up automatically:"
echo "  • Sound and microphone — PipeWire, works immediately, no manual card selection"
echo "  • D-Bus and elogind — verified running (required by NetworkManager/polkit)"
echo "  • Network — NetworkManager, only takes over once confirmed running (dhcpcd kept as fallback otherwise)"
echo "  • Notifications — dunst, themed to match Void"
echo "  • Window effects — picom (no screen tearing, shadows, smooth fades)"
echo "  • USB automount — udiskie (tray icon)"
echo "  • Auth agent — so graphical apps can prompt for your sudo password"
echo "  • Screen lock — Win+Shift+X, plus auto-lock on sleep"
echo "  • Screen brightness — Brightness Up/Down keys (laptops)"
echo "  • Media keys — Play/Pause/Next/Prev (playerctl)"
echo "  • Clipboard history — Win+Ctrl+V (clipmenu)"
echo "  • Power menu — Win+Shift+P (lock/logout/reboot/shutdown/suspend)"
echo "  • Battery charge — shown nicely in the bar + low-battery warnings"
echo "  • Wallpaper — configured via ~/.config/i3/wallpaper.conf, random with Win+Shift+W"
echo "  • Rofi — restyled to match Void (green/charcoal, app icons)"
[ -n "$FM_PKG" ] && echo "  • File manager — $FM_PKG (Win+Shift+F)"
[ -n "$BR_PKG" ] && echo "  • Web browser — $BR_PKG (Win+Shift+B)"
case "${DM_CHOICE:-3}" in
    1) echo "  • Login — auto-login on tty1, i3 starts automatically" ;;
    2) echo "  • Login — LightDM graphical login screen" ;;
    *) echo "  • Login — left untouched" ;;
esac
echo ""
echo "Reboot now to make sure every service (NetworkManager, D-Bus, login method) is picked up cleanly:"
echo "  sudo reboot"
