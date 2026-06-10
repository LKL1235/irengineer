import 'dart:io';

/// Whether live iRacing SDK coaching is available on this desktop OS.
bool get supportsLiveCoaching => Platform.isWindows;
