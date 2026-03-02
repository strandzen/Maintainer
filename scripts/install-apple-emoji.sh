#!/usr/bin/env bash

# --- 1. Variables and Setup ---
FONT_DIR="$HOME/.local/share/fonts/apple-emoji"
CONFIG_DIR="$HOME/.config/fontconfig"
FONT_URL="https://github.com/samuelngs/apple-emoji-ttf/releases/latest/download/AppleColorEmoji.ttf"

mkdir -p "$FONT_DIR" "$CONFIG_DIR"

# --- 2. Download with Verification ---
echo "📥 Downloading Apple Color Emoji..."
# curl will wait for completion before proceeding
if curl -L --progress-bar "$FONT_URL" -o "$FONT_DIR/AppleColorEmoji.ttf"; then
    echo "✅ Download complete."
else
    echo "❌ ERROR: Download failed. Please check your internet connection."
    exit 1
fi

# --- 3. Create the fonts.conf file ---
echo "⚙️ Configuring font priorities..."
cat << 'EOF' > "$CONFIG_DIR/fonts.conf"
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <alias>
    <family>emoji</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>serif</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>Apple Color Emoji</family></prefer>
  </alias>
</fontconfig>
EOF

# --- 4. Install and Rebuild Cache ---
echo "🔄 Installing font and rebuilding cache..."
# Force a deep rebuild to ensure Noto is cleared
fc-cache -rfv > /dev/null

# --- 5. Verify Installation ---
echo "🔍 Verifying installation..."
# fc-list checks if the system actually sees the new file
if fc-list : family | grep -iq "Apple Color Emoji"; then
    MATCH=$(fc-match emoji)
    echo "🚀 SUCCESS: Apple Color Emoji is installed and set as default."
    echo "Current match: $MATCH"
else
    echo "⚠️ WARNING: Font file found, but system is still prioritizing: $(fc-match emoji)"
fi
