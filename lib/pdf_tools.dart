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

/// Thrown when a PDF needs a password that was not given.
class PdfLockedException extends PdfToolException {
  const PdfLockedException(super.message);
}

/// One page in a new arrangement: which page of the source PDF, and how many
/// quarter turns clockwise to add to its rotation.
class PageEdit {
  const PageEdit(this.source, {this.turns = 0});

  /// Index in the source PDF, starting at 0.
  final int source;

  /// Extra clockwise quarter turns, 0 to 3.
  final int turns;
}

/// PDF work done fully on the phone with PDFium (through pdfrx).
class PdfTools {
  PdfTools._();

  /// Opens [path] and turns PDFium errors into friendly messages.
  static Future<PdfDocument> _open(String path, String name) async {
    try {
      return await PdfDocument.openFile(path);
    } on PdfPasswordException {
      throw PdfLockedException('"$name" is locked with a password. Open Protect → Unlock first.');
    } catch (_) {
      throw PdfToolException('"$name" could not be opened. It may be damaged or not a real PDF.');
    }
  }

  /// Opens [path] for reading. The caller must call `dispose()` on the result.
  static Future<PdfDocument> openDocument(String path, String name) => _open(path, name);

  /// Opens a PDF that may be locked. [onPasswordNeeded] is called when the
  /// file turns out to be locked. A wrong password throws a friendly error.
  static Future<PdfDocument> openWithPassword(
    String path,
    String name,
    String password, {
    void Function()? onPasswordNeeded,
  }) async {
    var attempts = 0;
    try {
      return await PdfDocument.openFile(
        path,
        passwordProvider: () {
          onPasswordNeeded?.call();
          // Give the password once; null stops PDFium from asking again.
          return attempts++ == 0 ? password : null;
        },
      );
    } on PdfPasswordException {
      throw const PdfToolException('That password is not right.');
    } catch (_) {
      throw PdfToolException('"$name" could not be opened. It may be damaged or not a real PDF.');
    }
  }

  /// Builds a new PDF from pages of [source], in the order of [edits], with
  /// their extra rotation. [source] stays open and unchanged.
  static Future<Uint8List> arrange(PdfDocument source, List<PageEdit> edits) async {
    if (edits.isEmpty) throw const PdfToolException('Choose at least one page.');
    final pages = source.pages;
    final out = await PdfDocument.createNew(sourceName: 'paperwise-pages');
    try {
      out.pages = [
        for (final edit in edits)
          pages[edit.source].rotatedBy(PdfPageRotation.values[edit.turns & 3]),
      ];
      return await out.encodePdf();
    } finally {
      await out.dispose();
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
