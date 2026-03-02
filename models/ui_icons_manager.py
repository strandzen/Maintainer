import os
from PyQt6.QtCore import pyqtProperty, pyqtSignal, pyqtSlot
from models.json_config_manager import JSONConfigManager


class UIIconsManager(JSONConfigManager):
    iconsChanged = pyqtSignal()

    _DEFAULT_MAPPING = {
        "advanced": "advanced.svg",
        "app_main": "app-main.svg",
        "clean": "clean.svg",
        "confirm": "confirm.svg",
        "corpse_cleaner": "corpse_cleaner.svg",
        "custom_scripts": "custom_scripts.svg",
        "error": "error.svg",
        "favorite": "favorite.svg",
        "home": "home.svg",
        "maintain_system": "maintain_system.svg",
        "maintain": "maintain_system.svg",
        "quit": "quit.svg",
        "ram": "ram.svg",
        "reboot": "reboot.svg",
        "recommended": "recommended.svg",
        "run": "run.svg",
        "running": "running.svg",
        "scripts": "custom_scripts.svg",
        "settings": "settings.svg",
        "ssd": "ssd.svg",
        "storage": "ssd.svg",
        "success": "success.svg",
        "trash": "clean.svg",
        "warning": "warning.svg"
    }

    def __init__(self, json_path, parent=None):
        super().__init__(json_path, parent)
        self._icons_dir = os.path.join(os.path.dirname(json_path), "icons")
        self._config = {}
        self._icons = {}
        self._exclude_from_colorization = []
        self._load_config()

    def _load_config(self):
        self._config = self._load_json(default={"global": {"scale": 1.0}})
        icon_map = self._config.get("icons", self._DEFAULT_MAPPING)
        self._icons = {
            key: "file://" + os.path.join(self._icons_dir, filename)
            for key, filename in icon_map.items()
        }
        # Fallback: ensure default keys are always present
        for key, filename in self._DEFAULT_MAPPING.items():
            if key not in self._icons:
                self._icons[key] = "file://" + os.path.join(self._icons_dir, filename)
        self._exclude_from_colorization = self._config.get("global", {}).get("excludeFromColorization", [])

    @pyqtProperty('QVariantMap', notify=iconsChanged)
    def icons(self):
        return self._icons

    @pyqtProperty('QVariantMap', notify=iconsChanged)
    def customColors(self):
        return self._config.get("custom_colors", {})

    @pyqtProperty(float, notify=iconsChanged)
    def globalScale(self):
        return self._config.get("global", {}).get("scale", 1.0)

    @pyqtProperty(float, notify=iconsChanged)
    def headerIconScale(self):
        return self._config.get("global", {}).get("headerIconScale", 1.5)

    @pyqtProperty(str, notify=iconsChanged)
    def defaultColor(self):
        return self._config.get("global", {}).get("defaultColor", "#3daee9")

    @pyqtProperty(bool, notify=iconsChanged)
    def colorize(self):
        return self._config.get("global", {}).get("colorize", True)

    @pyqtProperty('QStringList', notify=iconsChanged)
    def excludeFromColorization(self):
        return self._exclude_from_colorization

    @pyqtSlot(str, result=bool)
    def shouldColorize(self, icon_key):
        if not self.colorize:
            return False
        if icon_key in self._exclude_from_colorization:
            return False
        return True

    @pyqtSlot(str, str, result=str)
    @pyqtSlot(str, result=str)
    def iconColor(self, icon_key, fallback_color=""):
        if not self.shouldColorize(icon_key):
            return "transparent"

        custom_color = self._config.get("custom_colors", {}).get(icon_key)
        if custom_color:
            return custom_color

        return fallback_color if fallback_color else self.defaultColor
