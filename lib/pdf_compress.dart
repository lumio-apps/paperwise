import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import 'image_tools.dart';
import 'pdf_tools.dart';

/// How strongly a PDF is compressed.
enum CompressLevel {
  light('Light', 150, 85, 'Sharp pages, a modest size drop.'),
  balanced('Balanced', 110, 70, 'Good for reading and sharing by mail or chat.'),
  strong('Strong', 72, 50, 'Smallest file. Fine print gets softer.');

  const CompressLevel(this.label, this.dpi, this.quality, this.hint);

  final String label;

  /// Resolution the pages are redrawn at.
  final int dpi;

  /// JPG quality, 1 to 100.
  final int quality;
  final String hint;
}

/// One redrawn page: a JPG picture and the page size in PDF points.
class _PageImage {
  const _PageImage(this.jpg, this.width, this.height);

  final Uint8List jpg;
  final double width;
  final double height;
}

/// Makes PDFs smaller by redrawing each page as a JPG picture.
///
/// Because pages become pictures, text can no longer be selected or searched.
/// This works best for scans and photo PDFs.
class PdfCompressor {
  PdfCompressor._();

  // Keeps one page from using too much memory.
  static const double _maxPixels = 16e6;

  static Future<_PageImage> _renderPage(PdfPage page, CompressLevel level) async {
    final scale = level.dpi / 72.0;
    var width = page.width * scale;
    var height = page.height * scale;
    if (width * height > _maxPixels) {
      final shrink = math.sqrt(_maxPixels / (width * height));
      width *= shrink;
      height *= shrink;
    }
    final rendered = await page.render(
      width: math.max(1, width.round()),
      height: math.max(1, height.round()),
      fullWidth: width,
      fullHeight: height,
      backgroundColor: 0xFFFFFFFF,
    );
    if (rendered == null) throw const PdfToolException('A page could not be drawn.');
    try {
      final jpg = await encodeBgraPixels(
        rendered.pixels,
        rendered.width,
        rendered.height,
        png: false,
        quality: level.quality,
      );
      return _PageImage(jpg, page.width, page.height);
    } finally {
      rendered.dispose();
    }
  }

  /// Guesses the compressed size by redrawing up to three pages.
  static Future<int> estimate(PdfDocument document, CompressLevel level) async {
    final count = document.pages.length;
    if (count == 0) return 0;
    final sample = <int>{0, count ~/ 2, count - 1}.toList();
    var total = 0;
    for (final index in sample) {
      total += (await _renderPage(document.pages[index], level)).jpg.length;
    }
    final average = total / sample.length;
    return (average * count + 2048 + count * 120).round();
  }

  /// Builds the compressed PDF. [onProgress] gets the number of finished pages.
  static Future<Uint8List> compress(
    PdfDocument document,
    CompressLevel level, {
    void Function(int done, int total)? onProgress,
  }) async {
    final count = document.pages.length;
    if (count == 0) throw const PdfToolException('This PDF has no pages.');
    final pages = <_PageImage>[];
    for (var i = 0; i < count; i++) {
      onProgress?.call(i, count);
      pages.add(await _renderPage(document.pages[i], level));
    }
    onProgress?.call(count, count);
    return Isolate.run(() => _assemble(pages));
  }
}

Future<Uint8List> _assemble(List<_PageImage> pages) async {
  final doc = pw.Document(title: 'Compressed', creator: 'Paperwise', producer: 'Paperwise');
  for (final page in pages) {
    final image = pw.MemoryImage(page.jpg);
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat(page.width, page.height),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.FullPage(ignoreMargins: true, child: pw.Image(image, fit: pw.BoxFit.fill)),
      ),
    );
  }
  return doc.save();
}
