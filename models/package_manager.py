import json
import os
import subprocess
from PyQt6.QtCore import (
    QAbstractListModel, QModelIndex, Qt, QObject, QThread, QTimer,
    pyqtSignal, pyqtSlot, pyqtProperty, QUrl
)
from PyQt6.QtNetwork import QNetworkAccessManager, QNetworkRequest

from utils.privileged_process import run_privileged
from utils.formatting import format_bytes


_STRIP_PREFIXES = (
    "python-", "python3-", "ruby-", "perl-", "nodejs-",
    "go-", "haskell-", "r-", "lua-",
)


def make_pretty_name(pkg_name: str) -> str:
    pretty = pkg_name

    is_lib32 = pretty.startswith("lib32-")
    if is_lib32:
        pretty = pretty[6:]

    for prefix in _STRIP_PREFIXES:
        if pretty.startswith(prefix):
            pretty = pretty[len(prefix):]
            break

    pretty = " ".join(word.capitalize() for word in pretty.split("-"))

    if is_lib32:
        pretty += " (32-bit)"

    return pretty


class PackageModel(QAbstractListModel):
    NameRole       = Qt.ItemDataRole.UserRole + 1
    FullNameRole   = Qt.ItemDataRole.UserRole + 2
    VersionRole    = Qt.ItemDataRole.UserRole + 3
    UpdateStatusRole = Qt.ItemDataRole.UserRole + 4
    GroupRole      = Qt.ItemDataRole.UserRole + 5
    RepoRole       = Qt.ItemDataRole.UserRole + 6
    IsFavoriteRole = Qt.ItemDataRole.UserRole + 7
    SizeRole       = Qt.ItemDataRole.UserRole + 8

    def __init__(self, parent=None):
        super().__init__(parent)
        self._data = []  # dict with keys: name, full_name, version, update_status, groups, repo, is_favorite, size

    def rowCount(self, parent=QModelIndex()):
        return len(self._data)

    def data(self, index, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid() or index.row() >= len(self._data):
            return None
        item = self._data[index.row()]
        if role == self.NameRole:
            return item["name"]
        if role == self.FullNameRole:
            return item["full_name"]
        if role == self.VersionRole:
            return item["version"]
        if role == self.UpdateStatusRole:
            return item["update_status"]
        if role == self.GroupRole:
            return item["groups"]
        if role == self.RepoRole:
            return item["repo"]
        if role == self.IsFavoriteRole:
            return item["is_favorite"]
        if role == self.SizeRole:
            return item.get("size", 0)
        return None

    def roleNames(self):
        return {
            self.NameRole:         b"name",
            self.FullNameRole:     b"fullName",
            self.VersionRole:      b"version",
            self.UpdateStatusRole: b"updateStatus",
            self.GroupRole:        b"group",
            self.RepoRole:         b"repo",
            self.IsFavoriteRole:   b"isFavorite",
            self.SizeRole:         b"size",
        }

    def update_packages(self, packages, show_pretty, updatable_set, favs_set, show_grouped):
        self.beginResetModel()
        self._data = []
        for p in packages:
            is_fav = p["name"] in favs_set
            is_updatable = p["name"] in updatable_set
            grp = p.get("groups", "")

            if show_grouped:
                if is_fav:
                    grp = "Favorites"
                elif is_updatable:
                    grp = "Updates Available"

            self._data.append({
                "name": make_pretty_name(p["name"]) if show_pretty else p["name"],
                "full_name": p.get("fullName", p["name"]),
                "version": p["version"],
                "update_status": "available" if p["name"] in updatable_set else "idle",
                "groups": grp,
                "repo": p.get("repo", "Unknown"),
                "is_favorite": is_fav,
                "size": p.get("size", 0),
            })
        self.endResetModel()


class PackageListWorker(QThread):
    result = pyqtSignal(list)

    def __init__(self, explicit_only, parent=None):
        super().__init__(parent)
        self.explicit_only = explicit_only

    def run(self):
        cmd = ["pacman", "-Qe"] if self.explicit_only else ["pacman", "-Q"]
        try:
            # Get installed packages
            proc = subprocess.run(cmd, capture_output=True, text=True)
            packages = []
            pkg_map = {}
            if proc.returncode == 0:
                for line in proc.stdout.splitlines():
                    parts = line.split()
                    if len(parts) >= 2:
                        pkg = {"name": parts[0], "version": parts[1], "groups": "None", "repo": "Unknown", "size": 0}
                        packages.append(pkg)
                        pkg_map[parts[0]] = pkg

            # Get groups mapping
            proc_g = subprocess.run(["pacman", "-Qg"], capture_output=True, text=True)
            if proc_g.returncode == 0:
                for line in proc_g.stdout.splitlines():
                    parts = line.split()
                    if len(parts) >= 2:
                        group_name = parts[0]
                        pkg_name = parts[1]
                        if pkg_name in pkg_map:
                            current = pkg_map[pkg_name]["groups"]
                            if current == "None":
                                pkg_map[pkg_name]["groups"] = group_name
                            else:
                                pkg_map[pkg_name]["groups"] += f", {group_name}"

            # Get Repo mapping
            try:
                proc_sl = subprocess.run(["pacman", "-S", "-l"], capture_output=True, text=True, timeout=2.0)
                if proc_sl.returncode == 0:
                    for line in proc_sl.stdout.splitlines():
                        parts = line.split()
                        if len(parts) >= 2 and parts[1] in pkg_map:
                            pkg_map[parts[1]]["repo"] = parts[0]
            except Exception:
                pass
            
            try:
                proc_qm = subprocess.run(["pacman", "-Qm"], capture_output=True, text=True, timeout=2.0)
                if proc_qm.returncode == 0:
                    for line in proc_qm.stdout.splitlines():
                        parts = line.split()
                        if len(parts) >= 1 and parts[0] in pkg_map:
                            pkg_map[parts[0]]["repo"] = "AUR"
            except Exception:
                pass

            # Get installed sizes via expac (bytes)
            try:
                proc_sz = subprocess.run(
                    ["expac", "%n %m", "-Q"],
                    capture_output=True, text=True, timeout=5.0
                )
                if proc_sz.returncode == 0:
                    for line in proc_sz.stdout.splitlines():
                        parts = line.split(maxsplit=1)
                        if len(parts) == 2 and parts[0] in pkg_map:
                            try:
                                pkg_map[parts[0]]["size"] = int(parts[1])
                            except ValueError:
                                pass
            except Exception:
                pass

            self.result.emit(packages)
        except Exception as e:
            print(f"[PackageManager] package list error: {e}")
            self.result.emit([])


class UpdateCheckWorker(QThread):
    result = pyqtSignal(list)

    def __init__(self, aur_helper="pacman", parent=None):
        super().__init__(parent)
        self.aur_helper = aur_helper

    def run(self):
        try:
            env = {**os.environ, "NO_COLOR": "1"}
            names = set()
            
            # 1. Check Official Repos using 'checkupdates' (safest non-root way)
            try:
                print("[UpdateCheck] Running checkupdates...")
                proc_sync = subprocess.run(["checkupdates"], capture_output=True, text=True, env=env)
                if proc_sync.returncode == 0 and proc_sync.stdout:
                    for line in proc_sync.stdout.splitlines():
                        parts = line.split()
                        if parts:
                            names.add(parts[0].strip().lower())
                elif proc_sync.returncode != 1: # 1 means no updates
                    print(f"[UpdateCheck] checkupdates failed with code {proc_sync.returncode}")
                    if proc_sync.stderr:
                        print(f"[UpdateCheck] checkupdates stderr: {proc_sync.stderr.strip()}")
            except Exception as e:
                print(f"[UpdateCheck] Error running checkupdates: {e}")

            # 2. Check AUR using 'paru -Qua' (AUR check only)
            if self.aur_helper == "paru":
                try:
                    print("[UpdateCheck] Running paru -Qua...")
                    proc_aur = subprocess.run(["paru", "-Qua"], capture_output=True, text=True, env=env)
                    if proc_aur.returncode == 0 and proc_aur.stdout:
                        for line in proc_aur.stdout.splitlines():
                            parts = line.split()
                            if parts:
                                name = parts[0].strip().lower()
                                if "/" in name:
                                    name = name.split("/")[-1]
                                names.add(name)
                    elif proc_aur.returncode != 1:
                        print(f"[UpdateCheck] paru -Qua failed with code {proc_aur.returncode}")
                except Exception as e:
                    print(f"[UpdateCheck] Error running paru -Qua: {e}")

            final_list = list(names)
            print(f"[UpdateCheck] Total updates found: {len(final_list)}")
            if final_list:
                print(f"[UpdateCheck] Sample updates: {', '.join(final_list[:5])}")
                
            self.result.emit(final_list)
        except Exception as e:
            print(f"[PackageManager] update check error: {e}")
            self.result.emit([])


class SearchBrowseWorker(QThread):
    result = pyqtSignal(list)

    def __init__(self, query: str, aur_helper: str, parent=None):
        super().__init__(parent)
        self.query = query
        self.aur_helper = aur_helper

    def run(self):
        if not self.query.strip():
            self.result.emit([])
            return
            
        is_paru = self.aur_helper == "paru"
        
        args = [self.aur_helper, "-Ss", self.query]
        # paru -Ss returns format: "repo/name version [installed] \n description"
        # pacman returns similar.
        try:
            proc = subprocess.run(args, capture_output=True, text=True)
            packages = []
            if proc.returncode == 0:
                lines = proc.stdout.splitlines()
                for i in range(0, len(lines), 2):
                    if i + 1 >= len(lines): break
                    
                    header = lines[i].strip()
                    desc = lines[i+1].strip()
                    parts = header.split()
                    
                    if len(parts) >= 2:
                        repo_and_name = parts[0]
                        version = parts[1]
                        
                        # Strip color codes simply for the name just in case (though paru --color never should avoid this)
                        import re
                        repo_and_name = re.sub(r'\x1b\[[0-9;]*m', '', repo_and_name)
                        
                        repo, _, name = repo_and_name.partition("/")
                        if not name:
                            name = repo_and_name
                            repo = "Unknown"
                            
                        # Keep full repo/name for AUR/browse commands to be distinct
                        full_name = repo + "/" + name if repo != "Unknown" else name
                            
                        pkg = {
                            "name": name,
                            "fullName": full_name,
                            "version": version, 
                            "groups": repo,
                            "repo": repo if repo != "Unknown" else "AUR",
                            "desc": desc
                        }
                        packages.append(pkg)
                        
                        # Limit to 50 results to prevent massive unreadable lists and lag
                        if len(packages) >= 50:
                            break
                            
            self.result.emit(packages)
        except Exception as e:
            print(f"[PackageManager] search browse error: {e}")
            self.result.emit([])


class UpgradeWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def __init__(self, aur_helper="pacman", parent=None):
        super().__init__(parent)
        self.aur_helper = aur_helper
        self._proc = None
        self._is_aborted = False

    def abort(self):
        self._is_aborted = True
        if self._proc:
            try:
                self._proc.terminate()
            except:
                pass

    def run(self):
        try:
            if self.aur_helper == "pacman":
                self.progress.emit("Running pacman -Syu --noconfirm (requires privilege)...")
                self._proc = run_privileged(["sh", "-c", "pacman -Syu --noconfirm 2>&1"])
            else:
                self.progress.emit(f"Running {self.aur_helper} -Syu --noconfirm...")
                self._proc = subprocess.Popen(
                    [self.aur_helper, "-Syu", "--noconfirm", "--sudo", "pkexec", "--color", "never"],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
                )
            if self._proc:
                for line in iter(self._proc.stdout.readline, ""):
                    if self._is_aborted:
                        break
                    stripped = line.rstrip()
                    if stripped:
                        self.progress.emit(stripped)
                if not self._is_aborted:
                    self._proc.wait()
                    if self._proc.returncode == 0:
                        self.progress.emit("Upgrade complete.")
                        self.finished.emit(True)
                    else:
                        self.progress.emit(f"Upgrade failed (exit code {self._proc.returncode}).")
                        self.finished.emit(False)
                else:
                    self.progress.emit("Upgrade aborted by user.")
                    self.finished.emit(False)
            else:
                self.progress.emit("Upgrade cancelled or failed to start.")
                self.finished.emit(False)
        except Exception as e:
            self.progress.emit(f"Exception: {str(e)}")
            self.finished.emit(False)


class GetDepsWorker(QThread):
    result = pyqtSignal(list, str)  # list of names, total size string

    def __init__(self, names, parent=None):
        super().__init__(parent)
        self.names = names

    @staticmethod
    def _parse_qi(output: str) -> list[dict]:
        """Parse `pacman -Qi [pkgs]` output into a list of field dicts."""
        pkgs = []
        for section in output.split("\n\n"):
            info = {}
            for line in section.splitlines():
                if ":" in line:
                    key, _, val = line.partition(":")
                    info[key.strip()] = val.strip()
            if "Name" in info:
                pkgs.append(info)
        return pkgs

    @staticmethod
    def _strip_ver(dep: str) -> str:
        """'gtk3>=3.24' → 'gtk3'"""
        for op in (">=", "<=", "!=", ">", "<", "="):
            if op in dep:
                return dep.split(op)[0]
        return dep

    @staticmethod
    def _sum_bytes(pkgs: list[dict]) -> int:
        multipliers = {"b": 1, "kib": 1024, "mib": 1024**2, "gib": 1024**3,
                       "kb": 1000, "mb": 1000**2, "gb": 1000**3}
        total = 0
        for pkg in pkgs:
            parts = pkg.get("Installed Size", "").split()
            if len(parts) >= 2:
                try:
                    total += int(float(parts[0]) * multipliers.get(parts[1].lower(), 1))
                except (ValueError, KeyError):
                    pass
        return total

    def run(self):
        if not self.names:
            self.result.emit([], "0 B")
            return

        names_set = set(self.names)

        # ── Step 1: collect direct deps of the packages being removed ─────────
        # `pacman -Qi` requires no root — safe to call freely.
        candidate_deps: set[str] = set()
        try:
            proc = subprocess.run(["pacman", "-Qi"] + list(self.names),
                                  capture_output=True, text=True)
            for pkg in self._parse_qi(proc.stdout):
                deps_str = pkg.get("Depends On", "None")
                if deps_str and deps_str != "None":
                    for raw in deps_str.split():
                        dep = self._strip_ver(raw)
                        if dep and dep not in names_set:
                            candidate_deps.add(dep)
        except Exception:
            pass

        # ── Step 2: which candidates would be orphaned? ────────────────────────
        # A dep is orphaned if every package in its "Required By" list is also
        # being removed (i.e. nothing outside the removal set still needs it).
        orphaned: list[str] = []
        if candidate_deps:
            try:
                proc2 = subprocess.run(["pacman", "-Qi"] + sorted(candidate_deps),
                                       capture_output=True, text=True)
                for pkg in self._parse_qi(proc2.stdout):
                    name = pkg.get("Name", "")
                    if not name or name in names_set:
                        continue
                    req_str = pkg.get("Required By", "None")
                    required_by = set() if req_str == "None" else set(req_str.split())
                    if not required_by or required_by <= names_set:
                        orphaned.append(name)
            except Exception:
                pass

        packages_to_remove = list(self.names) + orphaned

        # ── Step 3: sum installed sizes ────────────────────────────────────────
        total_bytes = 0
        try:
            proc3 = subprocess.run(["pacman", "-Qi"] + packages_to_remove,
                                   capture_output=True, text=True)
            total_bytes = self._sum_bytes(self._parse_qi(proc3.stdout))
        except Exception:
            pass

        total_size = format_bytes(total_bytes) if total_bytes > 0 else "Unknown"
        self.result.emit(packages_to_remove, total_size)

class RemovePackageWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def __init__(self, names, parent=None):
        super().__init__(parent)
        self.names = names

    def run(self):
        try:
            names_str = " ".join(self.names)
            self.progress.emit(f"Requesting privileges to remove {len(self.names)} package(s)…")
            # Merge stderr into stdout so all pacman output appears in the terminal pane
            proc = run_privileged(["sh", "-c", f"pacman -Rns --noconfirm {names_str} 2>&1"])
            if proc:
                # Stream output line by line as pacman works
                for line in iter(proc.stdout.readline, ""):
                    stripped = line.rstrip()
                    if stripped:
                        self.progress.emit(stripped)
                proc.wait()
                if proc.returncode == 0:
                    self.progress.emit("Removal complete.")
                    self.finished.emit(True)
                else:
                    self.progress.emit(f"Removal failed (exit code {proc.returncode}).")
                    self.finished.emit(False)
            else:
                self.progress.emit("Cancelled or failed to obtain privileges.")
                self.finished.emit(False)
        except Exception as e:
            self.progress.emit(f"Exception: {e}")
            self.finished.emit(False)


class GetInstallDepsWorker(QThread):
    result = pyqtSignal(list, str)

    def __init__(self, names, aur_helper, parent=None):
        super().__init__(parent)
        self.names = names
        self.aur_helper = aur_helper

    def run(self):
        if not self.names:
            self.result.emit([], "0 B")
            return

        # pacman/paru -S --print-format "%n %s" <packages>
        # gives us the packages and their download sizes, but we want installed sizes ideally. 
        # Actually -Si gives detailed info.
        # Even simpler: pacman -S --print-format "%n" gets the list of packages to install.
        try:
            # We use pacman for dependency resolution to be fast and safe, but AUR helpers extend this.
            # Usually paru -S --print-format "%n" won't install AUR packages without prompting, 
            # so we might have to just do a basic `pacman` check first, or just bypass deps sizing for AUR
            # To be safe, we'll try to get it from paru -Sp --print-format "%n"
            args = [self.aur_helper, "-Sp", "--print-format", "%n"] + list(self.names)
            proc = subprocess.run(args, capture_output=True, text=True)
            
            to_install = []
            if proc.returncode == 0:
                for line in proc.stdout.splitlines():
                    # filter out urls if they appear (yay sometimes prints urls with -Sp)
                    line = line.strip()
                    if line and not line.startswith("http") and not line.startswith("file://") and line.find("/") == -1:
                        # might just be a name
                        to_install.append(line)
                        
            # If the helper doesn't support print format nicely, fallback to just names
            if not to_install:
                to_install = list(self.names)
                
            # We don't have a perfect way to size AUR package installed sizes before building, 
            # so we leave size as "Unknown" for browse mode
            self.result.emit(to_install, "Unknown")
        except Exception:
            self.result.emit(list(self.names), "Unknown")


class InstallPackageWorker(QThread):
    progress = pyqtSignal(str)
    finished = pyqtSignal(bool)

    def __init__(self, names, aur_helper, parent=None):
        super().__init__(parent)
        self.names = names
        self.aur_helper = aur_helper
        self._proc = None
        self._is_aborted = False

    def abort(self):
        self._is_aborted = True
        if self._proc:
            try:
                self._proc.terminate()
            except:
                pass

    def run(self):
        try:
            names_str = " ".join(self.names)
            self.progress.emit(f"Requesting privileges to install {len(self.names)} package(s) using {self.aur_helper}…")
            # If the aur_helper is paru, running as root with pkexec is actually FORBIDDEN by makepkg.
            # So we must NOT use run_privileged directly unless it's pacman.
            # Actually paru elevates itself when needed. Let's just run it directly!
            
            if self.aur_helper == "pacman":
                cmd = ["sh", "-c", f"pacman -S --noconfirm {names_str} 2>&1"]
                self._proc = run_privileged(cmd)
            else:
                cmd = [self.aur_helper, "-S", "--noconfirm", "--sudo", "pkexec"] + self.names
                self._proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                
            if self._proc:
                for line in iter(self._proc.stdout.readline, ""):
                    if self._is_aborted:
                        break
                    stripped = line.rstrip()
                    if stripped:
                        self.progress.emit(stripped)
                if not self._is_aborted:
                    self._proc.wait()
                    if self._proc.returncode == 0:
                        self.progress.emit("Installation complete.")
                        self.finished.emit(True)
                    else:
                        self.progress.emit(f"Installation failed (exit code {self._proc.returncode}).")
                        self.finished.emit(False)
                else:
                    self.progress.emit("Installation aborted by user.")
                    self.finished.emit(False)
            else:
                self.progress.emit("Cancelled or failed to start.")
                self.finished.emit(False)
        except Exception as e:
            self.progress.emit(f"Exception: {e}")
            self.finished.emit(False)


class PackageManager(QObject):
    packagesChanged          = pyqtSignal()
    isLoadingChanged         = pyqtSignal()
    showExplicitOnlyChanged  = pyqtSignal()
    showPrettyNamesChanged   = pyqtSignal()
    isCheckingUpdatesChanged = pyqtSignal()
    isUpgradingChanged       = pyqtSignal()
    isRemovingChanged        = pyqtSignal()
    isDryRunningChanged      = pyqtSignal()
    updateCountChanged       = pyqtSignal()
    progressTextChanged      = pyqtSignal()
    removalOutputChanged     = pyqtSignal()
    searchQueryChanged       = pyqtSignal()
    showGroupedChanged       = pyqtSignal()
    modeChanged              = pyqtSignal()
    selectedPackagesChanged  = pyqtSignal()
    depsReady                = pyqtSignal(list, str)
    removalDone              = pyqtSignal(bool)
    pkgbuildContentChanged   = pyqtSignal()
    upgradeActionTriggered   = pyqtSignal(str)
    sortOrderChanged         = pyqtSignal()

    def __init__(self, settings_manager=None, parent=None):
        super().__init__(parent)
        self._settings_manager = settings_manager
        self._nam = QNetworkAccessManager(self)
        self._model = PackageModel(self)
        self._packages = []
        self._browse_packages = []
        self._updatable = set()
        self._is_loading = False
        self._is_checking_updates = False
        self._is_upgrading = False
        self._is_removing = False
        self._is_dry_running = False
        self._update_count = 0
        self._progress_text = ""
        self._removal_output = ""
        self._search_query = ""
        self._show_explicit_only = True # Defaults
        self._show_pretty_names = True  # Defaults
        self._show_grouped = False
        self._mode = "installed" # "installed" or "browse"
        self._selected_packages = {}
        self._pkgbuild_content = ""
        self._sort_order = "name_asc"  # name_asc | name_desc | size_asc | size_desc

        # Favorites: load once, cache in memory
        self._favs_file = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "package_favorites.json"
        )
        self._favs_set = set()
        self._reload_favs()

        # Search debounce: avoids spawning a subprocess on every keystroke
        self._search_timer = QTimer(self)
        self._search_timer.setSingleShot(True)
        self._search_timer.setInterval(300)
        self._search_timer.timeout.connect(self._execute_search)

        self.worker = None
        self.update_worker = None
        self.upgrade_worker = None
        self.remove_worker = None
        self.deps_worker = None
        self.search_browse_worker = None

    # ── Properties ────────────────────────────────────────────────────────────

    @pyqtProperty(QObject, notify=packagesChanged)
    def model(self):
        return self._model

    @pyqtProperty(int, notify=packagesChanged)
    def packageCount(self):
        return len(self._packages) if self._mode == "installed" else len(self._browse_packages)

    @pyqtProperty(bool, notify=showExplicitOnlyChanged)
    def showExplicitOnly(self):
        return self._show_explicit_only

    @pyqtProperty(bool, notify=showPrettyNamesChanged)
    def showPrettyNames(self):
        return self._show_pretty_names

    @pyqtProperty(str, notify=modeChanged)
    def mode(self):
        return self._mode

    @mode.setter
    def mode(self, val):
        if self._mode != val:
            self._mode = val
            self.modeChanged.emit()
            self._search_timer.stop()
            if self._mode == "browse":
                self._browse_packages = []
                self._search_query = ""
                self.searchQueryChanged.emit()
            self._rebuild_model()

    @pyqtProperty(list, notify=selectedPackagesChanged)
    def selectedPackages(self):
        return list(self._selected_packages.keys())

    @selectedPackages.setter
    def selectedPackages(self, val):
        # We store the selected packages so we can pin them to the top during searches
        self._selected_packages = {k: True for k in val}
        self.selectedPackagesChanged.emit()

    @pyqtProperty(bool, notify=isLoadingChanged)
    def isLoading(self):
        return self._is_loading

    @pyqtProperty(bool, notify=isCheckingUpdatesChanged)
    def isCheckingUpdates(self):
        return self._is_checking_updates

    @pyqtProperty(bool, notify=isUpgradingChanged)
    def isUpgrading(self):
        return self._is_upgrading

    @pyqtProperty(bool, notify=isRemovingChanged)
    def isRemoving(self):
        return self._is_removing

    @pyqtProperty(bool, notify=isDryRunningChanged)
    def isDryRunning(self):
        return self._is_dry_running

    @pyqtProperty(int, notify=updateCountChanged)
    def updateCount(self):
        return self._update_count

    @pyqtProperty(str, notify=progressTextChanged)
    def progressText(self):
        return self._progress_text

    @pyqtProperty(str, notify=removalOutputChanged)
    def removalOutput(self):
        return self._removal_output

    @pyqtProperty(str, notify=pkgbuildContentChanged)
    def pkgbuildContent(self):
        return self._pkgbuild_content

    def _append_removal_output(self, line):
        self._removal_output = (self._removal_output + "\n" + line) if self._removal_output else line
        self.removalOutputChanged.emit()

    def _clear_removal_output(self):
        if self._removal_output:
            self._removal_output = ""
            self.removalOutputChanged.emit()

    @pyqtProperty(bool, notify=showGroupedChanged)
    def showGrouped(self):
        return self._show_grouped

    @pyqtProperty(str, notify=searchQueryChanged) 
    def searchQuery(self):
        return self._search_query

    @searchQuery.setter
    def searchQuery(self, val):
        if self._search_query != val:
            self._search_query = val
            self.searchQueryChanged.emit()
            self._search_timer.start()

    @pyqtProperty(str, notify=sortOrderChanged)
    def sortOrder(self):
        return self._sort_order

    @pyqtSlot(str)
    def set_sort_order(self, order: str):
        if self._sort_order != order:
            self._sort_order = order
            self.sortOrderChanged.emit()
            self._rebuild_model()

    def _execute_search(self):
        if self._mode == "browse":
            self._run_browse_search()
        else:
            self._rebuild_model()

    def _run_browse_search(self):
        self._set_loading(True)
        aur_helper = self._settings_manager.aurHelper if self._settings_manager else "pacman"
        self.search_browse_worker = SearchBrowseWorker(self._search_query, aur_helper, parent=self)
        self.search_browse_worker.result.connect(self._on_browse_search_finished)
        self.search_browse_worker.start()

    def _on_browse_search_finished(self, results):
        self._browse_packages = results
        self._set_loading(False)
        self._rebuild_model()

    # ── Internal helpers ──────────────────────────────────────────────────────

    def _set_loading(self, val):
        if self._is_loading != val:
            self._is_loading = val
            self.isLoadingChanged.emit()

    def _set_checking(self, val):
        if self._is_checking_updates != val:
            self._is_checking_updates = val
            self.isCheckingUpdatesChanged.emit()

    def _set_upgrading(self, val):
        if self._is_upgrading != val:
            self._is_upgrading = val
            self.isUpgradingChanged.emit()

    def _set_removing(self, val):
        if self._is_removing != val:
            self._is_removing = val
            self.isRemovingChanged.emit()

    def _set_dry_running(self, val):
        if self._is_dry_running != val:
            self._is_dry_running = val
            self.isDryRunningChanged.emit()

    def _set_progress(self, text):
        if self._progress_text != text:
            self._progress_text = text
            self.progressTextChanged.emit()

    def _reload_favs(self):
        try:
            with open(self._favs_file, "r") as f:
                data = json.load(f)
                self._favs_set = set(data.get("favorites", []))
        except Exception:
            self._favs_set = set()

    def _rebuild_model(self):
        favs = self._favs_set

        if self._mode == "installed":
            filtered_packages = self._packages
            if self._search_query:
                q = self._search_query.lower()
                filtered_packages = [p for p in self._packages if q in p["name"].lower()]

            # Build a sort key function based on _sort_order
            if self._sort_order == "name_desc":
                def _secondary_key(x):
                    return (-ord(x["name"][0].lower()) if x["name"] else 0, x["name"])
            elif self._sort_order == "size_asc":
                def _secondary_key(x):
                    return x.get("size", 0)
            elif self._sort_order == "size_desc":
                def _secondary_key(x):
                    return -x.get("size", 0)
            else:  # name_asc (default)
                def _secondary_key(x):
                    return x["name"]

            if self._show_grouped:
                filtered_packages = sorted(filtered_packages, key=lambda x: (
                    not (x["name"] in favs),
                    not (x["name"] in self._updatable),
                    x.get("groups", ""),
                    _secondary_key(x),
                ))
            else:
                filtered_packages = sorted(filtered_packages, key=_secondary_key)
        else:
            # Browse mode: already filtered remotely, just merge selected items to the top
            filtered_packages = list(self._browse_packages)
            
            # Put selected items at the top even if they don't match the current query
            selected_names_set = set(self._selected_packages.keys())
            
            # Find which selected packages are ALREADY in the fetched browse list
            in_results = {p.get("fullName", p["name"]) for p in filtered_packages}
            
            missing_selected_names = selected_names_set - in_results
            
            if missing_selected_names:
                for m_name in missing_selected_names:
                    # We create dummy entries for selected packages that got filtered out of view
                    # So the user can still un-select them
                    
                    # Try to separate repo/name if it's stored in full_name format
                    m_repo = "AUR"
                    m_short_name = m_name
                    if "/" in m_name:
                        m_repo, m_short_name = m_name.split("/", 1)
                        
                    filtered_packages.append({
                        "name": m_short_name,
                        "fullName": m_name,
                        "version": "Selected",
                        "groups": m_repo,
                        "repo": m_repo,
                        "desc": "Package selected. Change query to find it."
                    })
                    
            # If "Group by Group" is active, we also want to show ALL favorites, even if not searched/installed
            if self._show_grouped:
                # Find which favorites are missing from current view
                missing_favs = favs - {p["name"] for p in filtered_packages}
                
                # Further filter to ONLY include favorites that are NOT installed
                installed_names = {p["name"] for p in self._packages}
                uninstalled_favs = missing_favs - installed_names
                
                # We don't query pacman here to keep UI fast; just create placeholders 
                # that can be selected/installed exactly like browse results
                for f_name in uninstalled_favs:
                    filtered_packages.append({
                        "name": f_name,
                        "fullName": f_name,
                        "version": "Unknown",
                        "groups": "Favorites",
                        "repo": "AUR/Repo",
                        "desc": "Favorite package available for installation."
                    })
                    
            # Sort: first selected items, then favorites (only if grouped), then alphabetical
            if self._show_grouped:
                filtered_packages = sorted(filtered_packages, key=lambda x: (
                    not (x.get("fullName", x["name"]) in selected_names_set),
                    not (x["name"] in favs),
                    x.get("groups", ""),
                    x["name"]
                ))
            else:
                filtered_packages = sorted(filtered_packages, key=lambda x: (
                    not (x.get("fullName", x["name"]) in selected_names_set),
                    x["name"]
                ))

        self._model.update_packages(filtered_packages, self._show_pretty_names, self._updatable, favs, self._show_grouped)
        self.packagesChanged.emit()

    def _update_update_count(self):
        count = len(self._updatable)
        if self._update_count != count:
            self._update_count = count
            self.updateCountChanged.emit()

    # ── Slots ─────────────────────────────────────────────────────────────────

    @pyqtSlot()
    def refresh(self):
        self._set_loading(True)
        self.worker = PackageListWorker(self._show_explicit_only, parent=self)
        self.worker.result.connect(self._on_packages_loaded)
        self.worker.start()

    def _on_packages_loaded(self, packages):
        self._packages = packages
        self._rebuild_model()
        self._set_loading(False)

    @pyqtSlot()
    def check_updates(self):
        self._set_checking(True)
        aur_helper = self._settings_manager.aurHelper if self._settings_manager else "pacman"
        print(f"[PackageManager] Checking for updates using helper: {aur_helper}")
        self.update_worker = UpdateCheckWorker(aur_helper=aur_helper, parent=self)
        self.update_worker.result.connect(self._on_updates_checked)
        self.update_worker.start()

    def _on_updates_checked(self, names):
        print(f"[PackageManager] Updates checked: {len(names)} packages found.")
        self._updatable = set(names)
        self._update_update_count()
        self._rebuild_model()
        self._set_checking(False)

    @pyqtSlot(str)
    def fetch_pkgbuild(self, pkg_name: str):
        self._pkgbuild_content = f"Fetching PKGBUILD for {pkg_name}..."
        self.pkgbuildContentChanged.emit()

        url_str = f"https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h={pkg_name}"
        req = QNetworkRequest(QUrl(url_str))
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "MaintainerApp/1.0")
        
        reply = self._nam.get(req)
        reply.finished.connect(lambda: self._on_pkgbuild_fetched(reply))

    def _on_pkgbuild_fetched(self, reply):
        try:
            if reply.error() != reply.NetworkError.NoError:
                self._pkgbuild_content = f"Failed to fetch PKGBUILD:\n{reply.errorString()}"
            else:
                content = bytes(reply.readAll()).decode("utf-8")
                self._pkgbuild_content = content
        except Exception as e:
            self._pkgbuild_content = f"Exception reading PKGBUILD:\n{e}"
        finally:
            self.pkgbuildContentChanged.emit()
            reply.deleteLater()

    @pyqtSlot()
    def upgrade(self):
        self._set_upgrading(True)
        # We always use -Syu for the actual upgrade to ensure full system sync and safety.
        cmd = "paru -Syu"
        if self._settings_manager and self._settings_manager.aurHelper == "pacman":
            cmd = "sudo pacman -Syu"
        
        # This emit triggers the terminal popup via main.py or similar
        self.upgradeActionTriggered.emit(cmd)
        # We don't set upgrading to false here, we wait for the user to potentially refresh 
        # or the app to detect success. For now, we'll reset it after a delay or just let it be.
        # Actually, the user usually closes the terminal, we don't have a reliable callback.
        # So we'll reset it so they can click again if needed.
        self._set_upgrading(False)

    def _on_upgrade_finished(self, success):
        self._set_upgrading(False)
        if success:
            # Refresh list and clear update indicators
            self._updatable = set()
            self._update_update_count()
            self.refresh()
            self.check_updates()

    @pyqtSlot(bool)
    def set_show_explicit_only(self, val):
        if self._show_explicit_only != val:
            self._show_explicit_only = val
            self.showExplicitOnlyChanged.emit()
            self.refresh()

    @pyqtSlot(bool)
    def set_show_pretty_names(self, val):
        if self._show_pretty_names != val:
            self._show_pretty_names = val
            self.showPrettyNamesChanged.emit()
            self._rebuild_model()

    @pyqtSlot(bool)
    def set_show_grouped(self, val):
        if self._show_grouped != val:
            self._show_grouped = val
            self.showGroupedChanged.emit()
            self._rebuild_model()

    @pyqtSlot(list)
    def remove_packages(self, names):
        # We rename this internally to denote action
        if not names: return
        self._set_removing(True)
        self._clear_removal_output()
        if self._mode == "installed":
            self.remove_worker = RemovePackageWorker(names, parent=self)
        else:
            aur_helper = self._settings_manager.aurHelper if self._settings_manager else "pacman"
            self.remove_worker = InstallPackageWorker(names, aur_helper, parent=self)
            
        self.remove_worker.progress.connect(self._append_removal_output)
        self.remove_worker.finished.connect(self._on_remove_finished)
        self.remove_worker.start()

    def _on_remove_finished(self, success):
        self._set_removing(False)
        self.removalDone.emit(success)
        if success:
            if self._mode == "installed":
                self.refresh() # Will reload installed packages
            else:
                self.selectedPackages = [] # Clear selection
                self._rebuild_model()
                self.refresh() # Good idea to update installed status though browse won't immediately reflect it unless we add an 'installed' tag, which `pacman -Q` has

    @pyqtSlot(list)
    def get_remove_deps(self, names):
        if not names: return
        self._set_dry_running(True)
        if self._mode == "installed":
            self.deps_worker = GetDepsWorker(names, parent=self)
        else:
            aur_helper = self._settings_manager.aurHelper if self._settings_manager else "pacman"
            self.deps_worker = GetInstallDepsWorker(names, aur_helper, parent=self)
            
        self.deps_worker.result.connect(self._on_deps_ready)
        self.deps_worker.start()

    def _on_deps_ready(self, deps, size):
        self._set_dry_running(False)
        self.depsReady.emit(deps, size)

    @pyqtSlot()
    def cancel_action(self):
        """Allows cancelling active upgrades or installations."""
        if self._is_upgrading and self.upgrade_worker:
            self.upgrade_worker.abort()
            self._set_upgrading(False)
            self._append_removal_output("\n[Action ABORTED by user]")
        elif self._is_removing and self.remove_worker:
            if hasattr(self.remove_worker, 'abort'):
                self.remove_worker.abort()
            self._set_removing(False)
            self._append_removal_output("\n[Action ABORTED by user]")
