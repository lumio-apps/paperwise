import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'office/office_file.dart';
import 'pages/doc_viewer_page.dart';
import 'pages/image_to_pdf_page.dart';
import 'pages/merge_page.dart';
import 'pages/sheet_viewer_page.dart';
import 'pages/viewer_page.dart';

/// Opens files that other apps hand to Paperwise: "Open with Paperwise" for a
/// PDF, sheet or Word file, and the Share menu for those and pictures.
///
/// The Android side copies each file into the app's cache and gives us its path.
class ExternalOpen {
  ExternalOpen._();

  static const MethodChannel _channel = MethodChannel('com.lumioapps.paperwise/open');

  static const _imageEnds = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];

  /// Starts listening. Call once, right after the app starts.
  static Future<void> start(GlobalKey<NavigatorState> navigatorKey) async {
    if (!Platform.isAndroid) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'filesOpened') {
        final paths = _asPaths(call.arguments);
        if (paths.isNotEmpty) await _show(navigatorKey, paths);
      }
    });

    try {
      final paths = _asPaths(await _channel.invokeMethod<Object>('getInitialFiles'));
      if (paths.isNotEmpty) await _show(navigatorKey, paths);
    } on PlatformException {
      // The files could not be read; just start the app normally.
    } on MissingPluginException {
      // Not running on Android.
    }
  }

  static List<String> _asPaths(Object? value) {
    if (value is! List) return const [];
    return [for (final item in value) if (item is String) item];
  }

  static bool _isImage(String path) {
    final lower = path.toLowerCase();
    return _imageEnds.any(lower.endsWith);
  }

  static Future<void> _show(GlobalKey<NavigatorState> navigatorKey, List<String> paths) async {
    // On a cold start the navigator may not exist yet; wait for the first frame.
    var tries = 0;
    while (navigatorKey.currentState == null && tries < 20) {
      await WidgetsBinding.instance.endOfFrame;
      tries++;
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Excel, CSV and Word files open in their viewer, one at a time.
    final rest = paths.where((p) => !isSheetFile(p) && !isDocumentFile(p)).toList();
    if (rest.isEmpty) {
      final first = paths.first;
      final Widget viewer = isSheetFile(first) ? SheetViewerPage(path: first) : DocViewerPage(path: first);
      await navigator.push(MaterialPageRoute<void>(builder: (_) => viewer));
      return;
    }

    final images = rest.where(_isImage).toList();
    final pdfs = rest.where((p) => !_isImage(p)).toList();

    // Pictures become a PDF. A single PDF opens in the reader, and several
    // PDFs go to Merge so they can be joined in the order you like.
    final Widget page;
    if (images.isNotEmpty) {
      page = ImageToPdfPage(initialPaths: images);
    } else if (pdfs.length == 1) {
      page = ViewerPage(path: pdfs.first);
    } else {
      page = MergePage(initialPaths: pdfs);
    }
    await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
