import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';

import 'image_tools.dart';
import 'pdf_tools.dart';

/// How many pages are put on one sheet.
enum SheetLayout {
  two('2 per sheet', 2),
  four('4 per sheet', 4);

  const SheetLayout(this.label, this.perSheet);

  final String label;
  final int perSheet;
}

/// The grid for one sheet: columns, rows, and whether the sheet lies on its side.
class SheetGrid {
  const SheetGrid(this.columns, this.rows, this.landscape);

  final int columns;
  final int rows;
  final bool landscape;

  /// Picks the grid that wastes the least paper for pages shaped like the first
  /// page of the PDF. Tall pages sit side by side on a wide sheet.
  static SheetGrid of(SheetLayout layout, {required bool pagesAreLandscape}) {
    switch (layout) {
      case SheetLayout.two:
        return pagesAreLandscape ? const SheetGrid(1, 2, false) : const SheetGrid(2, 1, true);
      case SheetLayout.four:
        return SheetGrid(2, 2, pagesAreLandscape);
    }
  }
}

/// One redrawn page: a JPG picture and the page size in PDF points.
class _Cell {
  const _Cell(this.jpg, this.width, this.height);

  final Uint8List jpg;
  final double width;
  final double height;
}

// Space around the sheet and between pages, in PDF points.
const double _margin = 20;
const double _gap = 14;

/// Puts several pages on each A4 sheet, to save paper when printing.
///
/// Pages are redrawn as pictures, so text on the new sheets can no longer be
/// selected or searched.
class PdfNUp {
  PdfNUp._();

  // Resolution the pages are redrawn at. 150 is sharp enough to print.
  static const double _dpi = 150;

  static Future<Uint8List> build(
    PdfDocument document,
    SheetLayout layout, {
    required bool border,
    void Function(int done, int total)? onProgress,
  }) async {
    final count = document.pages.length;
    if (count == 0) throw const PdfToolException('This PDF has no pages.');
    final first = document.pages.first;
    final grid = SheetGrid.of(layout, pagesAreLandscape: first.width > first.height);
    final format = grid.landscape ? pdf.PdfPageFormat.a4.landscape : pdf.PdfPageFormat.a4;
    final cellWidth = (format.width - _margin * 2 - _gap * (grid.columns - 1)) / grid.columns;
    final cellHeight = (format.height - _margin * 2 - _gap * (grid.rows - 1)) / grid.rows;

    final cells = <_Cell>[];
    for (var i = 0; i < count; i++) {
      onProgress?.call(i, count);
      cells.add(await _render(document.pages[i], cellWidth, cellHeight));
    }
    onProgress?.call(count, count);

    final perSheet = layout.perSheet;
    final sheets = <List<_Cell>>[
      for (var start = 0; start < cells.length; start += perSheet)
        cells.sublist(start, math.min(start + perSheet, cells.length)),
    ];
    final columns = grid.columns;
    final rows = grid.rows;
    return Isolate.run(() => _assemble(sheets, format, columns, rows, cellWidth, cellHeight, border));
  }

  static Future<_Cell> _render(PdfPage page, double cellWidth, double cellHeight) async {
    // Draw the page just big enough to fill its place on the sheet.
    final fit = math.min(cellWidth / page.width, cellHeight / page.height);
    var width = page.width * fit * _dpi / 72.0;
    var height = page.height * fit * _dpi / 72.0;
    const maxPixels = 16e6;
    if (width * height > maxPixels) {
      final shrink = math.sqrt(maxPixels / (width * height));
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
      final jpg = await encodeBgraPixels(rendered.pixels, rendered.width, rendered.height, png: false, quality: 85);
      return _Cell(jpg, page.width, page.height);
    } finally {
      rendered.dispose();
    }
  }
}

Future<Uint8List> _assemble(
  List<List<_Cell>> sheets,
  pdf.PdfPageFormat format,
  int columns,
  int rows,
  double cellWidth,
  double cellHeight,
  bool border,
) async {
  final doc = pw.Document(title: 'Pages per sheet', creator: 'Paperwise', producer: 'Paperwise');
  for (final sheet in sheets) {
    final children = <pw.Widget>[];
    for (var i = 0; i < sheet.length; i++) {
      final cell = sheet[i];
      final column = i % columns;
      final row = i ~/ columns;
      final fit = math.min(cellWidth / cell.width, cellHeight / cell.height);
      final width = cell.width * fit;
      final height = cell.height * fit;
      final left = _margin + column * (cellWidth + _gap) + (cellWidth - width) / 2;
      final top = _margin + row * (cellHeight + _gap) + (cellHeight - height) / 2;
      final image = pw.MemoryImage(cell.jpg);
      children.add(
        pw.Positioned(
          left: left,
          top: top,
          child: pw.Container(
            width: width,
            height: height,
            decoration: border ? pw.BoxDecoration(border: pw.Border.all(color: pdf.PdfColors.grey500, width: 0.6)) : null,
            child: pw.Image(image, fit: pw.BoxFit.fill),
          ),
        ),
      );
    }
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(children: children),
      ),
    );
  }
  return doc.save();
}
