from PyQt6.QtCore import pyqtProperty, pyqtSignal
from models.json_config_manager import JSONConfigManager


class UIColorsManager(JSONConfigManager):
    uiColorsChanged = pyqtSignal()

    _DEFAULTS = {
        "window_darker_multiplier": 1.0,
        "sidebar_darker_multiplier": 1.4,
        "queue_darker_multiplier": 1.4,
        "description_darker_multiplier": 1.05,
        "window_background_hex": "",
        "sidebar_background_hex": "",
        "queue_background_hex": "",
        "description_background_hex": "",
        "border_color_hex": "",
        "text_color_hex": "",
        "neutral_text_hex": "",
        "accent_color_hex": ""
    }

    def __init__(self, json_path, parent=None):
        super().__init__(json_path, parent)
        data = self._load_json()
        self._colors = {**self._DEFAULTS, **data}
        self.uiColorsChanged.emit()

    @pyqtProperty('QVariantMap', notify=uiColorsChanged)
    def theme(self):
        return self._colors

