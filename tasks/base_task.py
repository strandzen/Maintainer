from enum import IntEnum
from PyQt6.QtCore import QObject, pyqtSignal, QThread, pyqtProperty, pyqtSlot
from utils.formatting import format_bytes


class TaskState(IntEnum):
    IDLE    = 0
    RUNNING = 1
    DONE    = 2
    ERROR   = 3


class BaseTask(QObject):
    stateChanged = pyqtSignal(int)
    progressMessage = pyqtSignal(str)
    finished = pyqtSignal(bool) # True if success, False if failed
    reclaimedSpaceChanged = pyqtSignal(str)
    subItemsChanged = pyqtSignal()
    outputHistoryChanged = pyqtSignal()
    progressTextChanged = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._state = TaskState.IDLE
        self._name = "Unknown Task"
        self._description = ""
        self._is_recommended = False
        self._is_advanced = False
        self._requires_privilege = False
        self._reclaimed_space = "-- MB"
        self._sub_items = []
        self._is_script = False
        self._output_history = ""
        self._progress_text = ""
        self.progressMessage.connect(self._update_progress_text)

    def _update_progress_text(self, msg):
        if self._progress_text != msg:
            self._progress_text = msg
            self.progressTextChanged.emit()

    @pyqtProperty(int, notify=stateChanged)
    def state(self):
        return self._state

    def set_state(self, new_state):
        if self._state != new_state:
            self._state = new_state
            self.stateChanged.emit(new_state)

    @pyqtProperty(str, notify=progressTextChanged)
    def progressText(self):
        return self._progress_text

    @pyqtProperty(bool, constant=True)
    def isScript(self):
        return self._is_script

    @pyqtProperty(bool, constant=True)
    def isRecommended(self):
        return self._is_recommended

    @pyqtProperty(bool, constant=True)
    def isAdvanced(self):
        return self._is_advanced

    @pyqtProperty(bool, constant=True)
    def requiresPrivilege(self):
        return self._requires_privilege

    @pyqtProperty(str, notify=reclaimedSpaceChanged)
    def reclaimedSpace(self):
        return self._reclaimed_space

    @pyqtProperty(str, notify=outputHistoryChanged)
    def outputHistory(self):
        return self._output_history

    @pyqtProperty(str, constant=True)
    def name(self):
        return self._name

    @pyqtProperty(str, constant=True)
    def description(self):
        return self._description

    @property
    def is_recommended(self):
        return self._is_recommended

    @property
    def is_advanced(self):
        return self._is_advanced

    @property
    def requires_privilege(self):
        return self._requires_privilege

    @property
    def reclaimed_space(self):
        return self._reclaimed_space

    def set_reclaimed_space(self, space_str):
        if self._reclaimed_space != space_str:
            self._reclaimed_space = space_str
            self.reclaimedSpaceChanged.emit(self._reclaimed_space)

    @pyqtProperty('QVariantList', notify=subItemsChanged)
    def subItems(self):
        return self._sub_items

    def set_sub_items(self, items):
        self._sub_items = items
        self.subItemsChanged.emit()
        self._recalculate_total_from_sub_items()

    @pyqtSlot(int, bool)
    def set_sub_item_checked(self, index, checked):
        if 0 <= index < len(self._sub_items):
            self._sub_items[index]['checked'] = checked
            # Do NOT emit subItemsChanged here, otherwise QML completely resets the ListView to the top
            self._recalculate_total_from_sub_items()

    def _recalculate_total_from_sub_items(self):
        if not self._sub_items:
            return
        total_bytes = sum(item.get('sizeBytes', 0) for item in self._sub_items if item.get('checked', True))
        self.set_reclaimed_space(format_bytes(total_bytes))

    @pyqtSlot()
    def execute(self):
        """
        Override this method to perform the actual task.
        Must emit finished(result) when done.
        """
        pass

    @pyqtSlot()
    def calculate_size(self):
        """
        Override to proactively calculate size.
        """
        pass


class BaseWorker(QThread):
    """
    Base class for worker threads that emit progress messages and a
    finished(bool) signal. Subclasses implement _execute() which returns bool.
    Exception handling is centralised here so subclasses stay clean.
    """
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def run(self):
        try:
            success = self._execute()
            self.finished.emit(bool(success))
        except Exception as e:
            self.progress.emit(f"Exception: {e}")
            self.finished.emit(False)

    def _execute(self) -> bool:
        """Override in subclass. Return True on success, False on failure."""
        raise NotImplementedError
