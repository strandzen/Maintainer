# Maintainer

**Maintainer** is a premium, modern system maintenance utility for Linux, specifically designed to integrate seamlessly with the KDE Plasma desktop environment. Built using Python, PyQt6, and the Kirigami UI framework, it provides a powerful yet intuitive interface for keeping your system clean, updated, and healthy.

![Maintainer Screenshot](icons/app_icon.svg) <!-- Placeholder for a real screenshot link if available -->

## Features

- 🚀 **System Health Dashboard**: Real-time monitoring of SSD health, RAM usage, and storage distribution with dynamic sparkline graphs.
- 📦 **Native Package Manager**: Comprehensive interface for Arch Linux package management, supporting popular AUR helpers like `paru` and `yay`.
- 💎 **AppImage Hub**: A centralized manager to browse, download, and manage AppImages with integrated version tracking.
- 🧹 **Corpse Cleaner**: Intelligent identification and removal of orphaned configuration files, cache directories, and system "dead weight".
- 🔐 **EFI Boot Audit**: Advanced tooling to audit and manage EFI boot entries safely.
- 🖌️ **Native Integration**: Full support for KDE Plasma's Breeze theme, including Dark/Light mode switching and system palette inheritance.

## Architecture

Maintainer is built with a strictly decoupled architecture:
- **Backend**: Python 3 code leveraging `PyQt6` for logic and system integration.
- **Frontend**: Responsive, modern UI implemented in `QML` using the `Kirigami` framework.
- **Design System**: Centralized JSON-based configuration for colors, icons, and typography.

## Getting Started

### Prerequisites

Ensure you have the following system dependencies installed:
- Python 3.10+
- PyQt6
- KDE Kirigami
- Kirigami Addons

### Running from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/strandzen/Maintainer.git
   cd Maintainer
   ```
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt # If available, or pip install PyQt6 psutil
   ```
3. Launch the application:
   ```bash
   python main.py
   ```

## Building a Standalone Binary

Maintainer can be bundled into a single standalone executable using PyInstaller.

1. Run the included build script:
   ```bash
   chmod +x build_binary.sh
   ./build_binary.sh
   ```
2. The bundled binary will be located at `dist/Maintainer`.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
