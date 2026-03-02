from PyQt6.QtCore import pyqtProperty, pyqtSignal
from models.json_config_manager import JSONConfigManager


class UIFontsManager(JSONConfigManager):
    uiFontsChanged = pyqtSignal()

    _DEFAULTS = {
        "headline": 16,
        "list_entry": 11,
        "tooltip": 10,
        "small_text": 9
    }

    def __init__(self, json_path, parent=None):
        super().__init__(json_path, parent)
        data = self._load_json()
        self._fonts = {**self._DEFAULTS, **data}
        self.uiFontsChanged.emit()

    @pyqtProperty('QVariantMap', notify=uiFontsChanged)
    def fonts(self):
        return self._fonts
