import json
import os
from PyQt6.QtCore import QObject


class JSONConfigManager(QObject):
    """
    Shared base for UI config managers that load a single JSON file.
    Provides _load_json() with consistent error handling.
    """

    def __init__(self, json_path, parent=None):
        super().__init__(parent)
        self._json_path = json_path

    def _load_json(self, default=None):
        """Load JSON from self._json_path. Returns default (or {}) on error or missing file."""
        if default is None:
            default = {}
        try:
            if os.path.exists(self._json_path):
                with open(self._json_path, "r") as f:
                    return json.load(f)
        except Exception as e:
            print(f"Error loading {self._json_path}: {e}")
        return default
