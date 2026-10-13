import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/viewer_page.dart';

/// Opens PDFs that other apps hand to Paperwise ("Open with Paperwise").
///
/// The Android side copies the PDF into the app's cache and gives us its path.
class ExternalOpen {
  ExternalOpen._();

  static const MethodChannel _channel = MethodChannel('com.lumioapps.paperwise/open');

  /// Starts listening. Call once, right after the app starts.
  static Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    if (!Platform.isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'pdfOpened') {
        final path = call.arguments;
        if (path is String) await _show(navigatorKey, path);
      }
    });

    try {
      final path = await _channel.invokeMethod<String>('getInitialPdf');
      if (path != null) await _show(navigatorKey, path);
    } on PlatformException {
      // The PDF could not be read; just start the app normally.
    } on MissingPluginException {
      // Not running on Android.
    }
  }

  static Future<void> _show(GlobalKey<NavigatorState> navigatorKey, String path) async {
    // On a cold start the navigator may not exist yet; wait for the first frame.
    var tries = 0;
    while (navigatorKey.currentState == null && tries < 20) {
      await WidgetsBinding.instance.endOfFrame;
      tries++;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    await navigator.push(MaterialPageRoute<void>(builder: (_) => ViewerPage(path: path)));
  }
}
