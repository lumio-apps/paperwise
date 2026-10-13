import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'pages/viewer_page.dart';

/// Opens a PDF in the built-in Paperwise viewer.
Future<void> openPdf(BuildContext context, String path) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ViewerPage(path: path)),
  );
}

/// Opens the share sheet for one or more PDFs.
Future<void> sharePdfs(List<String> paths) async {
  await SharePlus.instance.share(
    ShareParams(files: [for (final path in paths) XFile(path, mimeType: 'application/pdf')]),
  );
}

/// Lets the user pick a folder on the phone (like Downloads) and saves a copy there.
Future<void> savePdfToDevice(BuildContext context, String path, String fileName) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await File(path).readAsBytes();
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/pdf',
      dialogTitle: 'Save PDF',
    );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text('Saved "$fileName" to your phone.')));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not save the file. Please try again.')));
  }
}
