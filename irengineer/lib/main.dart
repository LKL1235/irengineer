import 'dart:io';

import 'main_linux.dart' deferred as linux;
import 'main_windows.dart' deferred as windows;

Future<void> main() async {
  if (Platform.isWindows) {
    await windows.loadLibrary();
    return windows.main();
  }
  await linux.loadLibrary();
  return linux.main();
}
