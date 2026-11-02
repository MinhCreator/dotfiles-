#!/usr/bin/env bash
set -euo pipefail

clear

dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
files=$dir/files
wallpaper=$dir/assets/wallpaper.jpg
old_home=/home/bnsplit

stamp=$(date +%Y%m%d-%H%M%S)
backup=$HOME/.local/share/bnsplit-backup/$stamp

# --- output helpers ---
c_blue=$'\e[1;34m' c_green=$'\e[1;32m' c_yellow=$'\e[1;33m' c_red=$'\e[1;31m' c_dim=$'\e[2m' c_off=$'\e[0m'

step() { printf '\n%s==>%s %s%s%s\n' "$c_blue" "$c_off" "$c_green" "$*" "$c_off"; }
info() { printf '    %s%s%s\n' "$c_dim" "$*" "$c_off"; }
warn() { printf '%swarning:%s %s\n' "$c_yellow" "$c_off" "$*" >&2; }
err() { printf '%serror:%s %s\n' "$c_red" "$c_off" "$*" >&2; }

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
  rsync
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
  acl
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
  err "don't run this as root, sudo is used when needed"
  exit 1
fi

if [[ ! -d $files ]]; then
  err "missing $files, run sync.sh first"
  exit 1
fi

# --- requirements ---
step "Checking requirements"
missing=()
command -v pacman >/dev/null || missing+=(pacman)
command -v yay >/dev/null || missing+=(yay)

if ((${#missing[@]})); then
  for m in "${missing[@]}"; do
    case $m in
    pacman) err "pacman is missing: this script only works on Arch" ;;
    yay)
      err "yay is missing, install it with:"
      echo "  sudo pacman -S --needed git base-devel"
      echo "  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin"
      echo "  cd /tmp/yay-bin; makepkg -si"
      ;;
    esac
  done
  exit 1
fi
info "pacman and yay found"

step "Requesting sudo"
sudo -v

# --- packages ---
step "Syncing package databases"
sudo pacman -Sy

if ((${#pacman_pkgs[@]})); then
  step "Installing ${#pacman_pkgs[@]} packages from the official repos"
  sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
fi

if ((${#aur_pkgs[@]})); then
  step "Installing ${#aur_pkgs[@]} packages from the AUR"
  yay -S --needed --noconfirm "${aur_pkgs[@]}"
fi

# --- stage a copy and rewrite the home path ---
step "Staging config files"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp -a -- "$files/." "$tmp/"

if [[ $HOME != "$old_home" ]]; then
  info "rewriting $old_home -> $HOME"
  esc=$(printf '%s' "$HOME" | sed 's/[&|\\]/\\&/g')
  { grep -rIlZF -- "$old_home" "$tmp" || true; } | xargs -0 -r sed -i "s|$old_home|$esc|g"
else
  info "home path already matches, no rewrite needed"
fi

# --- deploy ---
step "Deploying config files"
info "existing files that get overwritten are backed up to:"
info "$backup"
mkdir -p -- "$backup"

if [[ -d $tmp/home ]]; then
  info "copying to $HOME"
  rsync -rltEOc --no-perms \
    --backup --backup-dir="$backup/home" \
    -- "$tmp/home/" "$HOME/"
fi

if [[ -d $tmp/root ]]; then
  info "copying to / (system files)"
  sudo rsync -rltEOc --no-perms --chown=root:root \
    --backup --backup-dir="$backup/root" \
    -- "$tmp/root/" /
fi

# --- root-made backups live in $HOME: hand them back to the user ---
sudo chown -R -- "$(id -u):$(id -g)" "$backup"
find "$backup" -mindepth 1 -type d -empty -delete 2>/dev/null || true

backed_up=0
if [[ -d $backup ]]; then
  backed_up=$(find "$backup" -type f | wc -l)
fi
if ((backed_up == 0)); then
  rmdir -- "$backup" 2>/dev/null || true
fi

step "Preparing greeter directories"
if [[ -f /etc/tmpfiles.d/bn-greetd.conf ]]; then
  sudo systemd-tmpfiles --create /etc/tmpfiles.d/bn-greetd.conf
fi

step "Refreshing font cache"
fc-cache -f

# --- greetd ---
step "Switching display manager to greetd"
if id greeter >/dev/null 2>&1 && [[ -d $HOME/.config/quickshell ]]; then
  info "granting greeter access to the quickshell config"
  sudo setfacl -m u:greeter:x "$HOME"
  sudo setfacl -R -m u:greeter:rwX "$HOME/.config/quickshell"
  find "$HOME/.config/quickshell" -type d \
    -exec sudo setfacl -m d:u:greeter:rwX {} +
fi
if systemctl is-enabled --quiet display-manager.service 2>/dev/null; then
  info "disabling current display manager"
  sudo systemctl disable display-manager.service
fi
sudo systemctl enable greetd.service

# --- libretranslate ---
step "Setting up LibreTranslate virtualenv"
python -m venv "$HOME/.local/bin/libretranslate_env"
"$HOME/.local/bin/libretranslate_env/bin/pip" install libretranslate

# --- wallpaper ---
step "Applying wallpaper"
select_wallpaper=$HOME/.local/share/bnsplit/scripts/select-wallpaper
if [[ -f $wallpaper && -x $select_wallpaper ]]; then
  awww-daemon >/dev/null 2>&1 &
  daemon_pid=$!
  sleep 1
  "$select_wallpaper" "$wallpaper" >/dev/null 2>&1 ||
    warn "select-wallpaper failed, run it again from inside the session"
  kill "$daemon_pid" 2>/dev/null || true
else
  warn "skipping wallpaper: need $wallpaper and an executable select-wallpaper"
fi

# --- summary ---
printf '\n%sAll done!%s\n' "$c_green" "$c_off"
if ((backed_up > 0)); then
  printf '%d existing file(s) were backed up to:\n  %s\n' "$backed_up" "$backup"
  printf 'restore with:\n  rsync -a "%s/home/" "%s/"\n  sudo rsync -a "%s/root/" /\n' "$backup" "$HOME" "$backup"
else
  echo "No existing files were overwritten, so no backup was created."
fi

printf '\n%sRestart recommended%s to start greetd and load the new configuration.\n' "$c_yellow" "$c_off"
read -rp "Reboot now? [y/N] " answer
if [[ $answer == [yY]* ]]; then
  systemctl reboot
fi
