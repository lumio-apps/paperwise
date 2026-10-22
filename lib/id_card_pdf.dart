import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

/// Sizes the card can be printed at.
enum CardSize {
  actual('Actual size', 85.6, 54.0),
  large('Large', 150.0, 94.6);

  const CardSize(this.label, this.widthMm, this.heightMm);

  final String label;
  final double widthMm;
  final double heightMm;
}

/// Puts the front, and optionally the back, of an ID card on one A4 page, one
/// above the other. Each picture keeps its own shape and sits in the middle of
/// a card-sized place.
///
/// Runs in a background isolate so the screen stays smooth.
Future<Uint8List> buildIdCardPdf({
  required Uint8List front,
  Uint8List? back,
  required CardSize size,
  required bool border,
}) {
  return Isolate.run(() => _build(front, back, size, border));
}

Future<Uint8List> _build(Uint8List front, Uint8List? back, CardSize size, bool border) async {
  const mm = pdf.PdfPageFormat.mm;
  final page = pdf.PdfPageFormat.a4;
  final slotWidth = size.widthMm * mm;
  final slotHeight = size.heightMm * mm;
  final left = (page.width - slotWidth) / 2;
  final firstTop = 28 * mm;
  final secondTop = firstTop + slotHeight + 14 * mm;

  pw.Widget place(Uint8List bytes, double top) {
    final image = pw.MemoryImage(bytes);
    final width = (image.width ?? 1).toDouble();
    final height = (image.height ?? 1).toDouble();
    final fit = math.min(slotWidth / width, slotHeight / height);
    final drawWidth = width * fit;
    final drawHeight = height * fit;
    return pw.Positioned(
      left: left + (slotWidth - drawWidth) / 2,
      top: top + (slotHeight - drawHeight) / 2,
      child: pw.Container(
        width: drawWidth,
        height: drawHeight,
        decoration: border ? pw.BoxDecoration(border: pw.Border.all(color: pdf.PdfColors.grey600, width: 0.6)) : null,
        child: pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
  }

  final doc = pw.Document(title: 'ID card', creator: 'Paperwise', producer: 'Paperwise');
  doc.addPage(
    pw.Page(
      pageFormat: page,
      margin: pw.EdgeInsets.zero,
      build: (context) => pw.Stack(
        children: [
          place(front, firstTop),
          if (back != null) place(back, secondTop),
        ],
      ),
    ),
  );
  return doc.save();
}
