import json
import os
from PyQt6.QtCore import QObject, QAbstractListModel, Qt, pyqtProperty, pyqtSlot, QModelIndex, pyqtSignal

from models.task_model import TaskModel
from tasks.command_task import CommandTask
from tasks.efi_boot_task import EfiBootTask

RECOMMENDED_CATEGORIES = ("clean_system", "maintain_system")

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
        self._favorites_tasks_model = TaskModel(parent=parent)
        
        self.load_config(config_path, parent)
        self._recommended_tasks_model = self._createRecommendedTasksModel()
        
        if self._settings_manager is not None:
            self._settings_manager.favoriteTasksChanged.connect(self._rebuild_favorites_model)
            self._settings_manager.developerModeChanged.connect(self._rebuild_all_models)
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
        
        # --- Auto-discover scripts ---
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        scripts_dir = os.path.join(project_root, "scripts")
        
        if os.path.exists(scripts_dir) and os.path.isdir(scripts_dir):
            script_tasks = []
            for filename in sorted(os.listdir(scripts_dir)):
                if filename.endswith(".sh"):
                    script_path = os.path.join(scripts_dir, filename)
                    # Create a readable name from the filename: "my-script.sh" -> "My Script"
                    name_base = filename[:-3].replace("-", " ").replace("_", " ")
                    readable_name = name_base.title()
                    
                    script_tasks.append({
                        "name": readable_name,
                        "description": f"Runs the {filename} script.",
                        "command": f"bash {script_path}",
                        "type": "script",
                        "is_recommended": False,
                        "requires_privilege": False # Assume user scripts manage their own privilege if needed, or update later
                    })
            
            if script_tasks:
                self._category_data.append({
                    "id": "custom_scripts",
                    "name": "Custom Scripts",
                    "icon": "custom_scripts", # Using the dedicated custom_scripts.svg icon
                    "tasks": script_tasks
                })
        # -----------------------------

        self._category_model._categories = self._category_data

    def _rebuild_all_models(self):
        # Clear existing models and flat list
        self._all_tasks.clear()
        for model in self._task_models.values():
            model.clear()
        
        show_sim = False
        if self._settings_manager:
            show_sim = self._settings_manager.developerMode

        for category in self._category_data:
            cat_id = category.get("id")
            cat_hidden = category.get("hidden", False)
            if cat_hidden and not show_sim:
                continue
            if cat_id not in self._task_models:
                self._task_models[cat_id] = TaskModel(parent=self.parent())
            
            model = self._task_models[cat_id]
            model.clear()
            
            for task_data in category.get("tasks", []):
                if not show_sim and task_data.get("name") == "Simulation Test":
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
                elif task_type == "script":
                    from tasks.script_task import ScriptTask
                    task = ScriptTask(
                        name=task_data["name"],
                        description=task_data["description"],
                        command=task_data.get("command", ""),
                        is_recommended=task_data.get("is_recommended", False),
                        is_advanced=task_data.get("is_advanced", False),
                        requires_privilege=task_data.get("requires_privilege", False),
                        settings=self._settings_manager,
                        parent=self.parent()
                    )
                elif task_type == "efi_audit":
                    task = EfiBootTask(
                        name=task_data["name"],
                        description=task_data["description"],
                        is_recommended=task_data.get("is_recommended", False),
                        is_advanced=task_data.get("is_advanced", True),
                        requires_privilege=task_data.get("requires_privilege", True),
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
        self._rebuild_favorites_model()
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
        allowed_cats = ["clean_system", "maintain_system", "custom_scripts"]
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
    def favoritesTaskModel(self):
        return self._favorites_tasks_model

    def _rebuild_favorites_model(self):
        if not self._settings_manager:
            return
        self._favorites_tasks_model.clear()
        fav_names = self._settings_manager.favoriteTasks
        for task in self._all_tasks:
            if task.name in fav_names:
                self._favorites_tasks_model.add_task(task)

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
