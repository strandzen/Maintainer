import subprocess
import re
from PyQt6.QtCore import QThread, pyqtSignal, pyqtSlot, pyqtProperty
from tasks.base_task import BaseTask, TaskState
from utils.privileged_process import run_privileged

class EfiAuditWorker(QThread):
    finished = pyqtSignal(list)
    error = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

    def run(self):
        try:
            # Run efibootmgr -v to get detailed info
            # Needs root to read all entries sometimes, but usually standard user can read.
            # We'll use subprocess for reading.
            proc = subprocess.run(["efibootmgr", "-v"], capture_output=True, text=True)
            if proc.returncode != 0:
                self.error.emit(f"Failed to read EFI entries: {proc.stderr}")
                return

            entries = []
            
            # Pattern to match: BootXXXX* Name...
            # Example: Boot0001* archlinux	HD(1,GPT,...)/File(\EFI\archlinux\grubx64.efi)
            for line in proc.stdout.splitlines():
                match = re.match(r"^(Boot[0-9A-Fa-f]{4})\*?\s+(.*)$", line)
                if match:
                    boot_num = match.group(1) # e.g., Boot0001
                    details = match.group(2)
                    
                    # Basic heuristic for "ghost" or interesting entries:
                    # We will list all entries but let the user decide, as perfectly 
                    # detecting a "ghost" entry without mounting every partition is tough.
                    # Or we could just list them all.
                    
                    # Clean up the name a bit
                    name_parts = details.split('\t')
                    display_name = name_parts[0] if len(name_parts) > 0 else details
                    
                    entries.append({
                        "name": display_name,
                        "boot_id": boot_num,
                        "details": details,
                        "checked": False # For the UI checkbox
                    })

            self.finished.emit(entries)

        except FileNotFoundError:
            self.error.emit("efibootmgr not found. Is your system EFI?")
        except Exception as e:
            self.error.emit(str(e))

class EfiCleanWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def __init__(self, boot_ids, parent=None):
        super().__init__(parent)
        self.boot_ids = boot_ids # List of strings like 'Boot0001'

    def run(self):
        try:
            success = True
            for bid in self.boot_ids:
                # Extract the hex number from 'BootXXXX'
                match = re.search(r"Boot([0-9A-Fa-f]{4})", bid)
                if not match:
                    continue
                hex_id = match.group(1)
                
                self.progress.emit(f"Removing {bid}...")
                
                # Use pkexec to remove the boot entry
                proc = run_privileged(["efibootmgr", "-B", "-b", hex_id])
                if proc:
                    proc.wait()
                    if proc.returncode != 0:
                        err = proc.stderr.read()
                        self.progress.emit(f"Error removing {bid}: {err.strip()}")
                        success = False
                else:
                    success = False
                    
            self.finished.emit(success)
        except Exception as e:
            self.progress.emit(f"Exception: {str(e)}")
            self.finished.emit(False)


class EfiBootTask(BaseTask):
    """
    Task to scan and remove EFI Boot entries.
    """
    totalFoundChanged = pyqtSignal()
    
    def __init__(self, name, description, is_recommended=False, is_advanced=True, requires_privilege=True, parent=None):
        super().__init__(parent)
        self._name = name
        self._description = description
        self._is_recommended = is_recommended
        self._is_advanced = is_advanced
        self._requires_privilege = requires_privilege
        self._sub_items = []
        self._total_found = 0
        
        self.scan_worker = None
        self.clean_worker = None

    @pyqtProperty(int, notify=totalFoundChanged)
    def totalFound(self):
        return self._total_found

    @pyqtSlot()
    def scan(self):
        if self.state == TaskState.RUNNING:
            return

        self.progressMessage.emit("Scanning EFI boot entries...")
        self.set_state(TaskState.RUNNING)
        self._sub_items = []
        self._total_found = 0
        self.subItemsChanged.emit()

        self.scan_worker = EfiAuditWorker(parent=self)
        self.scan_worker.finished.connect(self._on_scan_finished)
        self.scan_worker.error.connect(self._on_scan_error)
        self.scan_worker.start()

    def _on_scan_finished(self, entries):
        self._sub_items = entries
        self._total_found = len(entries)
        if self._total_found > 0:
            self.progressMessage.emit(f"Found {self._total_found} boot entries.")
            self.set_state(TaskState.IDLE)
        else:
            self.progressMessage.emit("No boot entries found.")
            self.set_state(TaskState.DONE)
        self.totalFoundChanged.emit()
        self.subItemsChanged.emit()

    def _on_scan_error(self, err_msg):
        self.progressMessage.emit(f"Error: {err_msg}")
        self.set_state(TaskState.ERROR)

    @pyqtSlot(int, bool)
    def set_sub_item_checked(self, index, checked):
        if 0 <= index < len(self._sub_items):
            self._sub_items[index]["checked"] = checked
            self.subItemsChanged.emit()

    @pyqtSlot()
    def execute(self):
        if self.state == TaskState.RUNNING:
            return
        items_to_clean = [item["boot_id"] for item in self._sub_items if item.get("checked", False)]

        if not items_to_clean:
            self.progressMessage.emit("No items selected for removal.")
            self.set_state(TaskState.DONE)
            return

        self.set_state(TaskState.RUNNING)
        self.clean_worker = EfiCleanWorker(items_to_clean, parent=self)
        self.clean_worker.progress.connect(self.progressMessage.emit)
        self.clean_worker.finished.connect(self._on_clean_finished)
        self.clean_worker.start()

    def _on_clean_finished(self, success):
        if success:
            self.progressMessage.emit("Selected entries successfully removed.")
            self.set_state(TaskState.DONE)
        else:
            self.progressMessage.emit("Finished with some errors.")
            self.set_state(TaskState.ERROR)
            
        # Clear items to force a re-scan requirement
        self._sub_items = []
        self._total_found = 0
        self.totalFoundChanged.emit()
        self.subItemsChanged.emit()
