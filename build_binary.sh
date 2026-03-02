#!/bin/bash

# Create a temporary virtual environment for the build
echo "Creating build environment..."
python -m venv build_venv
source build_venv/bin/activate

# Install dependencies including PyInstaller
echo "Installing build dependencies..."
pip install --upgrade pip
pip install pyinstaller PyQt6 psutil

# Build the binary
# --onefile: bundle everything into a single executable
# --windowed: don't open a terminal window when running
# --name: name of the output binary
# --add-data: include assets in the bundle (format: "source:destination")
pyinstaller --onefile --windowed --name Maintainer \
    --add-data "qml:qml" \
    --add-data "icons:icons" \
    --add-data "tasks:tasks" \
    --add-data "utils:utils" \
    --add-data "ui_colors.json:." \
    --add-data "ui_fonts.json:." \
    --add-data "ui_icons.json:." \
    --add-data "ui_left_list.json:." \
    --add-data "ui_strings.json:." \
    --add-data "tasks_config.json:." \
    --add-data "appimage_custom.json:." \
    --add-data "package_favorites.json:." \
    main.py

echo "Build complete. Binary located in dist/Maintainer"
