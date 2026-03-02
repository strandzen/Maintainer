import subprocess
import os
from PyQt6.QtCore import QThread, pyqtSignal
from .base_task import BaseTask, TaskState
from utils.privileged_process import run_privileged

class GenericCmdWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def __init__(self, command_string, requires_privilege, parent=None):
        super().__init__(parent)
        self.command_string = command_string
        self.requires_privilege = requires_privilege

    def run(self):
        try:
            self.progress.emit(f"Running: {self.command_string}")
            
            if self.requires_privilege:
                # To handle complex shell commands with pkexec, wrap them in sh -c
                proc = run_privileged(["sh", "-c", self.command_string])
                if proc:
                    proc.wait()
                    output = proc.stdout.read()
                    err = proc.stderr.read()
                    if output: self.progress.emit(output.strip())
                    if proc.returncode == 0:
                        self.finished.emit(True)
                    else:
                        self.progress.emit(f"Error: {err.strip()}")
                        self.finished.emit(False)
                else:
                    self.finished.emit(False)
            else:
                proc = subprocess.run(
                    self.command_string, 
                    shell=True, 
                    capture_output=True, 
                    text=True,
                    executable="/bin/bash" # Support bash features like xargs or pipes easily
                )
                
                if proc.stdout:
                    self.progress.emit(proc.stdout.strip())
                    
                if proc.returncode == 0:
                    self.finished.emit(True)
                else:
                    self.progress.emit(f"Error: {proc.stderr.strip()}")
                    self.finished.emit(False)
                    
        except Exception as e:
            self.progress.emit(f"Exception: {str(e)}")
            self.finished.emit(False)

class SizeCmdWorker(QThread):
    sizeCalculated = pyqtSignal(str)

    def __init__(self, size_command, parent=None):
        super().__init__(parent)
        self.size_command = size_command

    def run(self):
        try:
            proc = subprocess.run(
                self.size_command, 
                shell=True, 
                capture_output=True, 
                text=True,
                executable="/bin/bash"
            )
            if proc.returncode == 0 and proc.stdout:
                # E.g. du outputs sizes like "1.2G    ." so we can split or just return it
                output_str = proc.stdout.strip().split('\t')[0] # Grab just the first part if it's du output
                if not output_str:
                    output_str = proc.stdout.strip()
                self.sizeCalculated.emit(output_str)
            else:
                self.sizeCalculated.emit("Size unknown")
        except Exception:
            self.sizeCalculated.emit("Size unknown")

class CommandTask(BaseTask):
    def __init__(self, name, description, command, size_command="", is_recommended=True, is_advanced=False, requires_privilege=False, settings=None, parent=None):
        super().__init__(parent)
        self._name = name
        self._description = description
        self._is_recommended = is_recommended
        self._is_advanced = is_advanced
        self._requires_privilege = requires_privilege
        self.command = command
        self.size_command = size_command
        self._settings = settings

    def _apply_tokens(self, cmd: str) -> str:
        if self._settings:
            cmd = cmd.replace("{cache_count}", str(self._settings.packageCacheCount))
            cmd = cmd.replace("{log_age}", self._settings.journalLogAge)
        return cmd

    def execute(self):
        self.set_state(TaskState.RUNNING)
        self.worker = GenericCmdWorker(self._apply_tokens(self.command), self._requires_privilege, parent=self)
        self.worker.progress.connect(self.progressMessage.emit)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()

    def _on_finished(self, success):
        self.set_state(TaskState.DONE if success else TaskState.ERROR)
        self.finished.emit(success)

    def calculate_size(self):
        if not self.size_command:
            self.set_reclaimed_space("")
            return
        self.set_reclaimed_space("Calculating...")
        self.size_worker = SizeCmdWorker(self._apply_tokens(self.size_command), parent=self)
        self.size_worker.sizeCalculated.connect(self.set_reclaimed_space)
        self.size_worker.start()
