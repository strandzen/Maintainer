import json
import os
from PyQt6.QtCore import QObject, QAbstractListModel, Qt, pyqtProperty, pyqtSlot, QModelIndex, pyqtSignal

from models.task_model import TaskModel
from tasks.command_task import CommandTask

RECOMMENDED_CATEGORIES = ("tools",)

class CategoryModel(QAbstractListModel):
    IdRole = Qt.ItemDataRole.UserRole + 1
    NameRole = Qt.ItemDataRole.UserRole + 2
    IconRole = Qt.ItemDataRole.UserRole + 3

    def __init__(self, categories=None, parent=None):
        super().__init__(parent)
        self._categories = categories or []

    def rowCount(self, parent=QModelIndex()):
        return len(self._categories)

    def data(self, index, role):
        if not index.isValid():
            return None

        row = index.row()
        category = self._categories[row]

        if role == self.IdRole:
            return category["id"]
        elif role == self.NameRole:
            return category["name"]
        elif role == self.IconRole:
            return category["icon"]
        return None

    def roleNames(self):
        return {
            self.IdRole: b"categoryId",
            self.NameRole: b"categoryName",
            self.IconRole: b"categoryIcon"
        }

class TaskRegistry(QObject):
    allTasksChanged = pyqtSignal()

    def __init__(self, config_path, parent=None, settings_manager=None):
        super().__init__(parent)
        self._settings_manager = settings_manager
        self._category_data = [] # List of dicts
        self._task_models = {} # dict mapping category_id -> TaskModel
        self._category_model = CategoryModel(parent=self)
        self._recommended_tasks_model = None
        
        self._all_tasks = [] # Flat list of all tasks for extracting names
        
        self.load_config(config_path, parent)
        self._recommended_tasks_model = self._createRecommendedTasksModel()
        
        if self._settings_manager is not None:
            self._rebuild_all_models()
        else:
            self._rebuild_all_models()

    def load_config(self, config_path, app_parent):
        if not os.path.exists(config_path):
            print(f"Warning: {config_path} not found.")
            return

        with open(config_path, 'r') as f:
            data = json.load(f)

        self._category_data = data.get("categories", [])
        

        self._category_model._categories = self._category_data

    def _rebuild_all_models(self):
        # Clear existing models and flat list
        self._all_tasks.clear()
        for model in self._task_models.values():
            model.clear()

        for category in self._category_data:
            cat_id = category.get("id")
            cat_hidden = category.get("hidden", False)
            if cat_hidden:
                continue
            if cat_id not in self._task_models:
                self._task_models[cat_id] = TaskModel(parent=self.parent())
            
            model = self._task_models[cat_id]
            model.clear()
            
            for task_data in category.get("tasks", []):
                if task_data.get("name") == "Simulation Test":
                    continue
                
                task_type = task_data.get("type", "command")
                
                if task_type == "ghost_config":
                    from tasks.maintain_task import GhostConfigTask
                    task = GhostConfigTask(
                        name=task_data["name"],
                        description=task_data["description"],
                        is_recommended=task_data.get("is_recommended", False),
                        is_advanced=task_data.get("is_advanced", False),
                        settings=self._settings_manager,
                        parent=self.parent()
                    )
                else:
                    task = CommandTask(
                        name=task_data["name"],
                        description=task_data["description"],
                        command=task_data.get("command", ""),
                        size_command=task_data.get("size_command", ""),
                        is_recommended=task_data.get("is_recommended", True),
                        is_advanced=task_data.get("is_advanced", False),
                        requires_privilege=task_data.get("requires_privilege", False),
                        settings=self._settings_manager,
                        parent=self.parent()
                    )
                model.add_task(task)
                self._all_tasks.append(task)

        # Rebuild derivative models
        if self._recommended_tasks_model:
            self._rebuild_recommended_model()
        self.allTasksChanged.emit()

    def _rebuild_recommended_model(self):
        self._recommended_tasks_model.clear()
        for cat_id in RECOMMENDED_CATEGORIES:
            source_model = self._task_models.get(cat_id)
            if source_model:
                for task in source_model.get_all_tasks():
                    if task.is_recommended:
                        self._recommended_tasks_model.add_task(task)

    @pyqtProperty(list, notify=allTasksChanged)
    def allTaskNames(self):
        return [t.name for t in self._all_tasks]

    @pyqtProperty(list, notify=allTasksChanged)
    def allowedFavoriteTaskNames(self):
        # Only show tasks from these specific categories
        allowed_cats = ["clean_system", "maintain_system"]
        names = []
        for cat_id in allowed_cats:
            model = self._task_models.get(cat_id)
            if model:
                tasks = model.get_all_tasks()
                for task in tasks:
                    if task.name not in names:
                        names.append(task.name)
        return names


    @pyqtProperty(QAbstractListModel, constant=True)
    def categories(self):
        return self._category_model

    @pyqtSlot(str, int, result=QObject)
    def getTask(self, category_id, index):
        model = self._task_models.get(category_id)
        if model:
            tasks = model.get_all_tasks()
            if 0 <= index < len(tasks):
                return tasks[index]
        return None

    @pyqtSlot(str, result=QAbstractListModel)
    def getModelForCategory(self, category_id):
        return self._task_models.get(category_id)

    @pyqtProperty(QAbstractListModel, constant=True)
    def recommendedTasksModel(self):
        return self._recommended_tasks_model

    @pyqtSlot(result=QAbstractListModel)
    def getRecommendedTasksModel(self):
        return self._recommended_tasks_model

    def _createRecommendedTasksModel(self):
        """
        Returns a new TaskModel containing all recommended tasks from both Clean and Maintain categories.
        Ensures Clean tasks are added first, then Maintain tasks.
        """
        combined_model = TaskModel(parent=self.parent())

        for cat_id in RECOMMENDED_CATEGORIES:
            source_model = self._task_models.get(cat_id)
            if source_model:
                for task in source_model.get_all_tasks():
                    if task.is_recommended:
                        # We use a NEW task instance if we want them to have independent state,
                        # OR we reuse the same task if we want the state to be shared with the category pages.
                        # Reusing the same task is better for state consistency across the app.
                        combined_model.add_task(task)
        
        return combined_model
