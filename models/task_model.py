from PyQt6.QtCore import QAbstractListModel, Qt, pyqtSignal, pyqtSlot, pyqtProperty, QModelIndex
from utils.formatting import format_bytes

class TaskModel(QAbstractListModel):
    NameRole = Qt.ItemDataRole.UserRole + 1
    DescriptionRole = Qt.ItemDataRole.UserRole + 2
    IsRecommendedRole = Qt.ItemDataRole.UserRole + 3
    IsCheckedRole = Qt.ItemDataRole.UserRole + 4
    StateRole = Qt.ItemDataRole.UserRole + 5
    ReclaimedSpaceRole = Qt.ItemDataRole.UserRole + 6
    SubItemsRole = Qt.ItemDataRole.UserRole + 7
    RequiresPrivilegeRole = Qt.ItemDataRole.UserRole + 8
    IsAdvancedRole = Qt.ItemDataRole.UserRole + 9

    checkedCountChanged = pyqtSignal()
    reclaimedSpaceTotalChanged = pyqtSignal()
    possibleSpaceTotalChanged = pyqtSignal()

    def __init__(self, tasks=None, parent=None):
        super().__init__(parent)
        self._tasks = tasks or []
        self._checked_states = [task.is_recommended for task in self._tasks]
        self._task_to_row = {task: i for i, task in enumerate(self._tasks)}

    def clear(self):
        self.beginResetModel()
        self._tasks.clear()
        self._checked_states.clear()
        self._task_to_row.clear()
        self.endResetModel()
        self.checkedCountChanged.emit()
        self.reclaimedSpaceTotalChanged.emit()
        self.possibleSpaceTotalChanged.emit()

    def add_task(self, task):
        row = len(self._tasks)
        self.beginInsertRows(QModelIndex(), row, row)
        self._tasks.append(task)
        self._checked_states.append(task.is_recommended)
        self._task_to_row[task] = row
        # Connect to task signals so the UI can update
        task.stateChanged.connect(lambda state, t=task: self._on_task_state_changed(t))
        task.reclaimedSpaceChanged.connect(lambda space, t=task: self._on_task_reclaimed_space_changed(t))
        task.subItemsChanged.connect(lambda t=task: self._on_task_subitems_changed(t))
        self.endInsertRows()
        
        # Trigger size calculation now that it's in the model
        task.calculate_size()
        self.checkedCountChanged.emit()

    def rowCount(self, parent=QModelIndex()):
        return len(self._tasks)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < self.rowCount()):
            return None
        
        task = self._tasks[index.row()]

        if role == self.NameRole:
            return task.name
        elif role == self.DescriptionRole:
            return task.description
        elif role == self.IsRecommendedRole:
            return task.is_recommended
        elif role == self.RequiresPrivilegeRole:
            return task.requires_privilege
        elif role == self.IsAdvancedRole:
            return task.is_advanced
        elif role == self.IsCheckedRole:
            return self._checked_states[index.row()]
        elif role == self.StateRole:
            return task.state
        elif role == self.ReclaimedSpaceRole:
            return task.reclaimed_space
        elif role == self.SubItemsRole:
            return task.subItems
        return None

    def setData(self, index, value, role):
        if not index.isValid() or not (0 <= index.row() < self.rowCount()):
            return False

        if role == self.IsCheckedRole:
            self._checked_states[index.row()] = bool(value)
            self.dataChanged.emit(index, index, [self.IsCheckedRole])
            self.checkedCountChanged.emit()
            self.reclaimedSpaceTotalChanged.emit()
            return True
            
        return False

    def roleNames(self):
        return {
            self.NameRole: b"name",
            self.DescriptionRole: b"description",
            self.IsRecommendedRole: b"isRecommended",
            self.IsCheckedRole: b"isChecked",
            self.StateRole: b"state",
            self.ReclaimedSpaceRole: b"reclaimedSpace",
            self.SubItemsRole: b"subItems",
            self.RequiresPrivilegeRole: b"requiresPrivilege",
            self.IsAdvancedRole: b"isAdvanced"
        }

    def _on_task_state_changed(self, task):
        row = self._task_to_row.get(task, -1)
        if row != -1:
            idx = self.index(row, 0)
            self.dataChanged.emit(idx, idx, [self.StateRole])

    def _on_task_reclaimed_space_changed(self, task):
        row = self._task_to_row.get(task, -1)
        if row != -1:
            idx = self.index(row, 0)
            self.dataChanged.emit(idx, idx, [self.ReclaimedSpaceRole])
            self.reclaimedSpaceTotalChanged.emit()
            self.possibleSpaceTotalChanged.emit()

    def _on_task_subitems_changed(self, task):
        row = self._task_to_row.get(task, -1)
        if row != -1:
            idx = self.index(row, 0)
            self.dataChanged.emit(idx, idx, [self.SubItemsRole])

    def _parse_size(self, size_str):
        if not size_str or size_str in ("Calculating...", "Size unknown"):
            return 0
        try:
            # size_str format might be "1.2G", "48.1M", "100K", or even "0.002 MB"
            s = size_str.replace("~", "").replace(" reclaimed", "").strip()
            if not s:
                return 0
            
            # Handle cases like "0.002 MB"
            if " " in s:
                value_str, unit = s.split(" ", 1)
                value = float(value_str)
                unit = unit.upper()
                if unit == "KB": return value * 1024
                if unit == "MB": return value * 1024**2
                if unit == "GB": return value * 1024**3
                if unit == "TB": return value * 1024**4
                return value

            # du outputs like 14M, 2.5G, 100K
            if s[-1] in 'Kk':
                return float(s[:-1]) * 1024
            elif s[-1] in 'Mm':
                return float(s[:-1]) * 1024**2
            elif s[-1] in 'Gg':
                return float(s[:-1]) * 1024**3
            elif s[-1] in 'Tt':
                return float(s[:-1]) * 1024**4
            elif s.isdigit() or "." in s:
                return float(s)
            return 0
        except Exception:
            return 0

    @pyqtProperty(str, notify=reclaimedSpaceTotalChanged)
    def totalReclaimedSpaceStr(self):
        total_bytes = sum(
            self._parse_size(task.reclaimed_space)
            for i, task in enumerate(self._tasks)
            if self._checked_states[i]
        )
        return format_bytes(int(total_bytes))

    @pyqtProperty(int, notify=reclaimedSpaceTotalChanged)
    def totalReclaimedSpaceBytes(self):
        total_bytes = 0
        for i, task in enumerate(self._tasks):
            if self._checked_states[i]:
                total_bytes += int(self._parse_size(task.reclaimed_space))
        return total_bytes

    @pyqtProperty(int, notify=possibleSpaceTotalChanged)
    def totalPossibleReclaimedSpaceBytes(self):
        total_bytes = 0
        for task in self._tasks:
            total_bytes += int(self._parse_size(task.reclaimed_space))
        return total_bytes

    @pyqtProperty(int, notify=checkedCountChanged)
    def checkedCount(self):
        return sum(self._checked_states)

    @pyqtProperty(int, notify=checkedCountChanged)
    def totalCount(self):
        return len(self._tasks)

    @pyqtSlot(result=list)
    def get_checked_tasks(self):
        return [task for i, task in enumerate(self._tasks) if self._checked_states[i]]

    def get_all_tasks(self):
        return self._tasks

    @pyqtSlot(int, result='QVariant')
    def get_task(self, index):
        if 0 <= index < len(self._tasks):
            return self._tasks[index]
        return None

    @pyqtSlot(int, int, bool)
    def setSubItemChecked(self, task_row, sub_index, checked):
        if 0 <= task_row < len(self._tasks):
            task = self._tasks[task_row]
            task.set_sub_item_checked(sub_index, checked)

    @pyqtSlot(int, result=list)
    def getSubItems(self, row):
        if 0 <= row < len(self._tasks):
            return self._tasks[row].subItems
        return []
