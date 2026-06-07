# 🟢 Void Linux Minimal i3wm Dotfiles (Swamp Green Setup)

This is an ultra-lightweight, minimalistic, and high-performance tiling setup built on **Void Linux** for low-end hardware (Pentium G640, Radeon HD6670, 4GB RAM). It features pure hardware **ALSA** audio routing (no heavy servers) and an authentic corporate-green Void color scheme.

## 🌟 Features
* **WM:** i3wm / i3-gaps (Void Linux brand green `#478061` palette)
* **Launcher:** Rofi (replaced primitive dmenu)
* **Audio:** pure hardware ALSA configuration (mapped to card 1 / Intel PCH)
* **Scale:** Optimized 110 DPI scaling (`Xft.dpi: 110`) for 1080p/720p screens
* **Screenshots:** Integrated custom keys (`maim` + `xclip`) for region/fullscreen capturing

---

## 🚀 One-Command Automatic Installation

Open your terminal in Void Linux and paste this exact command. It will clone the repository, install all necessary packages, copy configuration files, and set up your system instantly:

```bash
sudo xbps-install -S git -y && git clone https://github.com ~/dotfiles && cd ~/dotfiles && chmod +x install.sh && ./install.sh
```

> ⚠️ **Note:** Don't forget to replace `YOUR_GITHUB_USERNAME` in the command with your actual GitHub account name!

---

## ⌨️ Custom Keybindings (Super/Win used as Mod)

### 🎯 Window & System Management
* `Win + Enter` — Open Terminal (Alacritty)
* `Win + D` — Open Application Menu (Rofi Search)
* `Win + Shift + Q` — Close Active Window
* `Win + Shift + R` — Reload i3 Configurations (On the fly)
* `Win + Shift + E` — Exit Graphical UI

### 🔊 Audio & Volume Keys
* `Volume Up Key` — Increase hardware volume by 5%
* `Volume Down Key` — Decrease hardware volume by 5%
* `Mute Key` — Toggle Audio Mute state

### 📸 Screenshot Tools
* `PrintScreen` — Save fullscreen to `~/Pictures/`
* `Win + PrintScreen` — Select area with mouse and save to `~/Pictures/`
* `Ctrl + PrintScreen` — Copy fullscreen straight to clipboard
* `Win + Shift + S` — Select area and copy straight to clipboard (Windows style)

---

## 🛠️ Post-Installation (Audio Fix)
If your back speakers do not output audio because of the kernel's automatic Jack Sensing feature, apply the generic hardware mod:
```bash
echo "options snd-hda-intel model=generic position_fix=1" | sudo tee /etc/modprobe.d/alsa-base.conf
```
Then reboot your computer: `sudo reboot`.

