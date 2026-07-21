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
| **Screen lock** | i3lock + xss-lock | manual (Win+Shift+X) and automatic on sleep |
| **Battery** | i3status + watcher script | nice charge display in the bar, warnings at 15% and 5% |
| **Wallpaper** | feh + custom script | configured via a single file, or randomized with Win+Shift+W |
| **Clipboard** | clipmenu / clipmenud | keeps clipboard history, Win+Ctrl+V to pick from it |
| **Power menu** | rofi + loginctl | lock / logout / reboot / shutdown / suspend, no systemd needed |
| **File manager** | your choice at install time | ranger / nnn / lf (console) or pcmanfm (graphical) |
| **Web browser** | your choice at install time | Firefox / Chromium / qutebrowser |
| **Login method** | your choice at install time | console auto-login + auto-start i3 (recommended), or LightDM |
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

During installation you'll get three interactive arrow-key menus (via `dialog`) asking you to pick a **file manager**, a **web browser**, and a **login method** — everything else installs and configures itself with no further input.

The script will:
- update the system and install every package (skipping any that aren't in the repo, without aborting the whole run);
- set up PipeWire so sound and the microphone work right away;
- enable D-Bus and elogind and **verify they're actually running** before touching anything network-related;
- bring up NetworkManager and only disable the dhcpcd fallback **after confirming NetworkManager is actually running** — if NetworkManager fails to start for any reason, dhcpcd is left in place (or re-enabled) so you never lose network access;
- let you pick a file manager and browser from a menu, and wire them to `Win+Shift+F` / `Win+Shift+B`;
- copy every config into `~/.config`, `~/.xinitrc`, `~/.Xresources`;
- drop the Void-themed wallpaper into `~/Pictures/Wallpapers` and apply it right away;
- let you pick how you want to log in — see [Login method](#-login-method) below.

After installation, reboot (safest, since new services like NetworkManager and the login method come up cleanly), or at least restart i3 (`Win+Shift+R`).

The script is safe to re-run at any time (e.g. to fix a previous run or change your mind about the file manager/browser/login method) — it checks what's already installed/configured before touching anything.

---

## ⌨️ Keybindings (Super/Win = Mod)

### Windows and system
* `Win + Enter` — terminal (Alacritty)
* `Win + D` — app launcher (Rofi)
* `Win + Tab` — switch windows (Rofi)
* `Win + Shift + F` — file manager (chosen during install)
* `Win + Shift + B` — web browser (chosen during install)
* `Win + Shift + P` — power menu (lock/logout/reboot/shutdown/suspend)
* `Win + Ctrl + V` — clipboard history
* `Win + Shift + Q` — close window
* `Win + F` — fullscreen
* `Win + Shift + Space` — floating toggle
* `Win + E / W / S` — layout: split / tabbed / stacking
* `Win + R` — resize mode (arrows, then Enter/Esc)
* `Win + 1..5` — switch workspace
* `Win + Shift + 1..5` — move window to workspace
* `Win + Shift + C` — reload i3 config (no restart)
* `Win + Shift + R` — restart i3
* `Win + Shift + E` — exit the graphical session
* `Win + Shift + X` — lock screen

### Sound and microphone
* `Volume Up / Down` — volume ±5% (with an on-screen notification)
* `Mute` — mute/unmute sound
* `Mic Mute` — mute/unmute microphone

### Media and brightness
* `Play/Pause`, `Next`, `Prev` — media player control
* `Brightness Up / Down` — screen brightness (laptops)

### Screenshots
* `PrintScreen` — full screen → `~/Pictures/`
* `Win + PrintScreen` — selected region → `~/Pictures/`
* `Ctrl + PrintScreen` — full screen → clipboard
* `Win + Shift + S` — selected region → clipboard (Windows-style)

### Wallpaper
* `Win + Shift + W` — random wallpaper from `~/Pictures/Wallpapers`

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

The change applies after restarting i3 (`Win+Shift+R`), or immediately with:

```bash
~/.config/i3/scripts/wallpaper.sh
```

If you'd rather let the system pick randomly, just drop a few photos into `~/Pictures/Wallpapers/` and press `Win+Shift+W`: it'll pick a random image and remember the choice (it gets written back into `wallpaper.conf`).

---

## 🔋 Battery charge

Shown in the top bar alongside network, disk, and memory, as `🔋 XX%` (or `⚡ XX%` while charging). A separate background script (`battery-watch.sh`) also sends a popup warning once the charge drops to 15%, and a critical one at 5%. On desktops without a battery, this block and script simply don't show up — nothing to configure manually.

---

## 🔐 Login method

During install you pick one of:

1. **Console auto-login + auto-start i3 (recommended)** — no login screen at all. The system boots straight to tty1, logs you in automatically, and `.bash_profile` runs `startx` for you, which launches i3. Simplest option, and it sidesteps a long-standing upstream bug in `lightdm-gtk-greeter` (see below) entirely.
2. **LightDM** — a graphical login screen, themed to match Void (green/charcoal, uses your wallpaper as the background).
3. **Skip** — leaves whatever you already have configured untouched.

You can change your mind at any time by re-running `./install.sh` and picking a different option — it cleanly undoes the previous choice first (disables LightDM if you switch to auto-login, or restores the original `agetty-tty1` config if you switch to LightDM).

**Known LightDM issue:** `lightdm-gtk-greeter` has a long-standing, well-documented upstream bug (not specific to this setup — it affects Arch, Debian, and others too) where the first few keystrokes typed into the password field can get eaten or the field can reset shortly after gaining focus, making it look like your password submits early or gets scrambled. If you hit this:
- Click into the password field and wait about a second before typing.
- If it keeps happening, run `./install.sh` again and choose option 1 (auto-login) instead — it avoids the greeter entirely.

**If you're locked out of a graphical session entirely:** switch to a text console with `Ctrl+Alt+F3` (or F2/F4/F5/F6), log in there, and either fix things or just run `startx` directly.

---

## 🛠️ Common issues

**No internet after install / "NetworkManager ... want up" in `sv status`:**
This means NetworkManager isn't actually running — most often because D-Bus wasn't up yet when it tried to start. The current install.sh checks for this and keeps dhcpcd active as a fallback so you're never left offline, but if you're troubleshooting an existing install:
```bash
sudo cat /var/log/NetworkManager/current   # see the actual error
sudo sv status dbus                        # D-Bus must be "run:", not "down:"
sudo sv up dbus
sudo sv up NetworkManager
sudo sv status NetworkManager
```
If NetworkManager still won't come up and you just need Wi-Fi back right now:
```bash
sudo rm -f /var/service/NetworkManager
sudo ln -s /etc/sv/dhcpcd /var/service/
```

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

**Changed your mind about the file manager or browser:** just edit the `bindsym $mod+Shift+f` / `bindsym $mod+Shift+b` lines in `~/.config/i3/config` directly, then `Win+Shift+C` to reload.

**Changed your mind about the login method:** just re-run `./install.sh` and pick a different option in the "Login Method" menu.
