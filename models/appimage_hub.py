import os
import json
import time
import re

from PyQt6.QtCore import (
    QObject, QUrl, pyqtProperty, pyqtSignal, pyqtSlot,
    QAbstractListModel, Qt, QModelIndex, QSortFilterProxyModel
)
from PyQt6.QtNetwork import QNetworkAccessManager, QNetworkRequest, QNetworkReply


FEED_URL = "https://appimage.github.io/feed.json"
ICON_BASE = "https://appimage.github.io/"
CACHE_DIR = os.path.expanduser("~/.cache/maintainer")
CACHE_FILE = os.path.join(CACHE_DIR, "hub_feed.json")
CACHE_MAX_AGE = 86400  # 24 hours
CUSTOM_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "appimage_custom.json")


class AppImageHubModel(QAbstractListModel):
    NameRole        = Qt.ItemDataRole.UserRole + 1
    DescriptionRole = Qt.ItemDataRole.UserRole + 2
    CategoriesRole  = Qt.ItemDataRole.UserRole + 3
    IconUrlRole     = Qt.ItemDataRole.UserRole + 4
    OwnerRepoRole   = Qt.ItemDataRole.UserRole + 5
    LicenseRole     = Qt.ItemDataRole.UserRole + 6
    GithubAvatarRole = Qt.ItemDataRole.UserRole + 7

    def __init__(self, parent=None):
        super().__init__(parent)
        self._items = []

    def rowCount(self, parent=QModelIndex()):
        return len(self._items)

    def data(self, index, role):
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None
        item = self._items[index.row()]
        if role == self.NameRole:        return item.get("name", "")
        if role == self.DescriptionRole: return item.get("description", "")
        if role == self.CategoriesRole:  return item.get("categories", [])
        if role == self.IconUrlRole:     return item.get("icon_url", "")
        if role == self.OwnerRepoRole:   return item.get("owner_repo", "")
        if role == self.LicenseRole:     return item.get("license", "")
        if role == self.GithubAvatarRole: return item.get("github_avatar_url", "")
        return None

    def roleNames(self):
        return {
            self.NameRole:        b"name",
            self.DescriptionRole: b"description",
            self.CategoriesRole:  b"categories",
            self.IconUrlRole:     b"iconUrl",
            self.OwnerRepoRole:   b"ownerRepo",
            self.LicenseRole:     b"license",
            self.GithubAvatarRole: b"githubAvatarUrl",
        }

    def reset_data(self, items):
        self.beginResetModel()
        self._items = items
        self.endResetModel()


class AppImageHubFilterModel(QSortFilterProxyModel):
    def __init__(self, source_model, parent=None):
        super().__init__(parent)
        self.setSourceModel(source_model)
        self._search = ""

    def set_search(self, text):
        self._search = text.strip().lower()
        self.invalidateFilter()

    def filterAcceptsRow(self, source_row, source_parent):
        if not self._search:
            return True
        model = self.sourceModel()
        idx = model.index(source_row, 0, source_parent)
        name = (model.data(idx, AppImageHubModel.NameRole) or "").lower()
        desc = (model.data(idx, AppImageHubModel.DescriptionRole) or "").lower()
        return self._search in name or self._search in desc


class AppImageHubManager(QObject):
    isLoadingChanged = pyqtSignal()
    errorChanged     = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._source_model = AppImageHubModel(self)
        self._filter_model = AppImageHubFilterModel(self._source_model, self)
        self._nam = QNetworkAccessManager(self)
        self._is_loading = False
        self._error = ""

    @pyqtProperty(QObject, constant=True)
    def model(self):
        return self._filter_model

    @pyqtProperty(bool, notify=isLoadingChanged)
    def isLoading(self):
        return self._is_loading

    @pyqtProperty(str, notify=errorChanged)
    def error(self):
        return self._error

    @pyqtSlot()
    def fetch(self):
        """Load from cache if fresh, otherwise fetch from network."""
        if self._is_loading:
            return
        cache_loaded = self._load_from_cache()
        if not cache_loaded or not self._is_cache_fresh():
            self._fetch_from_network()

    @pyqtSlot()
    def refresh(self):
        """Force a fresh network fetch, ignoring cache age."""
        if self._is_loading:
            return
        self._fetch_from_network()

    @pyqtSlot(str)
    def setSearch(self, text):
        self._filter_model.set_search(text)

    # ── Cache ─────────────────────────────────────────────────────────────

    def _is_cache_fresh(self):
        if not os.path.exists(CACHE_FILE):
            return False
        return (time.time() - os.path.getmtime(CACHE_FILE)) < CACHE_MAX_AGE

    def _load_from_cache(self):
        if not os.path.exists(CACHE_FILE):
            return False
        try:
            with open(CACHE_FILE, "r") as f:
                data = json.load(f)
            self._populate_model(data.get("items", []))
            return True
        except Exception as e:
            print(f"[AppImageHub] cache load error: {e}")
            return False

    def _save_cache(self, data):
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
            with open(CACHE_FILE, "w") as f:
                json.dump(data, f)
        except Exception as e:
            print(f"AppImageHub cache write error: {e}")

    # ── Network ───────────────────────────────────────────────────────────

    def _fetch_from_network(self):
        self._set_loading(True)
        self._set_error("")
        req = QNetworkRequest(QUrl(FEED_URL))
        req.setHeader(QNetworkRequest.KnownHeaders.UserAgentHeader, "MaintainerApp/1.0")
        req.setTransferTimeout(15000)
        reply = self._nam.get(req)
        reply.finished.connect(lambda: self._on_feed_reply(reply))

    def _on_feed_reply(self, reply: QNetworkReply):
        try:
            if reply.error() != QNetworkReply.NetworkError.NoError:
                self._set_error(f"Failed to load AppImageHub: {reply.errorString()}")
                return
            data = json.loads(bytes(reply.readAll()).decode("utf-8"))
            self._populate_model(data.get("items", []))
            self._save_cache(data)
        except Exception as e:
            self._set_error(f"Failed to parse AppImageHub feed: {e}")
        finally:
            reply.deleteLater()
            self._set_loading(False)

    # ── Model population ──────────────────────────────────────────────────

    def _populate_model(self, raw_items):
        items = []
        for item in raw_items:
            name = item.get("name", "")
            if not name:
                continue
            # Extract GitHub owner/repo — skip apps without one (can't install)
            owner_repo = ""
            for link in (item.get("links") or []):
                if link.get("type") == "GitHub":
                    owner_repo = link.get("url", "")
                    break
            if not owner_repo:
                continue
            icons = item.get("icons") or []
            icon_url = (ICON_BASE + icons[0]) if icons else ""
            items.append({
                "name":        name,
                "description": item.get("description") or "",
                "categories":  item.get("categories") or [],
                "icon_url":    icon_url,
                "owner_repo":  owner_repo,
                "license":     item.get("license") or "",
                "github_avatar_url": f"https://github.com/{owner_repo.split('/')[0]}.png?size=128" if "/" in owner_repo else ""
             })

        # Merge custom items
        custom_items = self._load_custom_items()
        for c in custom_items:
            # Avoid duplicates if they already exist in the hub feed
            if not any(i["owner_repo"].lower() == c["owner_repo"].lower() for i in items):
                items.append(c)

        self._source_model.reset_data(items)

    def _load_custom_items(self):
        """Load manually defined AppImage entries from appimage_custom.json."""
        if not os.path.exists(CUSTOM_FILE):
            return []
        try:
            with open(CUSTOM_FILE, "r") as f:
                data = json.load(f)
            custom_items = []
            for item in data.get("items", []):
                name = item.get("name", "")
                url = item.get("github_url", "")
                if not name or not url:
                    continue
                owner_repo = self._parse_github_url(url)
                if not owner_repo:
                    continue
                custom_items.append({
                    "name":        name,
                    "description": item.get("description") or "",
                    "categories":  item.get("categories") or ["Custom"],
                    "icon_url":    item.get("icon_url") or "",
                    "owner_repo":  owner_repo,
                    "license":     item.get("license") or "Custom",
                })
            return custom_items
        except Exception as e:
            print(f"[AppImageHub] custom load error: {e}")
            return []

    def _parse_github_url(self, url):
        """Extract owner/repo from a full GitHub URL or return as-is if already in format."""
        url = url.strip().rstrip("/")
        # If it's already "owner/repo" and not a full URL
        if "/" in url and "://" not in url and not url.startswith("www."):
            # Check if it looks like owner/repo (2 parts)
            parts = url.split("/")
            if len(parts) == 2:
                return url
        
        # Try to parse full URL: https://github.com/owner/repo
        match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
        if match:
            return f"{match.group(1)}/{match.group(2)}"
        return ""

    # ── Helpers ───────────────────────────────────────────────────────────

    def _set_loading(self, value):
        if self._is_loading != value:
            self._is_loading = value
            self.isLoadingChanged.emit()

    def _set_error(self, value):
        if self._error != value:
            self._error = value
            self.errorChanged.emit()
