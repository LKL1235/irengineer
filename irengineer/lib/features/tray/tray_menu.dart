import 'package:tray_manager/tray_manager.dart';

Menu trayMenu() => Menu(
      items: [
        MenuItem(key: 'show', label: '显示窗口'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出'),
      ],
    );
