from PyQt6.QtCore import pyqtSlot
from tasks.command_task import CommandTask, GenericCmdWorker
from tasks.base_task import TaskState

class ScriptTask(CommandTask):
    """
    A specialized task for running shell scripts that captures 
    and exposes its entire output history to QML.
    """
    def __init__(self, name, description, command, size_command="", is_recommended=False, is_advanced=False, requires_privilege=False, settings=None, parent=None):
        super().__init__(name, description, command, size_command, is_recommended, is_advanced, requires_privilege, settings, parent)
        self._is_script = True
        self._output_history = ""

    def _append_to_history(self, msg):
        # Only append non-empty messages to avoid weird spacing
        if msg:
            if self._output_history:
                self._output_history += "\n" + msg
            else:
                self._output_history = msg
            self.outputHistoryChanged.emit()

    @pyqtSlot()
    def execute(self):
        self.set_state(TaskState.RUNNING)
        self._output_history = ""
        self.outputHistoryChanged.emit()
        self.worker = GenericCmdWorker(self._apply_tokens(self.command), self._requires_privilege, parent=self)
        self.worker.progress.connect(self.progressMessage.emit)
        self.worker.progress.connect(self._append_to_history)
        self.worker.finished.connect(self._on_finished)
        self.worker.start()
