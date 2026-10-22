import 'package:flutter/services.dart';

import 'app_settings.dart';

/// The "Save location": a folder on the phone, picked once in Settings, where
/// every new file made by Paperwise is also copied.
///
/// Android only lets an app write into a folder the user picked, so the
/// picking and copying are done by the Android side of the app.
class SaveFolder {
  SaveFolder._();

  static const MethodChannel _channel = MethodChannel('com.lumioapps.paperwise/folder');

  static bool get isSet => AppSettings.instance.saveFolderUri != null;

  /// Opens Android's folder picker. Returns true when a folder was chosen.
  static Future<bool> pick() async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('pickFolder');
      if (result == null) return false;
      final uri = result['uri'];
      if (uri is! String || uri.isEmpty) return false;
      final name = result['name'];
      AppSettings.instance.setSaveFolder(uri, name is String ? name : null);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Forgets the folder. New files stay only inside Paperwise.
  static void clear() => AppSettings.instance.setSaveFolder(null, null);

  /// Copies [path] into the chosen folder, if there is one. Never throws: a
  /// failed copy must not break the tool that just made the file.
  static Future<void> copyIfSet(String path, String name, String mime) async {
    final uri = AppSettings.instance.saveFolderUri;
    if (uri == null) return;
    try {
      await _channel.invokeMethod<bool>('copyToFolder', {
        'uri': uri,
        'path': path,
        'name': name,
        'mime': mime,
      });
    } catch (_) {
      // The folder may be gone or no longer allowed. The file is still safe inside Paperwise.
    }
  }
}
