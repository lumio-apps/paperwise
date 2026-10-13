import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

/// Opens a PDF in a viewer app that is already on the phone.
Future<void> openPdf(BuildContext context, String path) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await OpenFilex.open(path, type: 'application/pdf');
  if (result.type == ResultType.done) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        result.type == ResultType.noAppToOpen
            ? 'No PDF viewer found on this phone. A built-in viewer is coming in the next update.'
            : 'Could not open the file.',
      ),
    ),
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
