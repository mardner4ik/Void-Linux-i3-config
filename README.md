# 🟢 Void Linux i3wm Dotfiles — Swamp Green Edition

A lightweight but "fully equipped" tiling setup for **Void Linux**: sound and microphone work immediately after install, the network comes up on its own, you get notifications, USB automount, screen locking, a nice battery display, clipboard history, and wallpapers that are easy to change. All wrapped in Void's signature green/charcoal palette (`#478061`).

## 🌟 What's included

| Category | What | Details |
|---|---|---|
| **WM** | i3 / i3-gaps | Void green palette, small gaps, smart borders |
| **Sound + mic** | PipeWire + WirePlumber | modern ALSA/PulseAudio replacement, works immediately, no manual card selection |
| **Network** | NetworkManager + nm-applet | Wi-Fi/Ethernet tray icon, auto-connect |
| **Launcher** | Rofi | restyled to match Void, with app icons |
| **Notifications** | dunst | Void-themed, progress bar for volume/brightness |
| **Window effects** | picom | no screen tearing, soft shadows — safe backend for old GPUs |
| **Automount** | udiskie | USB drives mount themselves, tray icon |
| **Auth agent** | polkit + polkit-gnome | graphical apps can prompt for your sudo password |
| **Screen lock** | i3lock + xss-lock | manual (Super+Shift+X) and automatic on sleep |
| **Battery** | i3status + watcher script | nice charge display in the bar, warnings at 15% and 5% |
| **Wallpaper** | feh + custom script | configured via a single file, or randomized with Super+Shift+W |
| **Clipboard** | clipmenu / clipmenud | keeps clipboard history, Super+Ctrl+V to pick from it |
| **Power menu** | rofi + loginctl | lock / logout / reboot / shutdown / suspend, no systemd needed |
| **File manager** | your choice at install time | ranger / nnn / lf (console) or pcmanfm (graphical) |
| **Web browser** | your choice at install time | Firefox / Chromium / qutebrowser |
| **Screenshots** | maim + xclip | region/fullscreen, to a file or the clipboard |
| **Brightness** | brightnessctl | Brightness Up/Down keys (laptops) |
| **Media keys** | playerctl | Play/Pause/Next/Prev for any player |
| **Audio visualizer** | cava | run manually in a terminal |

---

## 🚀 Automatic installation

```bash
sudo xbps-install -S git -y
git clone <link to your repository> ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

During installation you'll get two interactive arrow-key menus (via `dialog`) asking you to pick a **file manager** and a **web browser** — everything else installs and configures itself with no further input.

The script will:
- update the system and install every package (skipping any that aren't in the repo, without aborting the whole run);
- set up PipeWire so sound and the microphone work right away;
- bring up NetworkManager and disable the conflicting dhcpcd service if it was running;
- let you pick a file manager and browser from a menu, and wire them to `Super+Shift+F` / `Super+Shift+B`;
- copy every config into `~/.config`, `~/.xinitrc`, `~/.Xresources`;
- drop the Void-themed wallpaper into `~/Pictures/Wallpapers` and apply it right away.

After installation, reboot (safest, since new services like NetworkManager come up), or at least restart i3 (`Super+Shift+R`).

---

## 🗑️ Uninstalling

```bash
chmod +x delete.sh
./delete.sh
```

`delete.sh` reverses everything `install.sh` did: it removes every package it installed (Xorg, i3, PipeWire, NetworkManager, your chosen file manager/browser/login manager, niceties, Plymouth), disables the services it enabled, restores your GRUB config if Plymouth had changed it, and deletes the dotfiles and wallpaper it copied into your home folder. You'll be asked to confirm before anything is removed, and again before cleaning up orphaned packages. Your personal files and any wallpapers you added yourself are left untouched.

---

## ⌨️ Keybindings (Super = Mod)

### Windows and system
* `Super + Enter` — terminal (Alacritty)
* `Super + D` — app launcher (Rofi)
* `Super + Tab` — switch windows (Rofi)
* `Super + Shift + F` — file manager (chosen during install)
* `Super + Shift + B` — web browser (chosen during install)
* `Super + Shift + P` — power menu (lock/logout/reboot/shutdown/suspend)
* `Super + Ctrl + V` — clipboard history
* `Super + Shift + Q` — close window
* `Super + F` — fullscreen
* `Super + Shift + Space` — floating toggle
* `Super + E / W / S` — layout: split / tabbed / stacking
* `Super + R` — resize mode (arrows, then Enter/Esc)
* `Super + 1..5` — switch workspace
* `Super + Shift + 1..5` — move window to workspace
* `Super + Shift + C` — reload i3 config (no restart)
* `Super + Shift + R` — restart i3
* `Super + Shift + E` — log out (asks for confirmation, then cleanly stops the tray/notification daemons before ending the session)
* `Super + Shift + X` — lock screen

### Sound and microphone
* `Volume Up / Down` — volume ±5% (with an on-screen notification)
* `Mute` — mute/unmute sound
* `Mic Mute` — mute/unmute microphone

### Media and brightness
* `Play/Pause`, `Next`, `Prev` — media player control
* `Brightness Up / Down` — screen brightness (laptops)

### Screenshots
* `PrintScreen` — full screen → `~/Pictures/`
* `Super + PrintScreen` — selected region → `~/Pictures/`
* `Ctrl + PrintScreen` — full screen → clipboard
* `Super + Shift + S` — selected region → clipboard (Windows-style)

### Wallpaper
* `Super + Shift + W` — random wallpaper from `~/Pictures/Wallpapers`

---

## 🖼️ Changing the wallpaper

The simplest way is to edit:

```
~/.config/i3/wallpaper.conf
```

and put the full path to whichever image you want, e.g.:

```
/home/user/Pictures/Wallpapers/my-photo.jpg
```

The change applies after restarting i3 (`Super+Shift+R`), or immediately with:

```bash
~/.config/i3/scripts/wallpaper.sh
```

If you'd rather let the system pick randomly, just drop a few photos into `~/Pictures/Wallpapers/` and press `Super+Shift+W`: it'll pick a random image and remember the choice (it gets written back into `wallpaper.conf`).

---

## 🔋 Battery charge

Shown in the top bar alongside network, disk, and memory, as `🔋 XX%` (or `⚡ XX%` while charging). A separate background script (`battery-watch.sh`) also sends a popup warning once the charge drops to 15%, and a critical one at 5%. On desktops without a battery, this block and script simply don't show up — nothing to configure manually.

---

## 🛠️ Common issues

**Terminal doesn't open, or Firefox/your file manager don't show up in rofi:** this is almost always because those packages failed to install — usually no internet connection yet at the point `install.sh` ran (very common right after booting a live ISO, before Wi-Fi/Ethernet is set up). `install.sh` now aborts early with a clear warning if it can't reach the repositories, and prints a pass/fail report for the critical packages at the end — re-read that output first. To check right now without reinstalling:
```bash
which alacritty || echo "alacritty missing"
xbps-query -l | grep -Ei 'firefox|chromium|qutebrowser|ranger|nnn|lf|pcmanfm'
ls /usr/share/applications | grep -i firefox
cat /tmp/xbps_install_alacritty.log   # or _firefox.log etc — shows why it failed
```
If a package is missing, fix your network first, then `sudo xbps-install -y <package>` (e.g. `sudo xbps-install -y alacritty firefox`) — no need to rerun the whole installer.

**Rear speakers silent (desktop PC, HDA Intel):**
```bash
echo "options snd-hda-intel model=generic position_fix=1" | sudo tee /etc/modprobe.d/alsa-base.conf
sudo reboot
```

**Want to confirm PipeWire is actually handling audio:**
```bash
pactl info | grep "Server Name"
# Should print something like: Server Name: PulseAudio (on PipeWire ...)
```

**No network icon in the tray:** make sure you can see the `nm-applet` icon in the right side of the i3bar — if not, run `nm-applet &` manually and check `/tmp/xbps_install_NetworkManager.log`.

**Want the old picom GPU backend back:** replace `backend = "xrender"` with `backend = "glx"` in `~/.config/picom/picom.conf` (can look better on newer graphics cards).

**Changed your mind about the file manager or browser:** just edit the `bindsym $mod+Shift+f` / `bindsym $mod+Shift+b` lines in `~/.config/i3/config` directly, then `Super+Shift+C` to reload.
