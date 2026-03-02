import os
import re
import json
import shutil
import tempfile

from PyQt6.QtCore import (
    QObject, QUrl, pyqtProperty, pyqtSignal, pyqtSlot,
    QAbstractListModel, Qt, QModelIndex, QTimer
)
from PyQt6.QtNetwork import QNetworkAccessManager, QNetworkRequest, QNetworkReply


def split_appimage_filename(filename: str):
    """
    Intelligently split an AppImage filename into a clean name and version details.
    Example: 'LM-Studio-0.4.1-1-x64_96...AppImage' -> ('LM Studio', '0.4.1-1-x64_96...')
    """
    base = filename
    if base.lower().endswith(".appimage"):
        base = base[:-9]

    pattern = r"[-_](\d|v\d|x86|amd64|arm64|i386|linux|x64)"
    match = re.search(pattern, base, flags=re.IGNORECASE)

    if match:
        split_idx = match.start()
        name_part = base[:split_idx]
        version_part = filename[split_idx+1:]
    else:
        name_part = base
        version_part = "Unknown"

    display_name = " ".join(name_part.replace("-", " ").replace("_", " ").split()).strip()
    return display_name, version_part


class AppImageModel(QAbstractListModel):
    NameRole = Qt.ItemDataRole.UserRole + 1
    PathRole = Qt.ItemDataRole.UserRole + 2
    UpdateUrlRole = Qt.ItemDataRole.UserRole + 3
    VersionRole = Qt.ItemDataRole.UserRole + 4
    LatestVersionRole = Qt.ItemDataRole.UserRole + 5
    UpdateStatusRole = Qt.ItemDataRole.UserRole + 6   # idle / checking / available / up-to-date / error
    CheckedRole = Qt.ItemDataRole.UserRole + 7
    DirectoryPathRole = Qt.ItemDataRole.UserRole + 8
    ReleaseNotesRole = Qt.ItemDataRole.UserRole + 9
    SizeRole = Qt.ItemDataRole.UserRole + 10
    IconPathRole = Qt.ItemDataRole.UserRole + 11

    def __init__(self, parent=None):
        super().__init__(parent)
        self._appimages = []
        self._path_to_row = {}   # O(1) path → row index

    def rowCount(self, parent=QModelIndex()):
        return len(self._appimages)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < len(self._appimages)):
            return None
        item = self._appimages[index.row()]
        if role == self.NameRole:            return item.get("name")
        if role == self.PathRole:            return item.get("path")
        if role == self.UpdateUrlRole:       return item.get("update_url", "")
        if role == self.VersionRole:         return item.get("version", "Unknown")
        if role == self.LatestVersionRole:   return item.get("latest_version", "")
        if role == self.UpdateStatusRole:    return item.get("update_status", "idle")
        if role == self.CheckedRole:         return item.get("is_checked", False)
        if role == self.ReleaseNotesRole:    return item.get("release_notes", "")
        if role == self.SizeRole:            return item.get("size", 0)
        if role == self.DirectoryPathRole:
            path = item.get("path", "")
            if path:
                d = os.path.dirname(path)
                return d + os.sep if d else ""
            return ""
        if role == self.IconPathRole:        return item.get("icon_path", "")
        return None

    def roleNames(self):
        return {
            self.NameRole:          b"name",
            self.PathRole:          b"path",
            self.UpdateUrlRole:     b"updateUrl",
            self.VersionRole:       b"version",
            self.LatestVersionRole: b"latestVersion",
            self.UpdateStatusRole:  b"updateStatus",
            self.CheckedRole:       b"isChecked",
            self.DirectoryPathRole: b"directoryPath",
            self.ReleaseNotesRole:  b"releaseNotes",
            self.SizeRole:          b"size",
            self.IconPathRole:      b"iconPath",
        }

    def setData(self, index, value, role):
        if not index.isValid() or not (0 <= index.row() < len(self._appimages)):
            return False
        if role == self.CheckedRole:
            self._appimages[index.row()]["is_checked"] = value
            self.dataChanged.emit(index, index, [self.CheckedRole])
            if self.parent():
                self.parent().checkedCountChanged.emit()
                self.parent().checkedUpdateCountChanged.emit()
            return True
        return False

    def update_data(self, new_data):
        self.beginResetModel()
        self._appimages = new_data
        self._path_to_row = {item["path"]: i for i, item in enumerate(new_data)}
        self.endResetModel()

    def _set_field(self, row, **kwargs):
        if not (0 <= row < len(self._appimages)):
            return
        role_map = {
            "name":           self.NameRole,
            "version":        self.VersionRole,
            "update_url":     self.UpdateUrlRole,
            "update_status":  self.UpdateStatusRole,
            "latest_version": self.LatestVersionRole,
            "release_notes":  self.ReleaseNotesRole,
        }
        changed_roles = []
        for key, value in kwargs.items():
            self._appimages[row][key] = value
            if key in role_map:
                changed_roles.append(role_map[key])
        if changed_roles:
            idx = self.index(row, 0)
            self.dataChanged.emit(idx, idx, changed_roles)

    def _remove_items(self, paths):
        """Remove a set of items by path without a full reset."""
        path_set = set(paths)
        new_data = [item for item in self._appimages if item["path"] not in path_set]
        self.beginResetModel()
        self._appimages = new_data
        self._path_to_row = {item["path"]: i for i, item in enumerate(new_data)}
        self.endResetModel()

    def _add_item(self, item_dict):
        """Append a single new item."""
        row = len(self._appimages)
        self.beginInsertRows(QModelIndex(), row, row)
        self._appimages.append(item_dict)
        self._path_to_row[item_dict["path"]] = row
        self.endInsertRows()

    def _replace_item(self, old_path, new_item):
        """Replace an item in-place (handles rename: old_path → new_item['path'])."""
        row = self._path_to_row.get(old_path)
        if row is None:
            self._add_item(new_item)
            return
        del self._path_to_row[old_path]
        self._appimages[row] = new_item
        self._path_to_row[new_item["path"]] = row
        idx = self.index(row, 0)
        self.dataChanged.emit(idx, idx, list(self.roleNames().keys()))


class AppImageManager(QObject):
    appImagesChanged          = pyqtSignal()
    checkedCountChanged       = pyqtSignal()
    selectedAppImageChanged   = pyqtSignal()
    isCheckingChanged         = pyqtSignal()
    isDownloadingChanged      = pyqtSignal()
    downloadProgressChanged   = pyqtSignal()
    checkedUpdateCountChanged = pyqtSignal()
    hubInstallStatusChanged   = pyqtSignal()  # "idle"|"checking"|"downloading"|"done"|"error"
    hubInstallAppChanged      = pyqtSignal()  # name of the app being installed
    searchQueryChanged        = pyqtSignal()
    sortOrderChanged          = pyqtSignal()

    def __init__(self, settings_manager, parent=None):
        super().__init__(parent)
        self._settings = settings_manager
        self._model = AppImageModel(self)
        self._metadata_path = os.path.expanduser("~/.config/maintainer_appimages.json")
        self._metadata = self._load_metadata()
        self._nam = QNetworkAccessManager(self)
        self._selected_path = ""
        self._is_checking = False
        self._is_downloading = False
        self._download_progress = 0.0
        self._pending_checks = 0     # how many concurrent checks remain
        self._active_downloads = {}  # path -> (reply, tmp_file)
        self._batch_update_queue = []
        self._hub_install_status = "idle"
        self._hub_install_app = ""
        self._raw_appimages = []           # unfiltered list from scan()
        self._search_query = ""
        self._sort_order = "name_asc"      # name_asc | name_desc | size_asc | size_desc
        self._search_timer = QTimer(self)
        self._search_timer.setSingleShot(True)
        self._search_timer.setInterval(300)
        self._search_timer.timeout.connect(self._rebuild_model)
        self.scan()

    # ── Persistence ─────────────────────────────────────────────────────
    def _load_metadata(self):
        if os.path.exists(self._metadata_path):
            try:
                with open(self._metadata_path, "r") as f:
                    return json.load(f)
            except Exception:
                return {}
        return {}

    def _save_metadata(self):
        try:
            with open(self._metadata_path, "w") as f:
                json.dump(self._metadata, f, indent=4)
        except Exception as e:
            print(f"Error saving AppImage metadata: {e}")

    # ── Model property ───────────────────────────────────────────────────
    @pyqtProperty(QObject, notify=appImagesChanged)
    def model(self):
        return self._model

    # ── Icon Discovery ──────────────────────────────────────────────────
    def _find_local_icon(self, name):
        """Search ~/.local/share/icons for a file matching the app name efficiently."""
        icon_dirs = [
            os.path.expanduser("~/.local/share/icons"),
            os.path.expanduser("~/.icons"),
            "/usr/share/icons/hicolor/scalable/apps",
            "/usr/share/icons/hicolor/48x48/apps",
            "/usr/share/icons"
        ]
        
        # Clean up name: lowercase, remove special chars, replace spaces with -
        slug = re.sub(r'[^a-zA-Z0-9_\-]', '', name.lower().replace(" ", "-"))
        extensions = [".png", ".svg", ".ico"]
        
        for root_dir in icon_dirs:
            if not os.path.exists(root_dir):
                continue
            
            # Check for direct matches first (faster)
            for ext in extensions:
                direct_path = os.path.join(root_dir, slug + ext)
                if os.path.exists(direct_path):
                    return direct_path
            
            # Limited walk if direct match fails
            try:
                # Only check top level first, then maybe shallow walk
                files = os.listdir(root_dir)
                for f in files:
                    f_lower = f.lower()
                    if f_lower.startswith(slug) and any(f_lower.endswith(e) for e in extensions):
                        return os.path.join(root_dir, f)
            except Exception:
                pass
                
        return ""

    # ── Scan ─────────────────────────────────────────────────────────────
    @pyqtSlot()
    def scan(self):
        scan_dir = os.path.expanduser(self._settings.appImageDir)
        appimages = []

        if os.path.exists(scan_dir):
            # Clean up orphaned temp files from interrupted downloads
            active_tmp_paths = {tmp.name for _, tmp in self._active_downloads.values() if tmp}
            try:
                for fname in os.listdir(scan_dir):
                    if fname.endswith(".appimage.tmp"):
                        fpath = os.path.join(scan_dir, fname)
                        if fpath not in active_tmp_paths:
                            try:
                                os.unlink(fpath)
                            except Exception:
                                pass
            except Exception:
                pass

            try:
                files = sorted(os.listdir(scan_dir))
                for fname in files:
                    if fname.lower().endswith(".appimage"):
                        path = os.path.join(scan_dir, fname)
                        meta = self._metadata.get(path, {})
                        display_name, version = split_appimage_filename(fname)
                        try:
                            file_size = os.path.getsize(path)
                        except Exception:
                            file_size = 0
                        
                        icon_path = self._find_local_icon(display_name)
                        
                        appimages.append({
                            "name":           display_name,
                            "path":           path,
                            "update_url":     meta.get("update_url", ""),
                            "version":        version,
                            "latest_version": meta.get("latest_version", ""),
                            "release_notes":  meta.get("release_notes", ""),
                            "update_status":  "idle",
                            "is_checked":     False,
                            "size":           file_size,
                            "icon_path":      icon_path
                        })
            except Exception:
                pass

        self._raw_appimages = appimages
        self._rebuild_model()

        # Re-select previously selected item (by path match)
        if self._selected_path and self._selected_path not in self._model._path_to_row:
            self._selected_path = ""
            self.selectedAppImageChanged.emit()

    # ── Search / Sort ────────────────────────────────────────────────────

    def _rebuild_model(self):
        data = self._raw_appimages
        if self._search_query:
            q = self._search_query.lower()
            data = [a for a in data if q in a["name"].lower()]

        reverse = self._sort_order.endswith("_desc")
        if "size" in self._sort_order:
            data = sorted(data, key=lambda a: a.get("size", 0), reverse=reverse)
        else:
            data = sorted(data, key=lambda a: a["name"].lower(), reverse=reverse)

        self._model.update_data(data)
        self.appImagesChanged.emit()

    @pyqtProperty(str, notify=searchQueryChanged)
    def searchQuery(self):
        return self._search_query

    @searchQuery.setter
    def searchQuery(self, value: str):
        if self._search_query != value:
            self._search_query = value
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

    # ── Selection ────────────────────────────────────────────────────────
    @pyqtSlot(str)
    def select_appimage(self, path):
        if self._selected_path != path:
            self._selected_path = path
            self.selectedAppImageChanged.emit()

    @pyqtProperty("QVariantMap", notify=selectedAppImageChanged)
    def selectedAppImage(self):
        row = self._model._path_to_row.get(self._selected_path)
        if row is not None:
            item = self._model._appimages[row]
            return {
                "name":          item.get("name"),
                "path":          item.get("path"),
                "updateUrl":     item.get("update_url", ""),
                "version":       item.get("version", "Unknown"),
                "latestVersion": item.get("latest_version", ""),
                "updateStatus":  item.get("update_status", "idle"),
                "releaseNotes":  item.get("release_notes", ""),
                "directoryPath": os.path.dirname(item["path"]) + os.sep,
                "iconPath":      item.get("icon_path", "")
            }
        return {}

    # ── State properties ─────────────────────────────────────────────────
    @pyqtProperty(bool, notify=isCheckingChanged)
    def isChecking(self):
        return self._is_checking

    @pyqtProperty(bool, notify=isDownloadingChanged)
    def isDownloading(self):
        return self._is_downloading

    @pyqtProperty(float, notify=downloadProgressChanged)
    def downloadProgress(self):
        return self._download_progress

    @pyqtProperty(int, notify=checkedCountChanged)
    def checkedCount(self):
        return sum(1 for item in self._model._appimages if item.get("is_checked"))

    @pyqtProperty(int, notify=checkedUpdateCountChanged)
    def checkedUpdateCount(self):
        return sum(1 for item in self._model._appimages
                   if item.get("is_checked") and item.get("update_status") == "available")

    # ── Update URL management ────────────────────────────────────────────
    @pyqtSlot(str, str)
    def set_update_url(self, path, url):
        if path not in self._metadata:
            self._metadata[path] = {}
        self._metadata[path]["update_url"] = url
        self._save_metadata()
        row = self._model._path_to_row.get(path)
        if row is not None:
            self._model._appimages[row]["update_url"] = url
            idx = self._model.index(row, 0)
            self._model.dataChanged.emit(idx, idx, [AppImageModel.UpdateUrlRole])
            if path == self._selected_path:
                self.selectedAppImageChanged.emit()

    # ── Update Checks ────────────────────────────────────────────────────
    @pyqtSlot()
    def check_all_updates(self):
        """Fire off async update checks for every AppImage that has a URL."""
        urls_found = [a for a in self._model._appimages if a.get("update_url")]
        if not urls_found:
            return
        self._pending_checks = len(urls_found)
        self._set_checking(True)
        for item in urls_found:
            self._start_check(item["path"], item["update_url"])

    @pyqtSlot(str)
    def check_for_updates(self, path):
        """Fire an async update check for a single AppImage."""
        row = self._model._path_to_row.get(path)
        if row is not None:
            url = self._model._appimages[row].get("update_url", "")
            if not url:
                return
            self._pending_checks = 1
            self._set_checking(True)
            self._start_check(path, url)

    def _start_check(self, path, url):
        owner_repo = self._extract_owner_repo(url)
        if not owner_repo:
            self._update_item_by_path(path, update_status="error")
            self._decrement_checks()
            return

        self._update_item_by_path(path, update_status="checking")
        api_url = f"https://api.github.com/repos/{owner_repo}/releases/latest"
        req = QNetworkRequest(QUrl(api_url))
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "MaintainerApp/1.0")
        req.setTransferTimeout(15000)
        reply = self._nam.get(req)
        reply.setProperty("appimage_path", path)
        reply.finished.connect(lambda: self._on_check_reply(reply))

    def _on_check_reply(self, reply: QNetworkReply):
        path = reply.property("appimage_path")
        try:
            if reply.error() != QNetworkReply.NetworkError.NoError:
                self._update_item_by_path(path, update_status="error")
                return

            data = json.loads(bytes(reply.readAll()).decode("utf-8"))
            latest_tag = data.get("tag_name", "")
            notes = data.get("body", "")

            row = self._model._path_to_row.get(path)
            local_version = self._model._appimages[row].get("version", "") if row is not None else ""

            local_clean = local_version.lstrip("v")
            latest_clean = latest_tag.lstrip("v")

            if latest_clean and latest_clean != local_clean:
                status = "available"
            elif latest_clean:
                status = "up-to-date"
            else:
                status = "error"

            appimage_assets = self._filter_appimage_assets(data.get("assets", []))

            if path not in self._metadata:
                self._metadata[path] = {}
            self._metadata[path]["latest_version"] = latest_tag
            self._metadata[path]["release_notes"] = notes
            self._metadata[path]["latest_assets"] = appimage_assets
            self._save_metadata()

            self._update_item_by_path(path, update_status=status,
                                      latest_version=latest_tag,
                                      release_notes=notes)

        except Exception as e:
            print(f"Update check error: {e}")
            self._update_item_by_path(path, update_status="error")
        finally:
            reply.deleteLater()
            self._decrement_checks()

    # ── Download & Replace ───────────────────────────────────────────────
    @pyqtSlot()
    def download_checked(self):
        """Download updates for all checked AppImages that have updates available."""
        if self._is_downloading:
            return

        to_update = [
            i["path"] for i in self._model._appimages
            if i.get("is_checked") and i.get("update_status") == "available"
        ]

        if not to_update:
            return

        self._batch_update_queue = to_update
        self._process_update_queue()

    def _process_update_queue(self):
        if not self._batch_update_queue:
            return
        next_path = self._batch_update_queue.pop(0)
        self.download_update(next_path)

    @pyqtSlot(str)
    def download_update(self, path):
        """Download the latest release asset and replace the existing file."""
        if self._is_downloading:
            return

        meta = self._metadata.get(path, {})
        assets = meta.get("latest_assets", [])
        asset = self._pick_best_asset(assets)

        if not asset:
            print("No suitable download asset found.")
            return

        download_url = asset.get("browser_download_url", "")
        new_name = asset.get("name", os.path.basename(path))
        new_path = os.path.join(os.path.dirname(path), new_name)

        self._set_downloading(True)
        self._download_progress = 0.0
        self.downloadProgressChanged.emit()

        self._update_item_by_path(path, update_status="downloading")

        req = QNetworkRequest(QUrl(download_url))
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "MaintainerApp/1.0")
        req.setTransferTimeout(0)
        reply = self._nam.get(req)
        reply.setProperty("old_path", path)
        reply.setProperty("new_path", new_path)

        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".appimage.tmp",
                                         dir=os.path.dirname(path))
        self._active_downloads[path] = (reply, tmp)

        reply.downloadProgress.connect(self._on_download_progress)
        reply.finished.connect(lambda: self._on_download_finished(reply))

    def _on_download_progress(self, received, total):
        if total > 0:
            self._download_progress = received / total
            self.downloadProgressChanged.emit()

    def _on_download_finished(self, reply: QNetworkReply):
        old_path = reply.property("old_path")
        new_path = reply.property("new_path")
        _, tmp = self._active_downloads.pop(old_path, (None, None))

        try:
            if reply.error() != QNetworkReply.NetworkError.NoError:
                print(f"Download error: {reply.errorString()}")
                self._update_item_by_path(old_path, update_status="error")
                if tmp:
                    try:
                        os.unlink(tmp.name)
                    except Exception:
                        pass
                return

            data = bytes(reply.readAll())
            if tmp:
                tmp.write(data)
                tmp.flush()
                tmp.close()
                os.chmod(tmp.name, 0o755)

                if old_path != new_path and os.path.exists(old_path):
                    os.remove(old_path)
                    if old_path in self._metadata:
                        old_meta = self._metadata.pop(old_path)
                        self._metadata[new_path] = old_meta
                shutil.move(tmp.name, new_path)
                self._save_metadata()
                print(f"Download complete: {new_path}")

            # Incremental model update: replace or update in-place
            meta = self._metadata.get(new_path, {})
            display_name, version = split_appimage_filename(os.path.basename(new_path))
            new_item = {
                "name":           display_name,
                "path":           new_path,
                "update_url":     meta.get("update_url", ""),
                "version":        version,
                "latest_version": meta.get("latest_version", ""),
                "release_notes":  meta.get("release_notes", ""),
                "update_status":  "up-to-date",
                "is_checked":     False,
            }
            if old_path == new_path:
                self._model._set_field(
                    self._model._path_to_row[new_path],
                    name=display_name, version=version,
                    update_status="up-to-date",
                    latest_version=meta.get("latest_version", "")
                )
            else:
                if self._selected_path == old_path:
                    self._selected_path = new_path
                self._model._replace_item(old_path, new_item)
            self.appImagesChanged.emit()
            if self._selected_path == new_path:
                self.selectedAppImageChanged.emit()

        except Exception as e:
            print(f"Download finalization error: {e}")
        finally:
            reply.deleteLater()
            self._set_downloading(False)
            self._download_progress = 0.0
            self.downloadProgressChanged.emit()
            if self._batch_update_queue:
                self._process_update_queue()

    # ── Delete ────────────────────────────────────────────────────────────
    @pyqtSlot(str)
    def delete_appimage(self, path):
        try:
            if os.path.exists(path):
                os.remove(path)
            if path in self._metadata:
                del self._metadata[path]
                self._save_metadata()
        except Exception as e:
            print(f"Error deleting AppImage: {e}")
        finally:
            if self._selected_path == path:
                self._selected_path = ""
                self.selectedAppImageChanged.emit()
            self._model._remove_items([path])
            self.appImagesChanged.emit()

    @pyqtSlot()
    def delete_checked(self):
        to_delete = [i["path"] for i in self._model._appimages if i.get("is_checked")]
        if not to_delete:
            return
        for path in to_delete:
            try:
                if os.path.exists(path):
                    os.remove(path)
                if path in self._metadata:
                    del self._metadata[path]
            except Exception as e:
                print(f"Batch delete error: {e}")
        self._save_metadata()
        if self._selected_path in to_delete:
            self._selected_path = ""
            self.selectedAppImageChanged.emit()
        self._model._remove_items(to_delete)
        self.appImagesChanged.emit()

    # ── Hub install ───────────────────────────────────────────────────────

    @pyqtProperty(str, notify=hubInstallStatusChanged)
    def hubInstallStatus(self):
        return self._hub_install_status

    @pyqtProperty(str, notify=hubInstallAppChanged)
    def hubInstallApp(self):
        return self._hub_install_app

    @pyqtProperty("QVariantList", notify=appImagesChanged)
    def installedOwnerRepos(self):
        """Return list of lowercase 'owner/repo' strings for all installed AppImages."""
        repos = []
        for meta in self._metadata.values():
            url = meta.get("update_url", "")
            m = re.search(r"github\.com/([^/]+/[^/]+)", url)
            if m:
                repos.append(m.group(1).lower().rstrip("/"))
        return repos

    @pyqtSlot(str, str)
    def install_from_hub(self, owner_repo: str, display_name: str):
        """Fetch the latest GitHub release for owner_repo and download the AppImage."""
        if self._hub_install_status in ("checking", "downloading"):
            return
        self._set_hub_install_app(display_name)
        self._set_hub_install_status("checking")
        api_url = f"https://api.github.com/repos/{owner_repo}/releases/latest"
        req = QNetworkRequest(QUrl(api_url))
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "MaintainerApp/1.0")
        req.setTransferTimeout(15000)
        reply = self._nam.get(req)
        reply.setProperty("hub_owner_repo", owner_repo)
        reply.setProperty("hub_display_name", display_name)
        reply.finished.connect(lambda: self._on_hub_check_reply(reply))

    def _on_hub_check_reply(self, reply: QNetworkReply):
        owner_repo = reply.property("hub_owner_repo")
        display_name = reply.property("hub_display_name")
        try:
            if reply.error() != QNetworkReply.NetworkError.NoError:
                self._set_hub_install_status("error")
                QTimer.singleShot(3000, lambda: self._set_hub_install_status("idle"))
                return

            data = json.loads(bytes(reply.readAll()).decode("utf-8"))
            latest_tag = data.get("tag_name", "").lstrip("v")
            asset = self._pick_best_asset(self._filter_appimage_assets(data.get("assets", [])))

            if not asset:
                print(f"Hub install: no AppImage asset found for {owner_repo}")
                self._set_hub_install_status("error")
                QTimer.singleShot(3000, lambda: self._set_hub_install_status("idle"))
                return

            download_url = asset.get("browser_download_url", "")
            asset_name = asset.get("name", f"{display_name}-{latest_tag}-x86_64.AppImage")
            scan_dir = os.path.expanduser(self._settings.appImageDir)
            os.makedirs(scan_dir, exist_ok=True)
            dest_path = os.path.join(scan_dir, asset_name)

            self._set_hub_install_status("downloading")
            self._set_downloading(True)
            self._download_progress = 0.0
            self.downloadProgressChanged.emit()

            dl_req = QNetworkRequest(QUrl(download_url))
            dl_req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "MaintainerApp/1.0")
            dl_req.setTransferTimeout(0)
            dl_reply = self._nam.get(dl_req)
            dl_reply.setProperty("hub_dest_path", dest_path)
            dl_reply.setProperty("hub_owner_repo", owner_repo)
            dl_reply.setProperty("hub_latest_tag", latest_tag)
            dl_reply.setProperty("hub_asset_name", asset_name)

            tmp = tempfile.NamedTemporaryFile(
                delete=False, suffix=".appimage.tmp", dir=scan_dir
            )
            self._active_downloads[dest_path] = (dl_reply, tmp)
            dl_reply.downloadProgress.connect(self._on_download_progress)
            dl_reply.finished.connect(lambda: self._on_hub_download_finished(dl_reply))

        except Exception as e:
            print(f"Hub install check error: {e}")
            self._set_hub_install_status("error")
            QTimer.singleShot(3000, lambda: self._set_hub_install_status("idle"))
        finally:
            reply.deleteLater()

    def _on_hub_download_finished(self, reply: QNetworkReply):
        dest_path = reply.property("hub_dest_path")
        owner_repo = reply.property("hub_owner_repo")
        latest_tag = reply.property("hub_latest_tag")
        asset_name = reply.property("hub_asset_name") or os.path.basename(dest_path)
        _, tmp = self._active_downloads.pop(dest_path, (None, None))
        try:
            if reply.error() != QNetworkReply.NetworkError.NoError:
                print(f"Hub download error: {reply.errorString()}")
                self._set_hub_install_status("error")
                if tmp:
                    try:
                        os.unlink(tmp.name)
                    except Exception:
                        pass
                QTimer.singleShot(3000, lambda: self._set_hub_install_status("idle"))
                return

            data = bytes(reply.readAll())
            if tmp:
                tmp.write(data)
                tmp.flush()
                tmp.close()
                os.chmod(tmp.name, 0o755)
                shutil.move(tmp.name, dest_path)

            # Register metadata so future update checks work
            if dest_path not in self._metadata:
                self._metadata[dest_path] = {}
            self._metadata[dest_path]["update_url"] = f"https://github.com/{owner_repo}"
            self._metadata[dest_path]["latest_version"] = latest_tag
            self._save_metadata()

            # Add new item to model incrementally
            display_name, version = split_appimage_filename(asset_name)
            new_item = {
                "name":           display_name,
                "path":           dest_path,
                "update_url":     f"https://github.com/{owner_repo}",
                "version":        version,
                "latest_version": latest_tag,
                "release_notes":  "",
                "update_status":  "idle",
                "is_checked":     False,
            }
            self._model._add_item(new_item)
            self.appImagesChanged.emit()

            self._set_hub_install_status("done")
            QTimer.singleShot(3000, lambda: self._set_hub_install_status("idle"))

        except Exception as e:
            print(f"Hub download finalize error: {e}")
            self._set_hub_install_status("error")
            QTimer.singleShot(3000, lambda: self._set_hub_install_status("idle"))
        finally:
            reply.deleteLater()
            self._set_downloading(False)
            self._download_progress = 0.0
            self.downloadProgressChanged.emit()

    def _set_hub_install_status(self, value):
        if self._hub_install_status != value:
            self._hub_install_status = value
            self.hubInstallStatusChanged.emit()

    def _set_hub_install_app(self, value):
        if self._hub_install_app != value:
            self._hub_install_app = value
            self.hubInstallAppChanged.emit()

    # ── Asset helpers (shared by update check + hub install) ─────────────
    @staticmethod
    def _filter_appimage_assets(assets):
        """Return only AppImage assets from a GitHub releases asset list."""
        return [
            a for a in assets
            if a.get("name", "").lower().endswith(".appimage")
            or ".appimage" in a.get("browser_download_url", "").lower()
        ]

    @staticmethod
    def _pick_best_asset(appimage_assets):
        """From AppImage assets, prefer x86_64/amd64; fall back to first."""
        for a in appimage_assets:
            aname = a.get("name", "").lower()
            if "x86_64" in aname or "amd64" in aname:
                return a
        return appimage_assets[0] if appimage_assets else None

    # ── Helpers ───────────────────────────────────────────────────────────
    @staticmethod
    def _extract_owner_repo(url: str):
        """Given https://github.com/owner/repo[/...], return 'owner/repo'."""
        m = re.search(r"github\.com/([^/]+/[^/]+)", url)
        if m:
            return m.group(1).rstrip("/")
        return None

    def _update_item_by_path(self, path, **kwargs):
        row = self._model._path_to_row.get(path)
        if row is not None:
            self._model._set_field(row, **kwargs)
            if path == self._selected_path:
                self.selectedAppImageChanged.emit()

    def _set_checking(self, value):
        if self._is_checking != value:
            self._is_checking = value
            self.isCheckingChanged.emit()
            if not value:
                self.checkedUpdateCountChanged.emit()

    def _set_downloading(self, value):
        if self._is_downloading != value:
            self._is_downloading = value
            self.isDownloadingChanged.emit()

    def _decrement_checks(self):
        self._pending_checks = max(0, self._pending_checks - 1)
        if self._pending_checks == 0:
            self._set_checking(False)
