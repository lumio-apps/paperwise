import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

enum PageSizeOption {
  a4('A4'),
  letter('Letter'),
  fit('Fit image');

  const PageSizeOption(this.label);
  final String label;
}

enum OrientationOption {
  portrait('Portrait'),
  landscape('Landscape');

  const OrientationOption(this.label);
  final String label;
}

enum MarginOption {
  none('None', 0),
  small('Small', 12),
  large('Large', 24);

  const MarginOption(this.label, this.millimeters);
  final String label;
  final double millimeters;
}

class ImagePdfOptions {
  const ImagePdfOptions({
    this.pageSize = PageSizeOption.a4,
    this.orientation = OrientationOption.portrait,
    this.margin = MarginOption.small,
  });

  final PageSizeOption pageSize;
  final OrientationOption orientation;
  final MarginOption margin;

  ImagePdfOptions copyWith({
    PageSizeOption? pageSize,
    OrientationOption? orientation,
    MarginOption? margin,
  }) {
    return ImagePdfOptions(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      margin: margin ?? this.margin,
    );
  }
}

/// Builds one PDF page per image, in the given order.
///
/// Runs in a background isolate so the screen stays smooth.
Future<Uint8List> buildImagesPdf(List<Uint8List> images, ImagePdfOptions options) {
  return Isolate.run(() => _build(images, options));
}

Future<Uint8List> _build(List<Uint8List> images, ImagePdfOptions options) async {
  final doc = pw.Document(title: 'Images', creator: 'Paperwise', producer: 'Paperwise');
  final margin = options.margin.millimeters * pdf.PdfPageFormat.mm;

  for (final bytes in images) {
    final image = pw.MemoryImage(bytes);
    final pdf.PdfPageFormat format;
    if (options.pageSize == PageSizeOption.fit) {
      // Keep the photo's own shape on an A4-wide page.
      final width = (image.width ?? 1).toDouble();
      final height = (image.height ?? 1).toDouble();
      final pageWidth = pdf.PdfPageFormat.a4.width;
      final contentWidth = pageWidth - margin * 2;
      format = pdf.PdfPageFormat(pageWidth, contentWidth * height / width + margin * 2);
    } else {
      final base = options.pageSize == PageSizeOption.a4 ? pdf.PdfPageFormat.a4 : pdf.PdfPageFormat.letter;
      format = options.orientation == OrientationOption.landscape ? base.landscape : base.portrait;
    }

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.all(margin),
        build: (context) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
      ),
    );
  }

  return doc.save();
}
