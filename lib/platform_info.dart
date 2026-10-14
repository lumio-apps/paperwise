import 'dart:io';

/// Small helpers for the few places where Windows and Android differ.
class PlatformInfo {
  PlatformInfo._();

  static final bool isAndroid = Platform.isAndroid;
  static final bool isWindows = Platform.isWindows;

  /// Desktop builds have no camera, so camera buttons are hidden there.
  static final bool hasCamera = Platform.isAndroid || Platform.isIOS;

  static final bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}
