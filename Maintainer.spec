# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('qml', 'qml'),
        ('icons', 'icons'),
        ('tasks', 'tasks'),
        ('utils', 'utils'),
        ('ui_colors.json', '.'),
        ('ui_fonts.json', '.'),
        ('ui_icons.json', '.'),
        ('ui_left_list.json', '.'),
        ('ui_strings.json', '.'),
        ('tasks_config.json', '.'),
        ('appimage_custom.json', '.'),
        ('package_favorites.json', '.'),
        ('/usr/lib/qt6/qml/org/kde/kirigami', 'org/kde/kirigami')
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='Maintainer',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
