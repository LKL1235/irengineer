import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'services/coach_provider.dart';
import 'services/coach_provider_windows.dart';
import 'services/tray/tray_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1200, 800),
    center: true,
    title: 'iREngineer',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await windowManager.setPreventClose(true);

  final container = ProviderContainer(
    overrides: [
      coachLoopProvider.overrideWith(WindowsCoachLoopNotifier.new),
    ],
  );
  late final TrayController tray;
  tray = TrayController(
    onExit: () async {
      await container.read(coachLoopProvider.notifier).shutdown();
      await tray.dispose();
      await windowManager.destroy();
    },
  );
  final closeHandler = CloseToTrayHandler(tray);
  windowManager.addListener(closeHandler);
  await tray.init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const IracingCoachApp(),
    ),
  );
}
