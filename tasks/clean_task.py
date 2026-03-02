import subprocess
from PyQt6.QtCore import pyqtSignal
from .base_task import BaseTask, BaseWorker, TaskState
from utils.privileged_process import run_privileged

class SimpleCmdWorker(BaseWorker):
    def __init__(self, cmd, msg, parent=None):
        super().__init__(parent)
        self.cmd = cmd
        self.msg = msg

    def _execute(self):
        self.progress.emit(self.msg)
        proc = subprocess.run(self.cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            self.progress.emit(f"Error: {proc.stderr}")
            return False
        return True

class PacmanCacheTask(BaseTask):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._name = "Clear Pacman Cache"
        self._description = "Removes old versions of installed packages, keeping the 3 most recent."
        self._is_recommended = True

    def execute(self):
        self.set_state(TaskState.RUNNING)
        self.worker = SimpleCmdWorker(["paccache", "-r"], "Running paccache -r...")
        self.worker.progress.connect(self.progressMessage.emit)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()

    def _on_finished(self, success):
        self.set_state(TaskState.DONE if success else TaskState.ERROR)
        self.finished.emit(success)

class JournalctlTask(BaseTask):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._name = "Vacuum Journalctl Logs"
        self._description = "Retains only the past 2 weeks of systemd logs."
        self._is_recommended = True

    def execute(self):
        self.set_state(TaskState.RUNNING)
        self.worker = SimpleCmdWorker(["journalctl", "--vacuum-time=2weeks"], "Running journalctl --vacuum-time=2weeks...")
        self.worker.progress.connect(self.progressMessage.emit)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()

    def _on_finished(self, success):
        self.set_state(TaskState.DONE if success else TaskState.ERROR)
        self.finished.emit(success)

class PacmanOrphanWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def run(self):
        try:
            self.progress.emit("Finding orphaned packages...")
            orphans_proc = subprocess.run(["pacman", "-Qtdq"], capture_output=True, text=True)
            orphans = orphans_proc.stdout.strip()
            
            if orphans:
                self.progress.emit(f"Found orphans. Removing requires privileges...")
                pkexec_cmd = ["pacman", "-Rns", "--noconfirm"] + orphans.split()
                proc = run_privileged(pkexec_cmd)
                if proc:
                    proc.wait()
                    if proc.returncode != 0:
                        self.progress.emit(f"Removal failed: {proc.stderr.read()}")
                        self.finished.emit(False)
                        return
                else:
                    self.finished.emit(False)
                    return
            else:
                self.progress.emit("No orphaned packages found.")

            self.finished.emit(True)
        except Exception as e:
            self.progress.emit(f"Error: {str(e)}")
            self.finished.emit(False)

class OrphanPackageTask(BaseTask):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._name = "Remove Orphan Packages"
        self._description = "Finds and removes packages that were installed as dependencies but are no longer required."
        self._is_recommended = True

    def execute(self):
        self.set_state(TaskState.RUNNING)
        self.worker = PacmanOrphanWorker()
        self.worker.progress.connect(self.progressMessage.emit)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()

    def _on_finished(self, success):
        self.set_state(TaskState.DONE if success else TaskState.ERROR)
        self.finished.emit(success)
