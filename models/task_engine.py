from PyQt6.QtCore import QObject, pyqtSignal, pyqtSlot, pyqtProperty

class TaskEngine(QObject):
    # Signals for QML
    taskStarted = pyqtSignal(str) # Name of task
    taskProgress = pyqtSignal(str) # Progress message
    taskFinished = pyqtSignal(str, bool) # Name, success
    allTasksFinished = pyqtSignal()
    
    overallProgressChanged = pyqtSignal()
    currentTaskChanged = pyqtSignal()
    queueChanged = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._queue = []
        self._current_index = -1
        self._overall_progress = 0.0

    @pyqtProperty('QVariantList', notify=queueChanged)
    def queue(self):
        return self._queue

    @pyqtProperty(float, notify=overallProgressChanged)
    def overallProgress(self):
        return self._overall_progress

    @pyqtProperty(QObject, notify=currentTaskChanged)
    def currentTask(self):
        if 0 <= self._current_index < len(self._queue):
            return self._queue[self._current_index]
        return None

    @pyqtSlot()
    def reset(self):
        self._queue = []
        self._current_index = -1
        self._overall_progress = 0.0
        self.queueChanged.emit()
        self.overallProgressChanged.emit()
        self.currentTaskChanged.emit()

    @pyqtSlot(list)
    def start_tasks(self, tasks):
        """
        Takes a list of BaseTask instances and starts executing them sequentially.
        """
        self._queue = tasks
        self._current_index = -1
        self._overall_progress = 0.0
        self.queueChanged.emit()
        self.overallProgressChanged.emit()
        self.currentTaskChanged.emit()

        if not self._queue:
            self.allTasksFinished.emit()
            return

        self._execute_next()

    def _execute_next(self):
        self._current_index += 1
        
        # Calculate overall progress
        if len(self._queue) > 0:
            self._overall_progress = self._current_index / len(self._queue)
            self.overallProgressChanged.emit()

        if self._current_index < len(self._queue):
            current_task = self._queue[self._current_index]
            
            # Connect signals
            current_task.progressMessage.connect(self._on_task_progress)
            current_task.finished.connect(self._on_task_finished)
            
            self.taskStarted.emit(current_task.name)
            self.currentTaskChanged.emit()
            current_task.execute()
        else:
            self._overall_progress = 1.0
            self.overallProgressChanged.emit()
            self.currentTaskChanged.emit()
            self.allTasksFinished.emit()

    def _on_task_progress(self, msg):
        self.taskProgress.emit(msg)

    def _on_task_finished(self, success):
        # Bound check to prevent IndexError
        if 0 <= self._current_index < len(self._queue):
            task = self._queue[self._current_index]
            self.taskFinished.emit(task.name, success)
            
            # Disconnect signals so they don't fire redundantly if reused
            try:
                task.progressMessage.disconnect(self._on_task_progress)
                task.finished.disconnect(self._on_task_finished)
            except TypeError:
                pass # Already disconnected

        # Proceed to next task regardless of failure for now
        self._execute_next()
