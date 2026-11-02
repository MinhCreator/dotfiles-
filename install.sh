#!/usr/bin/env bash
set -euo pipefail

clear

dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
files=$dir/files
wallpaper=$dir/assets/wallpaper.jpg
old_home=/home/bnsplit

pacman_pkgs=(
  hyprland
  hypridle
  hyprlock
  hyprsunset
  hyprpicker
  hyprshutdown
  uwsm
  qt6-5compat
  awww
  plasma-workspace
  kitty
  ghostty
  wezterm
  cava
  tmux
  fzf
  jq
  curl
  wl-clipboard
  grim
  slurp
  wtype
  tesseract
  tesseract-data-eng
  imagemagick
  ffmpeg
  file
  libjxl
  brightnessctl
  ddcutil
  udiskie
  inotify-tools
  python
  python-requests
  python-watchdog
  python-pillow
  python-pillow-jpegxl-plugin
  python-dbus
  python-gobject
  python-opencv
  python-psutil
  gtk3
  gtk4
  gtk-update-icon-cache
  glib2
  dconf
  libnotify
  xdg-utils
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  networkmanager
  bluez
  upower
  pipewire
  wireplumber
  pipewire-pulse
  pipewire-alsa
  pacman-contrib
  polkit
  procps-ng
  psmisc
  iputils
  util-linux
  zoxide
  fd
  zenity
  libqalculate
  gpu-screen-recorder
  fontconfig
  adwaita-icon-theme
  papirus-icon-theme
  noto-fonts
  noto-fonts-emoji
  ttf-roboto
  ttf-jetbrains-mono-nerd
  gnome-control-center
  gnome-calendar
  gnome-clocks
  nautilus
  evolution-data-server
  gnome-settings-daemon
  geoclue
  greetd
  base-devel
  git
)

aur_pkgs=(
  ttf-material-symbols-variable-git
  morewaita-icon-theme
  bibata-cursor-theme-bin
  upscayl-ncnn
  quickshell-git
)

if ((EUID == 0)); then
  echo "don't run this as root, sudo is used when needed" >&2
  exit 1
fi

if [[ ! -d $files ]]; then
  echo "missing $files, run sync.sh first" >&2
  exit 1
fi

# --- requirements ---
missing=()
command -v pacman >/dev/null || missing+=(pacman)
command -v yay >/dev/null || missing+=(yay)

if ((${#missing[@]})); then
  for m in "${missing[@]}"; do
    case $m in
    pacman) echo "pacman is missing: this script only works on Arch" ;;
    yay)
      echo "yay is missing, install it with:"
      echo "  sudo pacman -S --needed git base-devel"
      echo "  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin"
      echo "  cd /tmp/yay-bin; makepkg -si"
      ;;
    esac
  done
  exit 1
fi

sudo -v

# --- packages ---
sudo pacman -Sy
((${#pacman_pkgs[@]})) && sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
((${#aur_pkgs[@]})) && yay -S --needed --noconfirm "${aur_pkgs[@]}"

# --- stage a copy and rewrite the home path ---
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp -a -- "$files/." "$tmp/"

if [[ $HOME != "$old_home" ]]; then
  esc=$(printf '%s' "$HOME" | sed 's/[&|\\]/\\&/g')
  { grep -rIlZF -- "$old_home" "$tmp" || true; } | xargs -0 -r sed -i "s|$old_home|$esc|g"
fi

# --- deploy ---
# -E keeps the exec bit; --no-perms and -O stop rsync from applying the staging
# dir's mode and mtime to $HOME, /, /usr, etc.
[[ -d $tmp/home ]] && rsync -rltEO --no-perms -- "$tmp/home/" "$HOME/"
[[ -d $tmp/root ]] && sudo rsync -rltEO --no-perms --chown=root:root -- "$tmp/root/" /

fc-cache -f

# --- greetd ---
sudo systemctl enable greetd.service

# --- libtranslate ---
python -m venv "$HOME/.local/bin/libretranslate_env"
"$HOME/.local/bin/libretranslate_env/bin/pip" install libretranslate

# --- wallpaper ---
select_wallpaper=$HOME/.local/share/bnsplit/scripts/select-wallpaper
if [[ -f $wallpaper && -x $select_wallpaper ]]; then
  "$select_wallpaper" "$wallpaper" ||
    echo "warning: select-wallpaper failed, run it again from inside the session" >&2
else
  echo "skipping wallpaper: need $wallpaper and an executable select-wallpaper" >&2
fi

echo "done"
