import json
import os
from PyQt6.QtCore import QObject, QAbstractListModel, Qt, QModelIndex, pyqtSlot

class SidebarModel(QAbstractListModel):
    IdRole = Qt.ItemDataRole.UserRole + 1
    TypeRole = Qt.ItemDataRole.UserRole + 2
    NameRole = Qt.ItemDataRole.UserRole + 3
    IconRole = Qt.ItemDataRole.UserRole + 4
    UrlRole = Qt.ItemDataRole.UserRole + 5
    VolatileRole = Qt.ItemDataRole.UserRole + 6

    def __init__(self, config_path, settings_manager=None, task_registry=None, parent=None):
        super().__init__(parent)
        self._config_path = config_path
        self._settings_manager = settings_manager
        self._task_registry = task_registry
        
        self._all_items = []
        self._filtered_items = []
        
        self.load_config()
        
        if self._settings_manager:
            self._settings_manager.developerModeChanged.connect(self._rebuild_list)

    def load_config(self):
        if not os.path.exists(self._config_path):
            print(f"Warning: {self._config_path} not found.")
            return

        with open(self._config_path, 'r') as f:
            data = json.load(f)

        self._all_items = []
        
        for item in data:
            # For category types, we want to try to fetch the actual name/icon from the task registry
            item_type = item.get("type", "")
            item_id = item.get("id", "")
            
            if item_type == "category" and self._task_registry:
                # Look up category data
                cat_match = next((c for c in self._task_registry._category_data if c.get("id") == item_id), None)
                if cat_match:
                    item["name"] = cat_match.get("name", item.get("name", ""))
                    item["icon"] = cat_match.get("icon", item.get("icon", ""))
                else:
                    # Category not found in task_list.json? Skip or keep? Keep as fallback.
                    pass
            
            self._all_items.append(item)
            
        self._rebuild_list()

    def _rebuild_list(self):
        show_hidden = False
        if self._settings_manager:
            # We are using developerMode to toggle hidden tasks
            show_hidden = self._settings_manager.developerMode
            
        self.beginResetModel()
        self._filtered_items = []
        for item in self._all_items:
            # Filter if hidden is true and show_hidden is false
            if item.get("hidden", False) and not show_hidden:
                continue
            self._filtered_items.append(item)
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()):
        return len(self._filtered_items)

    def data(self, index, role):
        if not index.isValid():
            return None

        row = index.row()
        if row < 0 or row >= len(self._filtered_items):
            return None

        item = self._filtered_items[row]

        if role == self.IdRole:
            return item.get("id", "")
        elif role == self.TypeRole:
            return item.get("type", "")
        elif role == self.NameRole:
            return item.get("name", "")
        elif role == self.IconRole:
            return item.get("icon", "")
        elif role == self.UrlRole:
            return item.get("url", "")
        elif role == self.VolatileRole:
            return item.get("hidden", False)
            
        return None

    def roleNames(self):
        return {
            self.IdRole: b"modelId",
            self.TypeRole: b"modelType",
            self.NameRole: b"modelName",
            self.IconRole: b"modelIcon",
            self.UrlRole: b"modelUrl",
            self.VolatileRole: b"modelVolatile"
        }
