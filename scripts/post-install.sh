#!/usr/bin/env bash

# --- 1. PRIVILEGE CHECK ---
# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "🚀 Re-running with sudo for system tasks..."
   exec sudo "$0" "$@"
fi

echo "------------------------------------------"
echo "🌟 Starting Optimized Post-Install Script"
echo "------------------------------------------"

# --- 2. SYSTEM UPDATES ---
echo "🔍 Checking for system updates..."
# 'checkupdates' is from pacman-contrib; avoids locking the db
if checkupdates &> /dev/null; then
    echo "📦 Updates found. Upgrading system..."
    pacman -Syu --noconfirm

    # Kernel/Systemd updates often require a reboot on CachyOS
    if [ -f /var/run/reboot-required ] || pacman -Q linux-cachyos | grep -q "$(uname -r)"; then
        echo "⚠️  Kernel update detected. Please reboot and run again."
        exit 0
    fi
else
    echo "✅ System is already up to date."
fi

# Keep sudo active for the duration of the script
sudo -v

# --- 3. PACMAN INSTALLATIONS ---
# List your apps here. Simple to add/remove.
PACKAGES=(
    "fastfetch" "btop" "micro" "git" "base-devel" "konsave" "klassy"
    "darkly" "kde-material-you-colors" "protonup-qt" "obs-studio"
    "stremio" "zen-browser-bin" "helium-browser-bin" "blender"
    "steam" "topgrade" "lsd" "kate" "qbittorrent" "unzip"
)

echo "📥 Installing apps via Pacman..."
pacman -S --needed --noconfirm "${PACKAGES[@]}"

# --- 4. EXTERNAL FONT INSTALLATIONS ---
# San Francisco Pro (GitHub Binary Install)
SF_FONT_DIR="$HOME/.local/share/fonts/sf-pro"
if [ ! -d "$SF_FONT_DIR" ]; then
    echo "📥 Installing San Francisco Pro fonts..."
    SF_TEMP_DIR=$(mktemp -d)
    SF_URL="https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts/archive/refs/heads/master.zip"

    mkdir -p "$SF_FONT_DIR"
    if curl -L "$SF_URL" -o "$SF_TEMP_DIR/fonts.zip"; then
        unzip -q "$SF_TEMP_DIR/fonts.zip" -d "$SF_TEMP_DIR"
        find "$SF_TEMP_DIR" -type f \( -name "*.otf" -o -name "*.ttf" \) -exec mv {} "$SF_FONT_DIR/" \;
        echo "✅ SF Pro installed."
    fi
    rm -rf "$SF_TEMP_DIR"
else
    echo "✅ SF Pro already exists."
fi

# --- 5. SUB-SCRIPTS EXECUTION ---
# This looks for specific .sh files in the same folder as this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# List your extra scripts here to execute them in order
EXTRA_SCRIPTS=(
    "install_apple_emoji.sh"
    # "setup_gaming.sh"
)

for script in "${EXTRA_SCRIPTS[@]}"; do
    if [ -f "$SCRIPT_DIR/$script" ]; then
        echo "🛠️  Running: $script"
        bash "$SCRIPT_DIR/$script"
    else
        echo "❓ Optional script $script not found. Skipping."
    fi
done

# --- 6. FINALIZATION ---
echo "🔄 Refreshing font cache..."
fc-cache -f

echo "------------------------------------------"
echo "🎉 Setup complete! System is ready."
echo "------------------------------------------"
