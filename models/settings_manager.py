import os
from PyQt6.QtCore import QObject, QSettings, pyqtProperty, pyqtSignal, pyqtSlot

class SettingsManager(QObject):
    cornerRadiusChanged = pyqtSignal()
    packageCacheCountChanged = pyqtSignal()
    journalLogAgeChanged = pyqtSignal()
    ghostConfigBlacklistChanged = pyqtSignal()
    favoriteTasksChanged = pyqtSignal()
    corpseCleanerCustomPathsChanged = pyqtSignal()
    scriptsDirChanged = pyqtSignal()
    aurHelperChanged = pyqtSignal()
    checkUpdatesOnStartupChanged = pyqtSignal()
    emphasisColorChanged = pyqtSignal()
    cpuColorChanged = pyqtSignal()
    memoryColorChanged = pyqtSignal()
    downloadColorChanged = pyqtSignal()
    uploadColorChanged = pyqtSignal()
    swapColorChanged = pyqtSignal()
    enableContrastBordersChanged = pyqtSignal()
    alternatingRowColorsChanged = pyqtSignal()
    globalFontChanged = pyqtSignal()
    globalFontSizeChanged = pyqtSignal()
    defaultFontFamilyChanged = pyqtSignal()
    defaultFontSizeChanged = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.settings = QSettings(QSettings.Format.IniFormat, QSettings.Scope.UserScope, "MaintainerTeam", "Maintainer")
        
        # Initialize defaults if they don't exist
        if not self.settings.contains("cornerRadius"):
            self.settings.setValue("cornerRadius", 8)
        if not self.settings.contains("packageCacheCount"):
            self.settings.setValue("packageCacheCount", 3)
        if not self.settings.contains("journalLogAge"):
            self.settings.setValue("journalLogAge", "2weeks")
        if not self.settings.contains("ghostConfigBlacklist"):
            self.settings.setValue("ghostConfigBlacklist", "obs-studio,kde,plasma")
        if not self.settings.contains("favoriteTasks"):
            self.settings.setValue("favoriteTasks", ["Clear Pacman Cache"])
        if not self.settings.contains("corpseCleanerCustomPaths"):
            self.settings.setValue("corpseCleanerCustomPaths", "")
        if not self.settings.contains("scriptsDir"):
            project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            self.settings.setValue("scriptsDir", os.path.join(project_root, "scripts"))
        if not self.settings.contains("aurHelper"):
            self.settings.setValue("aurHelper", "pacman")
        if not self.settings.contains("checkUpdatesOnStartup"):
            self.settings.setValue("checkUpdatesOnStartup", True)
        if not self.settings.contains("enableContrastBorders"):
            self.settings.setValue("enableContrastBorders", True)
        if not self.settings.contains("emphasisColor"):
            self.settings.setValue("emphasisColor", "")
        for key in ("cpuColor", "memoryColor", "downloadColor", "uploadColor", "swapColor"):
            if not self.settings.contains(key):
                self.settings.setValue(key, "")
        if not self.settings.contains("alternatingRowColors"):
            self.settings.setValue("alternatingRowColors", False)
        if not self.settings.contains("globalFont"):
            self.settings.setValue("globalFont", "")
        if not self.settings.contains("globalFontSize"):
            self.settings.setValue("globalFontSize", 10)
        
        self._defaultFontFamily = ""
        self._defaultFontSize = 10

    @pyqtProperty(int, notify=cornerRadiusChanged)
    def cornerRadius(self):
        return int(self.settings.value("cornerRadius", 8))

    @cornerRadius.setter
    def cornerRadius(self, value):
        if self.cornerRadius != value:
            self.settings.setValue("cornerRadius", value)
            self.cornerRadiusChanged.emit()

    @pyqtProperty(int, notify=packageCacheCountChanged)
    def packageCacheCount(self):
        return int(self.settings.value("packageCacheCount", 3))

    @packageCacheCount.setter
    def packageCacheCount(self, value):
        if self.packageCacheCount != value:
            self.settings.setValue("packageCacheCount", value)
            self.packageCacheCountChanged.emit()

    @pyqtProperty(str, notify=journalLogAgeChanged)
    def journalLogAge(self):
        return str(self.settings.value("journalLogAge", "2weeks"))

    @journalLogAge.setter
    def journalLogAge(self, value):
        if self.journalLogAge != value:
            self.settings.setValue("journalLogAge", value)
            self.journalLogAgeChanged.emit()

    @pyqtProperty(str, notify=ghostConfigBlacklistChanged)
    def ghostConfigBlacklist(self):
        return str(self.settings.value("ghostConfigBlacklist", "obs-studio,kde,plasma"))

    @ghostConfigBlacklist.setter
    def ghostConfigBlacklist(self, value):
        if self.ghostConfigBlacklist != value:
            self.settings.setValue("ghostConfigBlacklist", value)
            self.ghostConfigBlacklistChanged.emit()

    @pyqtProperty(list, notify=favoriteTasksChanged)
    def favoriteTasks(self):
        val = self.settings.value("favoriteTasks", [])
        if isinstance(val, str):
            return [val] if val else []
        if val is None:
            return []
        return list(val)

    @favoriteTasks.setter
    def favoriteTasks(self, value):
        # value comes in as a Javascript array (list in python)
        if self.favoriteTasks != value:
            self.settings.setValue("favoriteTasks", value)
            self.favoriteTasksChanged.emit()

    @pyqtProperty(str, notify=corpseCleanerCustomPathsChanged)
    def corpseCleanerCustomPaths(self):
        return self.settings.value("corpseCleanerCustomPaths", "")

    @corpseCleanerCustomPaths.setter
    def corpseCleanerCustomPaths(self, value):
        if self.corpseCleanerCustomPaths != value:
            self.settings.setValue("corpseCleanerCustomPaths", str(value))
            self.corpseCleanerCustomPathsChanged.emit()

    @pyqtProperty(str, notify=scriptsDirChanged)
    def scriptsDir(self):
        return str(self.settings.value("scriptsDir", ""))

    @scriptsDir.setter
    def scriptsDir(self, value):
        if self.scriptsDir != value:
            self.settings.setValue("scriptsDir", str(value))
            self.scriptsDirChanged.emit()

    @pyqtProperty(str, notify=aurHelperChanged)
    def aurHelper(self):
        return str(self.settings.value("aurHelper", "pacman"))

    @aurHelper.setter
    def aurHelper(self, value):
        if self.aurHelper != value:
            self.settings.setValue("aurHelper", str(value))
            self.aurHelperChanged.emit()

    appImageDirChanged = pyqtSignal()
    @pyqtProperty(str, notify=appImageDirChanged)
    def appImageDir(self):
        default = os.path.expanduser("~/Applications")
        return str(self.settings.value("appImageDir", default))

    @appImageDir.setter
    def appImageDir(self, value):
        if self.appImageDir != value:
            self.settings.setValue("appImageDir", str(value))
            self.appImageDirChanged.emit()

    @pyqtProperty(bool, notify=checkUpdatesOnStartupChanged)
    def checkUpdatesOnStartup(self):
        return bool(self.settings.value("checkUpdatesOnStartup", True, type=bool))

    @checkUpdatesOnStartup.setter
    def checkUpdatesOnStartup(self, value):
        if self.checkUpdatesOnStartup != value:
            self.settings.setValue("checkUpdatesOnStartup", bool(value))
            self.checkUpdatesOnStartupChanged.emit()

    @pyqtProperty(bool, notify=enableContrastBordersChanged)
    def enableContrastBorders(self):
        return bool(self.settings.value("enableContrastBorders", True, type=bool))

    @enableContrastBorders.setter
    def enableContrastBorders(self, value):
        if self.enableContrastBorders != value:
            self.settings.setValue("enableContrastBorders", bool(value))
            self.enableContrastBordersChanged.emit()

    @pyqtProperty(str, notify=emphasisColorChanged)
    def emphasisColor(self):
        return str(self.settings.value("emphasisColor", ""))

    @emphasisColor.setter
    def emphasisColor(self, value):
        if self.emphasisColor != value:
            self.settings.setValue("emphasisColor", str(value))
            self.emphasisColorChanged.emit()

    @pyqtProperty(str, notify=cpuColorChanged)
    def cpuColor(self):
        return str(self.settings.value("cpuColor", ""))

    @cpuColor.setter
    def cpuColor(self, value):
        if self.cpuColor != value:
            self.settings.setValue("cpuColor", str(value))
            self.cpuColorChanged.emit()

    @pyqtProperty(str, notify=memoryColorChanged)
    def memoryColor(self):
        return str(self.settings.value("memoryColor", ""))

    @memoryColor.setter
    def memoryColor(self, value):
        if self.memoryColor != value:
            self.settings.setValue("memoryColor", str(value))
            self.memoryColorChanged.emit()

    @pyqtProperty(str, notify=downloadColorChanged)
    def downloadColor(self):
        return str(self.settings.value("downloadColor", ""))

    @downloadColor.setter
    def downloadColor(self, value):
        if self.downloadColor != value:
            self.settings.setValue("downloadColor", str(value))
            self.downloadColorChanged.emit()

    @pyqtProperty(str, notify=uploadColorChanged)
    def uploadColor(self):
        return str(self.settings.value("uploadColor", ""))

    @uploadColor.setter
    def uploadColor(self, value):
        if self.uploadColor != value:
            self.settings.setValue("uploadColor", str(value))
            self.uploadColorChanged.emit()

    @pyqtProperty(str, notify=swapColorChanged)
    def swapColor(self):
        return str(self.settings.value("swapColor", ""))

    @swapColor.setter
    def swapColor(self, value):
        if self.swapColor != value:
            self.settings.setValue("swapColor", str(value))
            self.swapColorChanged.emit()

    @pyqtProperty(bool, notify=alternatingRowColorsChanged)
    def alternatingRowColors(self):
        return bool(self.settings.value("alternatingRowColors", False, type=bool))

    @alternatingRowColors.setter
    def alternatingRowColors(self, value):
        if self.alternatingRowColors != value:
            self.settings.setValue("alternatingRowColors", bool(value))
            self.alternatingRowColorsChanged.emit()

    @pyqtProperty(str, notify=globalFontChanged)
    def globalFont(self):
        return str(self.settings.value("globalFont", ""))

    @globalFont.setter
    def globalFont(self, value):
        if self.globalFont != value:
            self.settings.setValue("globalFont", str(value))
            self.globalFontChanged.emit()

    @pyqtProperty(int, notify=globalFontSizeChanged)
    def globalFontSize(self):
        return int(self.settings.value("globalFontSize", 10))

    @globalFontSize.setter
    def globalFontSize(self, value):
        if self.globalFontSize != value:
            self.settings.setValue("globalFontSize", int(value))
            self.globalFontSizeChanged.emit()

    @pyqtProperty(str, notify=defaultFontFamilyChanged)
    def defaultFontFamily(self):
        return self._defaultFontFamily

    @defaultFontFamily.setter
    def defaultFontFamily(self, value):
        if self._defaultFontFamily != value:
            self._defaultFontFamily = str(value)
            self.defaultFontFamilyChanged.emit()

    @pyqtProperty(int, notify=defaultFontSizeChanged)
    def defaultFontSize(self):
        return self._defaultFontSize

    @defaultFontSize.setter
    def defaultFontSize(self, value):
        if self._defaultFontSize != value:
            self._defaultFontSize = int(value)
            self.defaultFontSizeChanged.emit()
