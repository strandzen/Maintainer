import sys
import os
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import Qt

from models.system_health import SystemHealth
from models.task_engine import TaskEngine
from models.task_registry import TaskRegistry
from models.settings_manager import SettingsManager
from models.sidebar_model import SidebarModel
from models.ui_strings_manager import UIStringsManager
from models.ui_icons_manager import UIIconsManager
from models.ui_colors_manager import UIColorsManager
from models.appimage_manager import AppImageManager
from models.appimage_hub import AppImageHubManager
from models.package_manager import PackageManager
from models.ui_fonts_manager import UIFontsManager

def main():
    # Set up the application
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Maintainer")
    app.setApplicationDisplayName("Maintainer Project")
    
    # Optional: set organization name and domain for settings
    app.setOrganizationName("MaintainerTeam")
    app.setOrganizationDomain("maintainer.org")

    # Initialize Backend Models
    system_health = SystemHealth(app)
    task_engine = TaskEngine(app)
    settings_manager = SettingsManager(app)

    # Load tasks from configuration
    config_path = os.path.join(os.path.dirname(__file__), "tasks_config.json")
    task_registry = TaskRegistry(config_path, app, settings_manager)
    
    # Load UI strings and icons
    ui_strings_path = os.path.join(os.path.dirname(__file__), "ui_strings.json")
    ui_strings_manager = UIStringsManager(ui_strings_path, app)
    
    ui_icons_path = os.path.join(os.path.dirname(__file__), "ui_icons.json")
    ui_icons_manager = UIIconsManager(ui_icons_path, app)

    ui_colors_path = os.path.join(os.path.dirname(__file__), "ui_colors.json")
    ui_colors_manager = UIColorsManager(ui_colors_path, app)
    
    ui_fonts_path = os.path.join(os.path.dirname(__file__), "ui_fonts.json")
    ui_fonts_manager = UIFontsManager(ui_fonts_path, app)

    # Initialize Sidebar Model
    sidebar_config_path = os.path.join(os.path.dirname(__file__), "ui_left_list.json")
    sidebar_model = SidebarModel(sidebar_config_path, settings_manager=settings_manager, task_registry=task_registry, parent=app)
    
    # Initialize AppImage Manager
    appimage_manager = AppImageManager(settings_manager, app)
    appimage_hub = AppImageHubManager(app)

    # Initialize Package Manager
    package_manager = PackageManager(settings_manager=settings_manager, parent=app)
    package_manager.refresh()
    if settings_manager.checkUpdatesOnStartup:
        package_manager.check_updates()

    # Setup QML Engine
    engine = QQmlApplicationEngine()
    
    # Expose Python objects to QML context
    context = engine.rootContext()
    context.setContextProperty("SystemHealth", system_health)
    context.setContextProperty("TaskEngine", task_engine)
    context.setContextProperty("TaskRegistry", task_registry)
    context.setContextProperty("SettingsManager", settings_manager)
    context.setContextProperty("SidebarModel", sidebar_model)
    context.setContextProperty("UIStrings", ui_strings_manager)
    context.setContextProperty("UIIcons", ui_icons_manager)
    context.setContextProperty("UIColors", ui_colors_manager)
    context.setContextProperty("UIFonts", ui_fonts_manager)
    context.setContextProperty("AppImageManager", appimage_manager)
    context.setContextProperty("AppImageHub", appimage_hub)
    context.setContextProperty("PackageManager", package_manager)

    # Start background hub feed fetch (uses cache if fresh, network otherwise)
    appimage_hub.fetch()

    # Load the main QML file
    engine.load("qml/main.qml")

    if not engine.rootObjects():
        sys.exit(-1)

    # Stop background timers before any threads are joined on exit
    def on_about_to_quit():
        system_health._fast_timer.stop()
        system_health._medium_timer.stop()
        system_health._app_timer.stop()

    app.aboutToQuit.connect(on_about_to_quit)

    result = app.exec()
    # os._exit is used intentionally: PyQt6 QThread objects can trigger SIGABRT
    # during interpreter teardown if their run() methods haven't returned yet.
    # Proper fix requires each worker to support a stop() signal.
    os._exit(result)

if __name__ == "__main__":
    main()
