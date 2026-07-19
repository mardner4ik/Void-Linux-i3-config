#!/bin/bash
# ==================================================================
#  Void Linux + i3 — AUTOMATIC installer (Swamp Green Edition)
#  Xorg, sound + microphone (PipeWire), network, notifications,
#  battery, wallpaper, clipboard history, login manager, optional
#  boot splash screen — all working out of the box.
# ==================================================================

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()    { echo -e "  ${GREEN}✔${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC} $1"; }
step()  { echo -e "\n${GREEN}${BOLD}→ $1${NC}"; }

echo -e "${GREEN}${BOLD}=== Void Linux + i3 — Swamp Green Edition ===${NC}"
echo "Installation is fully automatic. This will take a few minutes."

# Live ISOs commonly log you in as root with no 'sudo' installed at all.
# Detect that and just run commands directly instead of failing on
# "sudo: command not found" for every single install step.
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    echo -e "${RED}${BOLD}This needs root privileges, but you're not root and sudo isn't installed.${NC}"
    echo "Either run this script as root (e.g. 'su -' then re-run ./install.sh),"
    echo "or install sudo first as root: xbps-install -Sy sudo"
    exit 1
fi

pkg_installed() { xbps-query "$1" >/dev/null 2>&1; }

install_group() {
    local title="$1"; shift
    step "$title"
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            ok "$pkg already installed"
        elif $SUDO xbps-install -y "$pkg" >/tmp/xbps_install_"$pkg".log 2>&1; then
            ok "$pkg installed"
        else
            warn "$pkg could not be installed (skipping, log: /tmp/xbps_install_$pkg.log)"
        fi
    done
}

# Enable a runit service (symlink into /var/service), disabling any other
# service listed in $2 (space-separated) so only one login/display manager
# is ever active at once.
enable_service() {
    local svc="$1"; shift
    local others="${1:-}"
    if [ -d "/etc/sv/$svc" ]; then
        $SUDO mkdir -p /var/service
        for o in $others; do
            [ -L "/var/service/$o" ] && $SUDO rm -f "/var/service/$o" && warn "Disabled $o (replaced by $svc)"
        done
        if [ ! -L "/var/service/$svc" ]; then
            $SUDO ln -s "/etc/sv/$svc" /var/service/
            ok "$svc service enabled"
        else
            ok "$svc service already enabled"
        fi
    else
        warn "/etc/sv/$svc not found — service not enabled (package may not have installed correctly)"
    fi
}

# ------------------------------------------------------------------
# 0. Sync repositories
# ------------------------------------------------------------------
step "Syncing Void repositories"
DO_SYNC="y"
if [ -t 0 ]; then
    read -r -p "  Sync/update Void repositories now? [Y/n] " DO_SYNC < /dev/tty
fi
DO_SYNC="${DO_SYNC:-y}"

if [ "${DO_SYNC,,}" = "n" ]; then
    warn "Skipped — using whatever package index is already cached locally"
elif $SUDO xbps-install -Su -y >/tmp/xbps_sync.log 2>&1; then
    ok "System updated"
else
    echo -e "  ${RED}${BOLD}✘ Could not sync/update the Void repositories.${NC}"
    echo "  This almost always means there is no working internet connection yet"
    echo "  (very common right after booting a live ISO). Log: /tmp/xbps_sync.log"
    echo "  If EVERY package below fails too, this is why — fix your network"
    echo "  (e.g. 'ip a', 'dhcpcd <iface>', or connect Wi-Fi) and run install.sh again."
    if [ -t 0 ]; then
        read -r -p "  Continue anyway without a confirmed connection? [y/N] " NET_CONT < /dev/tty
    else
        NET_CONT="n"
    fi
    if [ "${NET_CONT,,}" != "y" ]; then
        echo "Aborted — fix your network connection and run install.sh again."
        exit 1
    fi
    warn "Continuing without a confirmed connection — expect most installs below to fail"
fi

# ------------------------------------------------------------------
# 1. Xorg (X Window System)
# ------------------------------------------------------------------
# The comprehensive "xorg" meta-package pulls in the X server, every free
# video/input driver, base fonts and xorg-xinit (startx) in one go — the
# safe default unless you need a proprietary GPU driver (e.g. nvidia).
install_group "Xorg (X Window System)" xorg xrandr xrdb xsetroot setxkbmap

if ! pkg_installed xorg-server && ! pkg_installed xorg; then
    warn "Xorg server could not be confirmed as installed — check /tmp/xbps_install_xorg.log"
fi

# ------------------------------------------------------------------
# 2. Base i3 environment
# ------------------------------------------------------------------
install_group "Base i3 environment" i3-gaps i3status rofi alacritty feh maim xclip dejavu-fonts-ttf acpi xdg-user-dirs dialog

# If i3-gaps is gone from the repo (gaps are built into newer i3), fall back to plain i3
if ! pkg_installed i3-gaps && ! pkg_installed i3; then
    warn "i3-gaps is unavailable, trying plain i3 (gaps are built into modern versions)"
    $SUDO xbps-install -y i3 >/tmp/xbps_install_i3.log 2>&1 && ok "i3 installed" || warn "i3 could not be installed either, check your internet connection"
fi

# Create standard user folders (~/Pictures, ~/Downloads, ...) so wallpapers/screenshots have somewhere to go
xdg-user-dirs-update 2>/dev/null && ok "Standard user folders created (~/Pictures, ~/Downloads, ...)"

# ------------------------------------------------------------------
# 3. Sound + microphone — PipeWire (modern ALSA/PulseAudio replacement)
# ------------------------------------------------------------------
install_group "Sound and microphone (PipeWire)" pipewire alsa-pipewire pavucontrol pamixer

step "Auto-configuring audio (so it just works, no manual steps)"

# Remove plain pulseaudio if present — it conflicts with pipewire-pulse
if pkg_installed pulseaudio; then
    $SUDO xbps-remove -y pulseaudio >/dev/null 2>&1
    warn "Removed standalone pulseaudio (it conflicts with pipewire-pulse)"
fi

# System-wide PulseAudio compatibility interface (needed by almost every app)
$SUDO mkdir -p /etc/pipewire/pipewire.conf.d
if [ -e /usr/share/examples/pipewire/20-pipewire-pulse.conf ]; then
    $SUDO ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
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
$SUDO mkdir -p /etc/alsa/conf.d
[ -e /usr/share/alsa/alsa.conf.d/50-pipewire.conf ] && $SUDO ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/
[ -e /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf ] && $SUDO ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
ok "ALSA apps are now automatically routed through PipeWire"

# Audio/video/input group membership (extra safety net)
$SUDO usermod -aG audio,video,input "$USER" 2>/dev/null && ok "User added to the audio/video/input groups"

# ------------------------------------------------------------------
# 4. Network
# ------------------------------------------------------------------
install_group "Network (NetworkManager)" NetworkManager network-manager-applet

if [ -d /etc/sv/NetworkManager ]; then
    $SUDO mkdir -p /var/service
    if [ ! -L /var/service/NetworkManager ]; then
        $SUDO ln -s /etc/sv/NetworkManager /var/service/
        ok "NetworkManager service started"
    else
        ok "NetworkManager service already active"
    fi
    # dhcpcd conflicts with NetworkManager — disable it if it was enabled
    if [ -L /var/service/dhcpcd ]; then
        $SUDO rm -f /var/service/dhcpcd
        warn "Disabled the old dhcpcd service (to avoid conflicting with NetworkManager)"
    fi
fi

# ------------------------------------------------------------------
# 5. Quality-of-life: notifications, compositing, automount, clipboard, icons
# ------------------------------------------------------------------
install_group "System niceties" dunst picom udiskie playerctl brightnessctl xss-lock i3lock polkit polkit-gnome papirus-icon-theme noto-fonts-emoji clipmenu curl

# ------------------------------------------------------------------
# 6. Audio visualizer (optional, just for looks in the terminal)
# ------------------------------------------------------------------
install_group "Audio visualizer" cava

# ------------------------------------------------------------------
# 7. File manager — interactive pick
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
# 8. Web browser — interactive pick
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
# 9. Login manager (authorization/display manager) — interactive pick
# ------------------------------------------------------------------
LM_CHOICE=4
if [ -t 0 ]; then
    LM_CHOICE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
        --title "Login Manager" \
        --menu "Pick a login/authorization manager (arrows + Enter):" 16 70 6 \
        1 "LightDM      - lightweight graphical login (GTK greeter)" \
        2 "SDDM         - QML-based graphical login screen" \
        3 "None         - no graphical login, start i3 with 'startx'" \
        3>&1 1>&2 2>&3 < /dev/tty) || LM_CHOICE=3
    clear
else
    warn "No terminal detected for interactive prompts — skipping login manager selection"
    LM_CHOICE=3
fi

LM_NAME="none"
case "${LM_CHOICE:-3}" in
    1)
        install_group "Login manager (LightDM)" lightdm lightdm-gtk-greeter
        enable_service "lightdm" "sddm"
        LM_NAME="LightDM"
        ;;
    2)
        install_group "Login manager (SDDM)" sddm
        enable_service "sddm" "lightdm"
        LM_NAME="SDDM"
        ;;
    *)
        step "Login manager"
        warn "Skipped — log in on the text console and run 'startx' to launch i3 (uses ~/.xinitrc)"
        # Make sure no leftover display manager is enabled from a previous run
        for o in lightdm sddm; do
            [ -L "/var/service/$o" ] && $SUDO rm -f "/var/service/$o" && warn "Disabled leftover $o service"
        done
        ;;
esac

# ------------------------------------------------------------------
# 10. Boot splash screen (Plymouth) — optional
# ------------------------------------------------------------------
PLYMOUTH_THEME=""
WANT_SPLASH=1

if [ -t 0 ]; then
    dialog --clear --backtitle "Void Linux i3 Setup" \
        --title "Boot Splash Screen" \
        --yesno "Add a graphical boot splash screen (Plymouth) instead of the plain kernel/BIOS boot text?\n\nYou can use your laptop/PC brand's own logo (downloaded), a generic animated theme, or just your firmware's logo via BGRT." 12 68 < /dev/tty
    WANT_SPLASH=$?
    clear
else
    WANT_SPLASH=1
fi

if [ "$WANT_SPLASH" -eq 0 ]; then
    install_group "Boot splash screen (Plymouth)" plymouth plymouth-data

    if pkg_installed plymouth; then

        # ---- pick a source for the splash look --------------------
        SPLASH_SOURCE=3
        if [ -t 0 ]; then
            SPLASH_SOURCE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
                --title "Boot Splash Look" \
                --menu "How do you want to pick the look?" 14 70 4 \
                1 "Brand logo (Lenovo, ASUS, Gigabyte, ...) - downloads it" \
                2 "Generic Plymouth theme (spinner, glow, bgrt/firmware, ...)" \
                3 "Skip - keep the plain BIOS/kernel text boot" \
                3>&1 1>&2 2>&3 < /dev/tty) || SPLASH_SOURCE=3
            clear
        fi

        # ============================================================
        # Option 1: manufacturer logo, downloaded from Wikimedia Commons
        # (freely-licensed logos) and dropped into a small custom
        # Plymouth "script" theme — no dependency on any specific
        # Plymouth theme's internal file layout, so it works the same
        # on any version.
        # ============================================================
        if [ "$SPLASH_SOURCE" = "1" ]; then
            command -v curl >/dev/null 2>&1 || install_group "curl (needed to download the logo)" curl

            BRAND_CHOICE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
                --title "Pick a brand" \
                --menu "Whose logo do you want on the boot splash?" 18 66 9 \
                1 "Lenovo" \
                2 "ASUS" \
                3 "Gigabyte" \
                4 "Dell" \
                5 "MSI" \
                6 "HP" \
                7 "Acer" \
                8 "Custom - paste your own image URL" \
                9 "Back / cancel" \
                3>&1 1>&2 2>&3 < /dev/tty) || BRAND_CHOICE=9
            clear

            LOGO_URL=""
            LOGO_LABEL=""
            case "$BRAND_CHOICE" in
                1)
                    LENOVO_SUB=$(dialog --clear --backtitle "Void Linux i3 Setup" \
                        --title "Lenovo" \
                        --menu "Which Lenovo logo?" 12 60 3 \
                        1 "ThinkPad" \
                        2 "Generic Lenovo" \
                        3>&1 1>&2 2>&3 < /dev/tty) || LENOVO_SUB=2
                    clear
                    if [ "$LENOVO_SUB" = "1" ]; then
                        LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/ThinkPad_Logo.svg?width=500"
                        LOGO_LABEL="ThinkPad"
                    else
                        LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/Lenovo_logo_2015.svg?width=500"
                        LOGO_LABEL="Lenovo"
                    fi
                    ;;
                2) LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/ASUS_Logo.svg?width=500"; LOGO_LABEL="ASUS" ;;
                3) LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/Gigabyte_Technology_Logo.svg?width=500"; LOGO_LABEL="Gigabyte" ;;
                4) LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/Dell_Logo.svg?width=500"; LOGO_LABEL="Dell" ;;
                5) LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/Micro-Star_International_logo2020.svg?width=500"; LOGO_LABEL="MSI" ;;
                6) LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/HP_logo_2012.svg?width=500"; LOGO_LABEL="HP" ;;
                7) LOGO_URL="https://commons.wikimedia.org/wiki/Special:FilePath/Acer_2011.svg?width=500"; LOGO_LABEL="Acer" ;;
                8)
                    if [ -t 0 ]; then
                        LOGO_URL=$(dialog --clear --backtitle "Void Linux i3 Setup" \
                            --title "Custom logo URL" \
                            --inputbox "Paste a direct image URL (png/jpg/svg):" 10 66 \
                            3>&1 1>&2 2>&3 < /dev/tty) || LOGO_URL=""
                        clear
                    fi
                    LOGO_LABEL="Custom"
                    ;;
                *) LOGO_URL="" ;;
            esac

            if [ -n "$LOGO_URL" ]; then
                step "Downloading the $LOGO_LABEL logo"
                THEME_NAME="void-logo"
                THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
                TMP_LOGO="/tmp/void-boot-logo.img"

                if curl -fL --max-time 20 -o "$TMP_LOGO" "$LOGO_URL" 2>/tmp/logo_download.log && [ -s "$TMP_LOGO" ] && [ "$(stat -c%s "$TMP_LOGO" 2>/dev/null || echo 0)" -gt 200 ]; then
                    ok "$LOGO_LABEL logo downloaded"

                    $SUDO mkdir -p "$THEME_DIR"
                    $SUDO cp "$TMP_LOGO" "$THEME_DIR/logo.png"

                    # Minimal, self-contained Plymouth "script" theme: dark
                    # background, the logo centered, and a small pulsing dot
                    # underneath so it's clear the system is still booting.
                    $SUDO tee "$THEME_DIR/$THEME_NAME.plymouth" >/dev/null << PLYMOUTH_INI
[Plymouth Theme]
Name=Void Logo - $LOGO_LABEL
Description=Custom boot logo generated by the Void i3 installer
ModuleName=script

[script]
ImageDir=$THEME_DIR
ScriptFile=$THEME_DIR/$THEME_NAME.script
PLYMOUTH_INI

                    $SUDO tee "$THEME_DIR/$THEME_NAME.script" >/dev/null << 'PLYMOUTH_SCRIPT'
Window.SetBackgroundTopColor(0.10, 0.10, 0.11);
Window.SetBackgroundBottomColor(0.10, 0.10, 0.11);

logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth()  / 2 - logo.image.GetWidth()  / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2);

dot.image = Image.Text("●", 1, 0.83, 0.48, 1, "Sans 28");
dot.sprite = Sprite(dot.image);
dot.sprite.SetX(Window.GetWidth() / 2 - dot.image.GetWidth() / 2);
dot.sprite.SetY(logo.sprite.GetY() + logo.image.GetHeight() + 40);

fun refresh_callback() {
    t = Plymouth.GetBootProgress() * 40;
    opacity = (Math.Sin(t) + 1) / 2;
    dot.sprite.SetOpacity(0.3 + opacity * 0.7);
}
Plymouth.SetRefreshFunction(refresh_callback);
PLYMOUTH_SCRIPT

                    PLYMOUTH_THEME="$THEME_NAME"
                    ok "Custom '$LOGO_LABEL' boot theme built"
                else
                    warn "Could not download that logo (log: /tmp/logo_download.log) — keeping the plain BIOS/kernel text boot"
                    warn "You can try again later, or pick 'Generic Plymouth theme' instead"
                fi
            else
                step "Boot splash theme"
                warn "No brand picked — keeping the plain BIOS/kernel text boot"
            fi

        # ============================================================
        # Option 2: generic built-in Plymouth theme (unchanged behaviour)
        # ============================================================
        elif [ "$SPLASH_SOURCE" = "2" ]; then
            step "Choosing a boot splash theme"

            # Ask plymouth itself what themes are actually available on this system
            mapfile -t AVAILABLE_THEMES < <(plymouth-set-default-theme --list 2>/dev/null | tr -d '\r')

            # Fallback list (upstream default theme set) in case listing fails
            if [ "${#AVAILABLE_THEMES[@]}" -eq 0 ]; then
                AVAILABLE_THEMES=(bgrt spinner details text tribar solar spinfinity glow fade-in script)
            fi

            theme_desc() {
                case "$1" in
                    bgrt)       echo "shows your laptop/PC firmware's own boot logo (e.g. ThinkPad) — closest to a plain BIOS boot" ;;
                    spinner)    echo "simple centered spinner, works well on any laptop" ;;
                    spinfinity) echo "spinner with a soft glow, Fedora-style" ;;
                    details)    echo "verbose boot log text, minimal styling" ;;
                    text)       echo "plain text boot messages, styled" ;;
                    tribar)     echo "classic three-color progress bar" ;;
                    solar)      echo "orange/dark spinner theme" ;;
                    glow)       echo "glowing logo with progress bar" ;;
                    fade-in)    echo "logo fades in while loading" ;;
                    script)     echo "scriptable base theme (for custom themes)" ;;
                    *)          echo "Plymouth theme" ;;
                esac
            }

            MENU_ITEMS=()
            IDX=1
            declare -A THEME_BY_IDX
            for t in "${AVAILABLE_THEMES[@]}"; do
                [ -z "$t" ] && continue
                MENU_ITEMS+=("$IDX" "$t - $(theme_desc "$t")")
                THEME_BY_IDX[$IDX]="$t"
                IDX=$((IDX+1))
            done
            SKIP_IDX=$IDX
            MENU_ITEMS+=("$SKIP_IDX" "Skip - keep the plain BIOS/kernel text boot")

            if [ -t 0 ]; then
                THEME_CHOICE=$(dialog --clear --backtitle "Void Linux i3 Setup" \
                    --title "Boot Splash Theme" \
                    --menu "Pick a boot splash theme (arrows + Enter):" 20 76 10 \
                    "${MENU_ITEMS[@]}" \
                    3>&1 1>&2 2>&3 < /dev/tty) || THEME_CHOICE=$SKIP_IDX
                clear
            else
                THEME_CHOICE=$SKIP_IDX
            fi

            if [ "${THEME_CHOICE:-$SKIP_IDX}" != "$SKIP_IDX" ] && [ -n "${THEME_BY_IDX[$THEME_CHOICE]:-}" ]; then
                PLYMOUTH_THEME="${THEME_BY_IDX[$THEME_CHOICE]}"
            else
                step "Boot splash theme"
                warn "Skipped — Plymouth is installed but not enabled, boot stays plain BIOS/kernel text"
            fi
        else
            step "Boot splash theme"
            warn "Skipped — keeping the plain BIOS/kernel text boot"
        fi

        # ============================================================
        # Wire up whichever theme got picked above (brand logo or
        # built-in) — same dracut/GRUB steps either way.
        # ============================================================
        if [ -n "$PLYMOUTH_THEME" ]; then
            step "Applying Plymouth theme: $PLYMOUTH_THEME"
            $SUDO plymouth-set-default-theme "$PLYMOUTH_THEME" 2>/tmp/plymouth_theme.log \
                && ok "Theme set to $PLYMOUTH_THEME" \
                || warn "Could not set theme (log: /tmp/plymouth_theme.log)"

            # Make sure dracut bundles the plymouth module into the initramfs
            $SUDO mkdir -p /etc/dracut.conf.d
            echo 'add_dracutmodules+=" plymouth "' | $SUDO tee /etc/dracut.conf.d/plymouth.conf >/dev/null
            ok "Enabled the plymouth dracut module"

            step "Rebuilding initramfs (this can take a minute)"
            if $SUDO dracut --force --regenerate-all >/tmp/dracut_plymouth.log 2>&1; then
                ok "Initramfs rebuilt with Plymouth support"
            else
                warn "dracut failed to rebuild the initramfs (log: /tmp/dracut_plymouth.log) — splash may not show until you fix this"
            fi

            # Add "splash quiet" to the kernel command line (GRUB only)
            if [ -f /etc/default/grub ]; then
                $SUDO cp /etc/default/grub /etc/default/grub.bak-plymouth
                if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
                    if ! grep -q 'splash' /etc/default/grub; then
                        $SUDO sed -i -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="([^"]*)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet splash"/' /etc/default/grub
                    fi
                else
                    echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' | $SUDO tee -a /etc/default/grub >/dev/null
                fi
                ok "Added 'quiet splash' to the GRUB kernel command line (backup: /etc/default/grub.bak-plymouth)"

                GRUB_CFG=""
                for c in /boot/grub/grub.cfg /boot/grub2/grub.cfg; do
                    [ -f "$c" ] && GRUB_CFG="$c" && break
                done

                if command -v update-grub >/dev/null 2>&1; then
                    $SUDO update-grub >/tmp/grub_update.log 2>&1 && ok "GRUB configuration regenerated" || warn "update-grub failed (log: /tmp/grub_update.log)"
                elif [ -n "$GRUB_CFG" ] && command -v grub-mkconfig >/dev/null 2>&1; then
                    $SUDO grub-mkconfig -o "$GRUB_CFG" >/tmp/grub_update.log 2>&1 && ok "GRUB configuration regenerated" || warn "grub-mkconfig failed (log: /tmp/grub_update.log)"
                else
                    warn "Could not find grub-mkconfig/update-grub — regenerate your GRUB config manually so 'splash' takes effect"
                fi
            else
                warn "No /etc/default/grub found (not using GRUB?) — add 'splash' to your bootloader's kernel command line manually"
            fi
        fi
    fi
else
    step "Boot splash screen"
    warn "Skipped — keeping the plain BIOS/kernel text boot"
fi

# ------------------------------------------------------------------
# 11. Copy config files
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
# 12. Wallpaper
# ------------------------------------------------------------------
step "Setting up wallpaper"
mkdir -p ~/Pictures/Wallpapers
cp -n wallpapers/*.png ~/Pictures/Wallpapers/ 2>/dev/null
echo "$HOME/Pictures/Wallpapers/void-green-default.png" > ~/.config/i3/wallpaper.conf
ok "Default Void-themed wallpaper copied to ~/Pictures/Wallpapers"
ok "To change it, edit ~/.config/i3/wallpaper.conf, or press Win+Shift+W for a random one"

# ------------------------------------------------------------------
# Verification — check the critical stuff is actually there
# ------------------------------------------------------------------
step "Verifying the install"
CRITICAL_OK=1
check_installed() {
    local label="$1" pkg="$2"
    if [ -z "$pkg" ]; then
        return
    elif pkg_installed "$pkg"; then
        ok "$label ($pkg)"
    else
        echo -e "  ${RED}${BOLD}✘ $label ($pkg) is NOT installed${NC} — retry with: ${SUDO:+sudo }xbps-install -y $pkg"
        CRITICAL_OK=0
    fi
}

I3_PKG="i3"; pkg_installed i3-gaps && I3_PKG="i3-gaps"
check_installed "Xorg"              xorg
check_installed "Window manager"    "$I3_PKG"
check_installed "Terminal"          alacritty
check_installed "App launcher"      rofi
check_installed "Dialog (installer menus)" dialog
[ -n "$FM_PKG" ] && check_installed "File manager" "$FM_PKG"
[ -n "$BR_PKG" ] && check_installed "Web browser"  "$BR_PKG"

if [ "$CRITICAL_OK" -eq 0 ]; then
    echo -e "\n  ${RED}${BOLD}⚠ Some core packages above failed to install.${NC}"
    echo "  This is almost always a network problem during install (see the repo-sync"
    echo "  warning above, and check the /tmp/xbps_install_<pkg>.log files it points to)."
    echo "  Fix your connection, then either re-run ./install.sh, or install just the"
    echo "  missing ones with the '${SUDO:+sudo }xbps-install -y <pkg>' commands printed above."
fi

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
echo -e "\n${GREEN}${BOLD}=== Done! ===${NC}"
echo "What was set up automatically:"
echo "  • Xorg — X server, drivers, and fonts installed"
echo "  • Sound and microphone — PipeWire, works immediately, no manual card selection"
echo "  • Network — NetworkManager (Wi-Fi/Ethernet) with a tray icon"
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
if [ "$LM_NAME" != "none" ]; then
    echo "  • Login manager — $LM_NAME (graphical login on boot)"
else
    echo "  • Login manager — none (run 'startx' from the console to start i3)"
fi
if [ -n "$PLYMOUTH_THEME" ]; then
    if [ "$PLYMOUTH_THEME" = "void-logo" ] && [ -n "${LOGO_LABEL:-}" ]; then
        echo "  • Boot splash screen — Plymouth, $LOGO_LABEL logo"
    else
        echo "  • Boot splash screen — Plymouth, theme '$PLYMOUTH_THEME'"
    fi
else
    echo "  • Boot splash screen — not enabled (plain BIOS/kernel text boot)"
fi
echo ""
echo "Press Win+Shift+R to restart i3, or reboot to make sure everything is picked up."
