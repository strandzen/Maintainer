import os
import shutil
import subprocess
import socket
from collections import deque
import psutil
from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal, pyqtSlot, QTimer, QThread, QAbstractListModel, Qt, QModelIndex

class ProcessModel(QAbstractListModel):
    PidRole = Qt.ItemDataRole.UserRole + 1
    NameRole = Qt.ItemDataRole.UserRole + 2
    UserRole = Qt.ItemDataRole.UserRole + 3
    CpuRole = Qt.ItemDataRole.UserRole + 4
    MemoryRole = Qt.ItemDataRole.UserRole + 5
    ExeRole = Qt.ItemDataRole.UserRole + 6

    def __init__(self, parent=None):
        super().__init__(parent)
        self._processes = []
        self._pid_to_row = {}

    def rowCount(self, parent=QModelIndex()):
        return len(self._processes)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < len(self._processes)):
            return None
        
        proc = self._processes[index.row()]
        if role == self.PidRole: return proc.get("pid")
        if role == self.NameRole: return proc.get("name")
        if role == self.UserRole: return proc.get("user")
        if role == self.CpuRole: return proc.get("cpu")
        if role == self.MemoryRole: return proc.get("memory")
        if role == self.ExeRole: return proc.get("exe")
        return None

    def roleNames(self):
        return {
            self.PidRole: b"pid",
            self.NameRole: b"name",
            self.UserRole: b"user",
            self.CpuRole: b"cpu",
            self.MemoryRole: b"memory",
            self.ExeRole: b"exe"
        }

    def update_processes(self, new_procs):
        # We want to minimize resets to preserve scroll position.
        # This is a simplified but effective way: 
        # If the set of PIDs is drastically different or size changed, reset.
        # Otherwise, update existing rows.
        
        new_pids = [p['pid'] for p in new_procs]
        old_pids = [p['pid'] for p in self._processes]
        
        if len(new_procs) != len(self._processes) or set(new_pids) != set(old_pids):
            self.beginResetModel()
            self._processes = new_procs
            self._pid_to_row = {p['pid']: i for i, p in enumerate(new_procs)}
            self.endResetModel()
        else:
            # Update values for existing PIDs
            for i, p in enumerate(new_procs):
                old_p = self._processes[i]
                if old_p['cpu'] != p['cpu'] or old_p['memory'] != p['memory']:
                    self._processes[i] = p
                    idx = self.index(i, 0)
                    self.dataChanged.emit(idx, idx, [self.CpuRole, self.MemoryRole])

class StorageScannerWorker(QThread):
    result = pyqtSignal(dict) # Dict with sizes in bytes: 'apps', 'media', 'games', 'downloads', 'vms', 'trash_cache', 'other', 'total_used', 'total'

    def run(self):
        try:
            home = os.path.expanduser("~")
            
            # Simple recursive directory size calculator
            def get_dir_size(path):
                total = 0
                if os.path.exists(path):
                    for dirpath, _, filenames in os.walk(path):
                        for f in filenames:
                            fp = os.path.join(dirpath, f)
                            if not os.path.islink(fp):
                                try:
                                    total += os.path.getsize(fp)
                                except OSError:
                                    pass
                return total

            # 1. Apps (Approximation: /usr minus /usr/share/games, plus /var/lib/flatpak, plus pacman cache)
            # A faster way: pacman -Qiq | awk '/^Size/ {s+=$3} END {print s}' gives bytes but awk output is usually in bytes
            # For simplicity let's stick to Python scanning or a fast du.
            # actually pacman -Qi provides total size already but text parsing is needed. 
            # We will use `du -s` for a few key directories where most apps live.
            apps_size = 0
            for d in ['/usr/bin', '/usr/lib', '/opt', '/var/lib/flatpak']:
                apps_size += get_dir_size(d)

            # 2. Media
            media_size = 0
            for d in ['Videos', 'Pictures', 'Music']:
                media_size += get_dir_size(os.path.join(home, d))

            # 3. Games
            games_size = 0
            for d in ['Games', '.local/share/Steam', '.local/share/BeamNG']:
                path = os.path.join(home, d)
                if os.path.exists(path):
                    games_size += get_dir_size(path)

            # 4. Downloads
            downloads_size = get_dir_size(os.path.join(home, 'Downloads'))

            # 5. Virtual Machines
            vms_size = 0
            for d in ['.local/share/gnome-boxes', '.config/libvirt']:
                path = os.path.join(home, d)
                if os.path.exists(path):
                    vms_size += get_dir_size(path)
            if os.path.exists('/var/lib/libvirt'):
                vms_size += get_dir_size('/var/lib/libvirt')

            # 6. Cache & Trash
            trash_cache_size = get_dir_size(os.path.join(home, '.cache'))
            trash_cache_size += get_dir_size(os.path.join(home, '.local/share/Trash'))

            # 4. Total and Other
            usage = psutil.disk_usage('/')
            total_used = usage.used
            total = usage.total
            
            # other is simply what's left. Make sure it doesn't go below 0.
            other_size = max(0, total_used - (apps_size + media_size + games_size + downloads_size + vms_size + trash_cache_size))

            res = {
                'apps': apps_size,
                'media': media_size,
                'games': games_size,
                'downloads': downloads_size,
                'vms': vms_size,
                'trash_cache': trash_cache_size,
                'other': other_size,
                'total_used': total_used,
                'total': total
            }
            self.result.emit(res)
        except Exception:
            pass


class SystemHealth(QObject):
    # Signals
    ramUsageChanged = pyqtSignal()
    storageUsageChanged = pyqtSignal()
    cpuUsageChanged = pyqtSignal()
    swapUsageChanged = pyqtSignal()
    networkUsageChanged = pyqtSignal()
    applicationsChanged = pyqtSignal()
    cpuHistoryChanged = pyqtSignal()
    ramHistoryChanged = pyqtSignal()
    networkHistoryChanged = pyqtSignal()
    sortChanged = pyqtSignal()
    categorizedStorageChanged = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._ramUsage = 0.0
        self._ramTotalStr = ""
        self._storageUsage = 0.0
        self._storageTotalStr = ""
        self._cpuUsage = 0.0
        self._swapUsage = 0.0
        self._swapTotalStr = ""
        self._netDownload = 0.0
        self._netUpload = 0.0
        self._ipv4Address = self._get_ipv4()
        self._process_model = ProcessModel(self)
        self._searchQuery = ""
        
        self._sort_column = "cpu"
        self._sort_ascending = False

        self._appsSize = 0.0
        self._mediaSize = 0.0
        self._gamesSize = 0.0
        self._downloadsSize = 0.0
        self._vmsSize = 0.0
        self._trashCacheSize = 0.0
        self._otherSize = 0.0
        self._totalUsedSize = 0.0
        self._totalDiskSize = 1.0 # default to avoid divide by zero
        self._storage_worker = None

        self._cpu_history = deque(maxlen=60)
        self._ram_history = deque(maxlen=60)
        self._net_down_history = deque(maxlen=60)
        self._net_up_history = deque(maxlen=60)

        self._proc_cache = {}
        try:
            self._last_net_io = psutil.net_io_counters()
        except Exception:
            self._last_net_io = None

        # Separate timers per metric group to balance responsiveness vs cost
        self._fast_timer = QTimer(self)   # CPU + network: 1 s
        self._fast_timer.timeout.connect(self._update_fast_metrics)
        self._fast_timer.start(1000)

        self._medium_timer = QTimer(self)  # RAM / swap / storage: 3 s
        self._medium_timer.timeout.connect(self._update_medium_metrics)
        self._medium_timer.start(3000)

        self._app_timer = QTimer(self)    # Process list: 5 s
        self._app_timer.timeout.connect(self._update_applications)
        self._app_timer.start(5000)

        # Debounce timer for search query changes
        self._search_timer = QTimer(self)
        self._search_timer.setSingleShot(True)
        self._search_timer.setInterval(300)
        self._search_timer.timeout.connect(self._update_applications)

        self._storage_cat_timer = QTimer(self)
        self._storage_cat_timer.timeout.connect(self._fetch_storage_categories)
        self._storage_cat_timer.start(60000) # Every 60 seconds is enough for heavy storage scanning
        
        # Initial fetch
        self._update_fast_metrics()
        self._update_medium_metrics()
        self._update_applications()
        self._fetch_storage_categories()

    def _fetch_storage_categories(self):
        if self._storage_worker is None or not self._storage_worker.isRunning():
            self._storage_worker = StorageScannerWorker(parent=self)
            self._storage_worker.result.connect(self._on_storage_categories_fetched)
            self._storage_worker.start()

    def _on_storage_categories_fetched(self, data):
        self._appsSize = data.get('apps', 0)
        self._mediaSize = data.get('media', 0)
        self._gamesSize = data.get('games', 0)
        self._downloadsSize = data.get('downloads', 0)
        self._vmsSize = data.get('vms', 0)
        self._trashCacheSize = data.get('trash_cache', 0)
        self._otherSize = data.get('other', 0)
        self._totalUsedSize = data.get('total_used', 0)
        self._totalDiskSize = data.get('total', 1)
        self.categorizedStorageChanged.emit()

    def _get_ipv4(self):
        try:
            for interface, snics in psutil.net_if_addrs().items():
                if interface != 'lo':
                    for snic in snics:
                        if snic.family == socket.AF_INET:
                            return snic.address
        except Exception:
            pass
        return "Unknown"
        
    def _update_fast_metrics(self):
        self._update_cpu()
        self._update_network()

    def _update_medium_metrics(self):
        self._update_ram()
        self._update_storage()
        self._update_swap()

    def _update_ram(self):
        try:
            mem = psutil.virtual_memory()
            self._ramUsage = mem.percent / 100.0
            used_gb = mem.used / (1024**3)
            total_gb = mem.total / (1024**3)
            self._ramTotalStr = f"{used_gb:.1f}GiB / {total_gb:.1f}GiB"
            self._ram_history.append(self._ramUsage)
            self.ramUsageChanged.emit()
            self.ramHistoryChanged.emit()
        except Exception:
            pass

    def _update_storage(self):
        try:
            usage = psutil.disk_usage('/')
            self._storageUsage = usage.percent / 100.0
            used_gb = usage.used / (1024**3)
            total_gb = usage.total / (1024**3)
            self._storageTotalStr = f"{used_gb:.1f}GiB / {total_gb:.1f}GiB"
            self.storageUsageChanged.emit()
        except Exception:
            pass

    def _update_cpu(self):
        try:
            self._cpuUsage = psutil.cpu_percent(interval=None) / 100.0
            self._cpu_history.append(self._cpuUsage)
            self.cpuUsageChanged.emit()
            self.cpuHistoryChanged.emit()
        except Exception:
            pass

    def _update_swap(self):
        try:
            swap = psutil.swap_memory()
            self._swapUsage = swap.percent / 100.0
            used_gb = swap.used / (1024**3)
            total_gb = swap.total / (1024**3)
            self._swapTotalStr = f"{used_gb:.1f}GiB / {total_gb:.1f}GiB"
            self.swapUsageChanged.emit()
        except Exception:
            pass

    def _update_network(self):
        try:
            current_net_io = psutil.net_io_counters()
            if self._last_net_io:
                self._netDownload = (current_net_io.bytes_recv - self._last_net_io.bytes_recv) / 1.0
                self._netUpload = (current_net_io.bytes_sent - self._last_net_io.bytes_sent) / 1.0
            self._last_net_io = current_net_io
            self._net_down_history.append(self._netDownload)
            self._net_up_history.append(self._netUpload)
            self.networkUsageChanged.emit()
            self.networkHistoryChanged.emit()
        except Exception:
            pass

    def _update_applications(self):
        try:
            procs = []
            current_pids = set()
            search_lower = self._searchQuery.lower()
            
            for p in psutil.process_iter(['pid', 'name', 'memory_info', 'username', 'exe']):
                try:
                    pid = p.info['pid']
                    current_pids.add(pid)
                    if pid not in self._proc_cache:
                        self._proc_cache[pid] = p
                        p.cpu_percent()
                        cpu = 0.0
                    else:
                        cpu = self._proc_cache[pid].cpu_percent()
                    
                    name_str = p.info['name'] or "Unknown"
                    user_str = p.info['username'] or "Unknown"
                    
                    if search_lower and search_lower not in name_str.lower() and search_lower not in user_str.lower() and search_lower != str(pid):
                        continue
                        
                    mem_bytes = p.info['memory_info'].rss
                    procs.append({
                        "pid": pid,
                        "name": name_str,
                        "user": user_str,
                        "exe": p.info['exe'] or "",
                        "cpu_val": cpu,
                        "cpu": f"{cpu:.1f}%",
                        "mem_val": mem_bytes,
                        "memory": f"{mem_bytes / (1024*1024):.1f} MiB"
                    })
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess, KeyError):
                    pass
            
            dead_pids = set(self._proc_cache.keys()) - current_pids
            for pid in dead_pids:
                del self._proc_cache[pid]
                
            sort_key = {
                "cpu":    lambda x: x['cpu_val'],
                "memory": lambda x: x['mem_val'],
                "name":   lambda x: x['name'].lower(),
                "user":   lambda x: x['user'].lower(),
                "pid":    lambda x: x['pid'],
            }.get(self._sort_column, lambda x: x['cpu_val'])
            top_procs = sorted(procs, key=sort_key, reverse=not self._sort_ascending)[:50]
            
            formatted_procs = []
            for p in top_procs:
                formatted_procs.append({
                    "pid": p['pid'],
                    "name": p['name'],
                    "user": p['user'],
                    "exe": p['exe'],
                    "cpu": p['cpu'],
                    "memory": p['memory']
                })
            
            self._process_model.update_processes(formatted_procs)
        except Exception:
            pass

    @pyqtSlot(str)
    def toggleSort(self, column):
        if self._sort_column == column:
            self._sort_ascending = not self._sort_ascending
        else:
            self._sort_column = column
            self._sort_ascending = column in ("name", "user", "pid")
        self.sortChanged.emit()
        self._update_applications()

    @pyqtSlot(int)
    def kill_process(self, pid):
        try:
            p = psutil.Process(pid)
            p.terminate()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass

    @pyqtSlot(int)
    def open_file_location(self, pid):
        try:
            p = psutil.Process(pid)
            exe_path = p.exe()
            if exe_path:
                dir_path = os.path.dirname(exe_path)
                subprocess.Popen(['xdg-open', dir_path])
        except (psutil.NoSuchProcess, psutil.AccessDenied, OSError):
            pass

    @pyqtProperty(float, notify=ramUsageChanged)
    def ramUsage(self): return self._ramUsage
    @pyqtProperty(str, notify=ramUsageChanged)
    def ramTotalStr(self): return self._ramTotalStr
    @pyqtProperty(float, notify=storageUsageChanged)
    def storageUsage(self): return self._storageUsage
    @pyqtProperty(str, notify=storageUsageChanged)
    def storageTotalStr(self): return self._storageTotalStr

    @pyqtProperty(float, notify=categorizedStorageChanged)
    def appsSize(self): return self._appsSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def mediaSize(self): return self._mediaSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def gamesSize(self): return self._gamesSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def downloadsSize(self): return self._downloadsSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def vmsSize(self): return self._vmsSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def trashCacheSize(self): return self._trashCacheSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def otherSize(self): return self._otherSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def totalUsedSize(self): return self._totalUsedSize
    @pyqtProperty(float, notify=categorizedStorageChanged)
    def totalDiskSize(self): return self._totalDiskSize

    @pyqtProperty(float, notify=cpuUsageChanged)
    def cpuUsage(self): return self._cpuUsage
    @pyqtProperty(float, notify=swapUsageChanged)
    def swapUsage(self): return self._swapUsage
    @pyqtProperty(str, notify=swapUsageChanged)
    def swapTotalStr(self): return self._swapTotalStr
    
    @pyqtProperty(float, notify=networkUsageChanged)
    def netDownload(self): return self._netDownload
    @pyqtProperty(float, notify=networkUsageChanged)
    def netUpload(self): return self._netUpload
    @pyqtProperty(str, notify=networkUsageChanged)
    def ipv4Address(self): return self._ipv4Address

    @pyqtProperty(str, notify=sortChanged)
    def sortColumn(self): return self._sort_column

    @pyqtProperty(bool, notify=sortChanged)
    def sortAscending(self): return self._sort_ascending

    @pyqtProperty(list, notify=cpuHistoryChanged)
    def cpuHistory(self): return list(self._cpu_history)

    @pyqtProperty(list, notify=ramHistoryChanged)
    def ramHistory(self): return list(self._ram_history)

    @pyqtProperty(list, notify=networkHistoryChanged)
    def netDownHistory(self): return list(self._net_down_history)

    @pyqtProperty(list, notify=networkHistoryChanged)
    def netUpHistory(self): return list(self._net_up_history)

    @pyqtProperty(QObject, notify=applicationsChanged)
    def applications(self): return self._process_model

    @pyqtProperty(str, notify=applicationsChanged)
    def searchQuery(self): return self._searchQuery
    
    @searchQuery.setter
    def searchQuery(self, val):
        if self._searchQuery != val:
            self._searchQuery = val
            self._search_timer.start()

