#!/bin/bash

# Create a temporary virtual environment for the build
echo "Creating build environment..."
python -m venv build_venv
source build_venv/bin/activate

# Install dependencies including PyInstaller
echo "Installing build dependencies..."
pip install --upgrade pip
pip install pyinstaller PyQt6 psutil

# Build the binary using the spec file to ensure all configurations are used
pyinstaller --clean Maintainer.spec

echo "Build complete. Binary located in dist/Maintainer"
