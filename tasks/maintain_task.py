import subprocess
import os
import shutil
from PyQt6.QtCore import QThread, pyqtSignal, pyqtSlot
from .base_task import BaseTask, BaseWorker, TaskState

class GhostConfigSizeWorker(QThread):
    sizeCalculated = pyqtSignal(list)

    def __init__(self, blacklist_str, custom_paths_str="", parent=None):
        super().__init__(parent)
        self.blacklist = [w.strip().lower() for w in blacklist_str.split(',') if w.strip()]
        self.custom_paths = [p.strip() for p in custom_paths_str.split(',') if p.strip()]

        # Load external ccblacklist.json
        blacklist_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ccblacklist.json")
        if os.path.exists(blacklist_path):
            try:
                import json
                with open(blacklist_path, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        self.blacklist.extend([str(item).lower().strip() for item in data])
            except Exception as e:
                print(f"Error loading ccblacklist.json: {e}")

    def run(self):
        try:
            pacman_proc = subprocess.run(["pacman", "-Qq"], capture_output=True, text=True)
            installed_pkgs = set(pacman_proc.stdout.splitlines())

            installed_flatpaks = set()
            if shutil.which("flatpak"):
                flatpak_proc = subprocess.run(["flatpak", "list", "--app", "--columns=application"], capture_output=True, text=True)
                for line in flatpak_proc.stdout.splitlines():
                    if line.strip():
                        installed_flatpaks.add(line.strip().lower())
                        installed_flatpaks.add(line.strip().split('.')[-1].lower())

            # Common config folders that aren't tied to a specific installed pacman pkg
            system_ignore = {"pulse", "systemd", "gtk-3.0", "gtk-4.0", "fontconfig", "dconf", "xfce4", "kde", "kde.org", "menus", "mime", "autostart", "trash", "keyrings", "gvfs", "ibus", "nautilus", "kdeglobals", "kio", "gtk-2.0"}
            ignore_set = installed_pkgs.union(installed_flatpaks).union(system_ignore).union(set(self.blacklist))

            sub_items = []
            dirs_to_scan = [os.path.expanduser("~/.config"), os.path.expanduser("~/.local/share"), os.path.expanduser("~/.local/bin")]

            for custom_path in self.custom_paths:
                expanded = os.path.expanduser(custom_path)
                if expanded not in dirs_to_scan: # avoid duplicates
                    dirs_to_scan.append(expanded)

            for base_dir in dirs_to_scan:
                if not os.path.exists(base_dir):
                    continue
                for item in os.listdir(base_dir):
                    item_path = os.path.join(base_dir, item)
                    if os.path.isdir(item_path):
                        if item.lower() not in ignore_set:
                            # It's an orphan! Calculate its size
                            size_bytes = self._get_dir_size(item_path)
                            if size_bytes > 0:
                                sub_items.append({
                                    "name": os.path.join(os.path.basename(base_dir), item),
                                    "description": item_path,
                                    "sizeBytes": size_bytes,
                                    "checked": False # Off by default for safety
                                })

            self.sizeCalculated.emit(sub_items)

        except Exception as e:
            print(f"GhostConfigSizeWorker Error: {e}")
            self.sizeCalculated.emit([])

    def _get_dir_size(self, path):
        total = 0
        for dirpath, _, filenames in os.walk(path):
            for f in filenames:
                fp = os.path.join(dirpath, f)
                if not os.path.islink(fp):
                    try:
                        total += os.path.getsize(fp)
                    except OSError:
                        pass
        return total


class GhostConfigExecWorker(BaseWorker):
    def __init__(self, sub_items, parent=None):
        super().__init__(parent)
        self.sub_items = sub_items

    def _execute(self):
        self.progress.emit("Cleaning orphaned ghost configurations...")
        for item in self.sub_items:
            if item.get("checked", False):
                target_path = item.get("description", "")
                if target_path and os.path.exists(target_path):
                    self.progress.emit(f"Removing {target_path}")
                    subprocess.run(["rm", "-rf", target_path], check=False)
        self.progress.emit("Finished cleaning ghost configs.")
        return True


class GhostConfigTask(BaseTask):
    def __init__(self, name, description, is_recommended=False, is_advanced=False, settings=None, parent=None):
        super().__init__(parent)
        self._name = name
        self._description = description
        self._is_recommended = is_recommended
        self._is_advanced = is_advanced
        self._requires_privilege = False
        self._settings = settings
        self.size_worker = None
        self.exec_worker = None

    @pyqtSlot()
    def calculate_size(self):
        self.set_state(TaskState.RUNNING)
        self.set_sub_items([])
        self.set_reclaimed_space("Scanning...")
        sm = self._settings
        blacklist = sm.ghostConfigBlacklist if sm else ""
        custom_paths = sm.corpseCleanerCustomPaths if sm else ""
        self.size_worker = GhostConfigSizeWorker(blacklist, custom_paths)
        self.size_worker.sizeCalculated.connect(self._on_size_calculated)
        self.size_worker.start()

    def _on_size_calculated(self, sub_items):
        self.set_state(TaskState.DONE)
        self.set_sub_items(sub_items)
        if not sub_items:
            self.set_reclaimed_space("0 B")

    @pyqtSlot()
    def execute(self):
        self.set_state(TaskState.RUNNING)
        # Filter checked items directly from the internal list
        to_clean = [it for it in self._sub_items if it.get("checked", False)]
        if not to_clean:
            self.set_state(TaskState.DONE)
            self.finished.emit(True)
            return

        self.exec_worker = GhostConfigExecWorker(to_clean)
        self.exec_worker.progress.connect(self.progressMessage.emit)
        self.exec_worker.finished.connect(self._on_finished)
        self.exec_worker.start()

    def _on_finished(self, success):
        self.set_state(TaskState.DONE if success else TaskState.ERROR)
        # Clear sub-items to force refresh and indicate cleaning is done
        self.set_sub_items([])
        if success:
            self.calculate_size()
        self.finished.emit(success)
