import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../features/tray/tray_menu.dart';

/// System tray + minimize-to-tray lifecycle (R1).
class TrayController with TrayListener {
  TrayController({required this.onExit});

  final Future<void> Function() onExit;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    await trayManager.setIcon('assets/icons/tray.ico');
    await trayManager.setContextMenu(trayMenu());
    trayManager.addListener(this);
    _initialized = true;
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
  }

  Future<void> hideToTray() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
      case 'exit':
        onExit();
    }
  }
}

/// Hides window on close (X) instead of quitting.
class CloseToTrayHandler with WindowListener {
  CloseToTrayHandler(this.tray);

  final TrayController tray;

  @override
  void onWindowClose() async {
    await tray.hideToTray();
  }
}
