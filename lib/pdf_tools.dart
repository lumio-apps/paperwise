import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'page_ranges.dart';

/// Thrown when a PDF can't be used, with a message for the user.
class PdfToolException implements Exception {
  const PdfToolException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// PDF work done fully on the phone with PDFium (through pdfrx).
class PdfTools {
  PdfTools._();

  /// Opens [path] and turns PDFium errors into friendly messages.
  static Future<PdfDocument> _open(String path, String name) async {
    try {
      return await PdfDocument.openFile(path);
    } on PdfPasswordException {
      throw PdfToolException('"$name" is locked with a password. Unlocking PDFs is coming in a later update.');
    } catch (_) {
      throw PdfToolException('"$name" could not be opened. It may be damaged or not a real PDF.');
    }
  }

  /// Number of pages in the PDF at [path].
  static Future<int> pageCount(String path, String name) async {
    final doc = await _open(path, name);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  /// Joins the PDFs in [paths] (in this order) into one new PDF.
  static Future<Uint8List> merge(List<String> paths, List<String> names) async {
    final docs = <PdfDocument>[];
    try {
      for (var i = 0; i < paths.length; i++) {
        docs.add(await _open(paths[i], names[i]));
      }
      final out = await PdfDocument.createNew(sourceName: 'paperwise-merge');
      try {
        out.pages = [for (final doc in docs) ...doc.pages];
        return await out.encodePdf();
      } finally {
        await out.dispose();
      }
    } finally {
      for (final doc in docs) {
        await doc.dispose();
      }
    }
  }

  /// Cuts the PDF at [path] into one new PDF per range.
  ///
  /// [onPart] receives each finished part right away, so big PDFs don't need
  /// every part in memory at once.
  static Future<void> split(
    String path,
    String name,
    List<PageRange> ranges,
    Future<void> Function(int index, Uint8List bytes) onPart,
  ) async {
    final doc = await _open(path, name);
    try {
      final pages = doc.pages;
      for (var i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        if (range.start < 1 || range.end > pages.length) {
          throw PdfToolException('Pages ${range.start}-${range.end} are outside this PDF.');
        }
        final out = await PdfDocument.createNew(sourceName: 'paperwise-split-$i');
        try {
          out.pages = pages.sublist(range.start - 1, range.end);
          await onPart(i, await out.encodePdf());
        } finally {
          await out.dispose();
        }
      }
    } finally {
      await doc.dispose();
    }
  }
}
