import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'pdf_stamper.dart';
import 'pdf_tools.dart';

/// Writes text and drawings onto PDFs, keeping the original text selectable.
class PdfEditor {
  PdfEditor._();

  /// Returns a copy of [document] with [plan] written on it.
  static Future<Uint8List> apply(PdfDocument document, StampPlan plan) async {
    const failed = PdfToolException('This PDF could not be edited. Nothing was saved.');
    final pageCount = document.pages.length;
    if (pageCount == 0) throw const PdfToolException('This PDF has no pages.');

    // PDFium saves a clean copy first, which has the simple layout the writer needs.
    final clean = await PdfTools.arrange(document, [for (var i = 0; i < pageCount; i++) PageEdit(i)]);

    final Uint8List result;
    try {
      result = await Isolate.run(() => PdfStamper.apply(clean, plan));
    } catch (_) {
      throw failed;
    }

    // Make sure the new file really opens and has all its pages.
    try {
      final check = await PdfDocument.openData(result);
      final ok = check.pages.length == pageCount;
      await check.dispose();
      if (!ok) throw failed;
    } on PdfToolException {
      rethrow;
    } catch (_) {
      throw failed;
    }
    return result;
  }
}
