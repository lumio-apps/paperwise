/// The built-in PDF fonts Paperwise can write with. Every PDF reader has them,
/// so nothing needs to be stored inside the file.
///
/// Only plain keyboard characters (letters, numbers and common symbols) are
/// supported for now.
enum PdfFont {
  sans('Sans', 'Helvetica', false, _helvetica),
  sansBold('Sans bold', 'Helvetica-Bold', true, _helveticaBold),
  serif('Serif', 'Times-Roman', false, _times),
  serifBold('Serif bold', 'Times-Bold', true, _timesBold),
  mono('Mono', 'Courier', false, null),
  monoBold('Mono bold', 'Courier-Bold', true, null);

  const PdfFont(this.label, this.baseFont, this.bold, this._widths);

  final String label;

  /// The PDF name of the font.
  final String baseFont;
  final bool bold;
  final List<int>? _widths;

  /// The same font family in regular or bold.
  PdfFont withBold(bool value) {
    if (value == bold) return this;
    switch (this) {
      case PdfFont.sans:
      case PdfFont.sansBold:
        return value ? PdfFont.sansBold : PdfFont.sans;
      case PdfFont.serif:
      case PdfFont.serifBold:
        return value ? PdfFont.serifBold : PdfFont.serif;
      case PdfFont.mono:
      case PdfFont.monoBold:
        return value ? PdfFont.monoBold : PdfFont.mono;
    }
  }

  /// Width of [text] in PDF points at [size].
  double width(String text, double size) {
    final widths = _widths;
    var total = 0;
    for (final unit in text.codeUnits) {
      if (widths == null) {
        total += 600;
      } else if (unit >= 32 && unit <= 126) {
        total += widths[unit - 32];
      } else {
        total += 556;
      }
    }
    return total * size / 1000;
  }

  /// True when every character of [text] can be written.
  static bool canWrite(String text) => text.codeUnits.every((u) => u >= 32 && u <= 126);
}

const List<int> _helvetica = [
  278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, //
  556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, //
  722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500, 556, //
  556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, //
  260, 334, 584,
];

const List<int> _helveticaBold = [
  278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, //
  556, 556, 556, 333, 333, 584, 584, 584, 611, 975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, //
  722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556, 333, 556, 611, 556, 611, //
  556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, //
  280, 389, 584,
];

const List<int> _times = [
  250, 333, 408, 500, 500, 833, 778, 180, 333, 333, 500, 564, 250, 333, 250, 278, 500, 500, 500, 500, 500, 500, 500, //
  500, 500, 500, 278, 278, 564, 564, 564, 444, 921, 722, 667, 667, 722, 611, 556, 722, 722, 333, 389, 722, 611, 889, //
  722, 722, 556, 722, 667, 556, 611, 722, 722, 944, 722, 722, 611, 333, 278, 333, 469, 500, 333, 444, 500, 444, 500, //
  444, 333, 500, 500, 278, 278, 500, 278, 778, 500, 500, 500, 500, 333, 389, 278, 500, 500, 722, 500, 500, 444, 480, //
  200, 480, 541,
];

const List<int> _timesBold = [
  250, 333, 555, 500, 500, 1000, 833, 278, 333, 333, 500, 570, 250, 333, 250, 278, 500, 500, 500, 500, 500, 500, 500, //
  500, 500, 500, 333, 333, 570, 570, 570, 500, 930, 722, 667, 722, 722, 667, 611, 778, 778, 389, 500, 778, 667, 944, //
  722, 778, 611, 778, 722, 556, 667, 722, 722, 1000, 722, 722, 667, 333, 278, 333, 581, 500, 333, 500, 556, 444, 556, //
  444, 333, 500, 556, 278, 333, 556, 278, 833, 556, 500, 556, 556, 444, 389, 333, 556, 500, 722, 500, 500, 444, 394, //
  220, 394, 520,
];
