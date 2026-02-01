# 3D Slicer startup script - runs on application launch
# Configure dark theme and fullscreen

import slicer

# Disable WebEngine to prevent crashes in containerized environments
try:
    # Disable the embedded Chromium browser
    slicer.app.settings().setValue('WebEngine/Enabled', False)
    # Prevent automatic extension catalog loading which uses WebEngine
    slicer.app.settings().setValue('Extensions/ServerUrl', '')
except:
    pass

settings = slicer.app.userSettings()
settings.setValue('Styles/Style', 'Dark Slicer')
settings.sync()  # Force save to disk

# Also try to apply it directly to the application
import qt
# Get available styles
availableStyles = qt.QStyleFactory.keys()

# Try to set Dark Slicer style
if 'Dark Slicer' in availableStyles:
     slicer.app.setStyle('Dark Slicer')

# Apply dark palette programmatically as backup
darkPalette = qt.QPalette()
darkPalette.setColor(qt.QPalette.Window, qt.QColor(53, 53, 53))
darkPalette.setColor(qt.QPalette.WindowText, qt.Qt.white)
darkPalette.setColor(qt.QPalette.Base, qt.QColor(35, 35, 35))
darkPalette.setColor(qt.QPalette.AlternateBase, qt.QColor(53, 53, 53))
darkPalette.setColor(qt.QPalette.ToolTipBase, qt.QColor(25, 25, 25))
darkPalette.setColor(qt.QPalette.ToolTipText, qt.Qt.white)
darkPalette.setColor(qt.QPalette.Text, qt.Qt.white)
darkPalette.setColor(qt.QPalette.Button, qt.QColor(53, 53, 53))
darkPalette.setColor(qt.QPalette.ButtonText, qt.Qt.white)
darkPalette.setColor(qt.QPalette.BrightText, qt.Qt.red)
darkPalette.setColor(qt.QPalette.Link, qt.QColor(42, 130, 218))
darkPalette.setColor(qt.QPalette.Highlight, qt.QColor(42, 130, 218))
darkPalette.setColor(qt.QPalette.HighlightedText, qt.Qt.black)
slicer.app.setPalette(darkPalette)

import qt
mainWindow = slicer.util.mainWindow()
if mainWindow:
     # Maximize the window
     mainWindow.showMaximized()
     # Also try to set it fullscreen (can toggle with F11)
     mainWindow.showFullScreen()  # Uncomment for true fullscreen