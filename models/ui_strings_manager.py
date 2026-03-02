from PyQt6.QtCore import pyqtProperty, pyqtSignal
from models.json_config_manager import JSONConfigManager


class UIStringsManager(JSONConfigManager):
    uiStringsChanged = pyqtSignal()

    def __init__(self, json_path, parent=None):
        super().__init__(json_path, parent)
        self._strings = self._load_json()
        self.uiStringsChanged.emit()

    @pyqtProperty('QVariantMap', notify=uiStringsChanged)
    def ui(self):
        """Expose strings as a nested dictionary structure for QML access"""
        return self._strings
