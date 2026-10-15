import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'image_tools.dart';
import 'pdf_editor.dart';
import 'pdf_stamper.dart';
import 'pdf_tools.dart';

/// What reading a PDF found.
class OcrOutcome {
  const OcrOutcome({required this.pageTexts, required this.stamps, required this.pagesRead, required this.pagesSkipped});

  /// The text of every page, in order. Empty when a page has none.
  final List<String> pageTexts;

  /// Invisible words to write on each page (page index starts at 0).
  final Map<int, List<Stamp>> stamps;

  /// Pages that were read with text recognition.
  final int pagesRead;

  /// Pages left alone because they already contain text.
  final int pagesSkipped;

  /// All the text, with a blank line between pages.
  String get fullText => pageTexts.where((t) => t.trim().isNotEmpty).join('\n\n');

  bool get foundText => fullText.trim().isNotEmpty;
}

/// Reads text from scanned pages on the phone (no internet), and can write it
/// invisibly behind the scan so the PDF becomes searchable.
///
/// Text recognition is done by the ML Kit model that is bundled in the app.
/// For now it reads English (Latin letters).
class PdfOcr {
  PdfOcr._();

  static const int _dpi = 200;
  static const double _maxSide = 3000;

  /// A page with at least this many letters already has real text.
  static const int _hasTextLimit = 20;

  /// Reads every page. With [skipTextPages], pages that already contain text
  /// are not read again, and their own text is used instead.
  static Future<OcrOutcome> read(
    PdfDocument document, {
    bool skipTextPages = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final count = document.pages.length;
    if (count == 0) throw const PdfToolException('This PDF has no pages.');

    final temp = await getTemporaryDirectory();
    final imageFile = File('${temp.path}/paperwise_ocr_page.jpg');
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final texts = <String>[];
    final stamps = <int, List<Stamp>>{};
    var read = 0;
    var skipped = 0;
    try {
      for (var i = 0; i < count; i++) {
        onProgress?.call(i, count);
        final page = document.pages[i];

        String existing = '';
        if (skipTextPages) {
          try {
            existing = _textOf(await page.loadText());
          } catch (_) {
            existing = '';
          }
        }
        if (existing.length >= _hasTextLimit) {
          texts.add(existing);
          skipped++;
          continue;
        }

        final scale = math.min(_dpi / 72.0, _maxSide / math.max(page.width, page.height));
        final width = math.max(1.0, page.width * scale);
        final height = math.max(1.0, page.height * scale);
        final rendered = await page.render(
          width: width.round(),
          height: height.round(),
          fullWidth: width,
          fullHeight: height,
          backgroundColor: 0xFFFFFFFF,
        );
        if (rendered == null) throw const PdfToolException('A page could not be drawn.');
        final int imageWidth = rendered.width;
        final int imageHeight = rendered.height;
        final Uint8List jpg;
        try {
          jpg = await encodeBgraPixels(rendered.pixels, imageWidth, imageHeight, png: false, quality: 92);
        } finally {
          rendered.dispose();
        }
        await imageFile.writeAsBytes(jpg, flush: true);

        final result = await recognizer.processImage(InputImage.fromFilePath(imageFile.path));
        read++;
        texts.add(result.text.trim());

        final words = <Stamp>[];
        for (final block in result.blocks) {
          for (final line in block.lines) {
            for (final element in line.elements) {
              final box = element.boundingBox;
              if (element.text.trim().isEmpty) continue;
              words.add(
                HiddenWordStamp(
                  left: (box.left / imageWidth).clamp(0.0, 1.0),
                  top: (box.top / imageHeight).clamp(0.0, 1.0),
                  right: (box.right / imageWidth).clamp(0.0, 1.0),
                  bottom: (box.bottom / imageHeight).clamp(0.0, 1.0),
                  text: element.text,
                ),
              );
            }
          }
        }
        if (words.isNotEmpty) stamps[i] = words;
      }
      onProgress?.call(count, count);
    } finally {
      await recognizer.close();
      if (await imageFile.exists()) await imageFile.delete();
    }
    return OcrOutcome(pageTexts: texts, stamps: stamps, pagesRead: read, pagesSkipped: skipped);
  }

  /// The plain text of a loaded page. Written to work with the text object of
  /// both older and newer pdfrx versions.
  static String _textOf(Object? pageText) {
    if (pageText == null) return '';
    final dynamic value = pageText;
    try {
      return ((value.fullText as String?) ?? '').trim();
    } catch (_) {
      // Newer versions call it "text".
    }
    try {
      return ((value.text as String?) ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Writes the words found by [read] invisibly onto the pages and returns the
  /// new PDF. The scan itself is not changed.
  static Future<Uint8List> makeSearchable(PdfDocument document, OcrOutcome outcome) {
    if (outcome.stamps.isEmpty) {
      throw const PdfToolException('No text was found on these pages, so nothing was saved.');
    }
    return PdfEditor.apply(document, StampPlan(byPage: outcome.stamps));
  }
}
