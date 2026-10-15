import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'pdf_fonts.dart';

/// A colour for text and drawings, each part from 0 to 1.
class StampColor {
  const StampColor(this.red, this.green, this.blue);

  final double red;
  final double green;
  final double blue;

  static const black = StampColor(0, 0, 0);
  static const blue1 = StampColor(0.08, 0.2, 0.75);
  static const red1 = StampColor(0.8, 0.1, 0.1);
  static const gray = StampColor(0.35, 0.35, 0.35);
}

/// Something to write on a page. Positions are fractions of the page as it
/// looks on screen: 0,0 is the top-left corner and 1,1 the bottom-right.
sealed class Stamp {
  const Stamp();
}

/// A line of text. [left] and [top] are the top-left corner of the text.
class TextStamp extends Stamp {
  const TextStamp({
    required this.left,
    required this.top,
    required this.text,
    required this.font,
    required this.size,
    required this.color,
  });

  final double left;
  final double top;
  final String text;
  final PdfFont font;

  /// Size in PDF points.
  final double size;
  final StampColor color;
}

/// Pen strokes, for example a signature. Each stroke is a flat list of
/// x,y,x,y... fractions of the page.
class InkStamp extends Stamp {
  const InkStamp({required this.strokes, required this.width, required this.color});

  final List<List<double>> strokes;

  /// Pen width in PDF points.
  final double width;
  final StampColor color;
}

/// A rectangle. With [filled] and an [opacity] below 1 it works like a
/// highlighter pen: the text underneath stays readable.
class RectStamp extends Stamp {
  const RectStamp({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.color,
    this.filled = false,
    this.opacity = 1,
    this.width = 2,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final StampColor color;
  final bool filled;
  final double opacity;

  /// Outline width in PDF points.
  final double width;
}

/// An ellipse that fits inside the box given by the four fractions.
class EllipseStamp extends Stamp {
  const EllipseStamp({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.color,
    this.width = 2,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final StampColor color;
  final double width;
}

/// A straight line, optionally with an arrow head at the end.
class LineStamp extends Stamp {
  const LineStamp({
    required this.fromLeft,
    required this.fromTop,
    required this.toLeft,
    required this.toTop,
    required this.color,
    this.width = 2,
    this.arrow = false,
  });

  final double fromLeft;
  final double fromTop;
  final double toLeft;
  final double toTop;
  final StampColor color;
  final double width;
  final bool arrow;
}

enum HAnchor { left, center, right }

/// Text placed at the same spot on many pages, like a page number.
/// "{n}" is the page number and "{total}" the number of pages.
class EveryPageText {
  const EveryPageText({
    required this.template,
    required this.horizontal,
    required this.atTop,
    required this.font,
    required this.size,
    required this.color,
    this.fromPage = 1,
    this.margin = 28,
  });

  final String template;
  final HAnchor horizontal;
  final bool atTop;
  final PdfFont font;
  final double size;
  final StampColor color;

  /// First page that gets the text (the first page of a PDF is 1).
  final int fromPage;

  /// Distance from the page edge in points.
  final double margin;
}

/// Everything to write into one PDF.
class StampPlan {
  const StampPlan({this.byPage = const {}, this.everyPage = const []});

  /// Stamps by page index, starting at 0.
  final Map<int, List<Stamp>> byPage;
  final List<EveryPageText> everyPage;
}

class _Ref {
  const _Ref(this.number);
  final int number;
}

class _Raw {
  const _Raw(this.text);
  final String text;
}

/// Writes text and drawings on top of the pages of a PDF without changing
/// anything else, so the text already in the PDF stays selectable.
///
/// It works on PDFs saved by PDFium (the kind Paperwise makes with its page
/// tools), which keep a simple, classic file layout. It adds the new content
/// at the end of the file as an incremental update.
class PdfStamper {
  PdfStamper._();

  /// Returns a copy of [data] with [plan] written on its pages.
  /// Throws a [FormatException] when the file layout is not supported.
  static Uint8List apply(Uint8List data, StampPlan plan) {
    final doc = _Doc(data);
    final pages = doc.pages();
    final total = pages.length;

    var nextNumber = doc.size;
    int allocate() => nextNumber++;

    final added = <int, List<int>>{};
    final fontObjects = <PdfFont, int>{};

    int fontObject(PdfFont font) {
      return fontObjects.putIfAbsent(font, () {
        final number = allocate();
        added[number] = latin1.encode(
          '<</Type/Font/Subtype/Type1/BaseFont/${font.baseFont}/Encoding/WinAnsiEncoding>>',
        );
        return number;
      });
    }

    for (var i = 0; i < total; i++) {
      final page = pages[i];
      final geometry = _Geometry.of(doc, page);
      final width = geometry.displayWidth;
      final height = geometry.displayHeight;

      final stamps = <Stamp>[...(plan.byPage[i] ?? const <Stamp>[])];
      for (final every in plan.everyPage) {
        if (i + 1 < every.fromPage) continue;
        final text = every.template.replaceAll('{n}', '${i + 1}').replaceAll('{total}', '$total');
        if (text.isEmpty) continue;
        final textWidth = every.font.width(text, every.size);
        final double x;
        switch (every.horizontal) {
          case HAnchor.left:
            x = every.margin;
          case HAnchor.center:
            x = (width - textWidth) / 2;
          case HAnchor.right:
            x = width - every.margin - textWidth;
        }
        final y = every.atTop ? every.margin : height - every.margin - every.size;
        stamps.add(
          TextStamp(
            left: x / width,
            top: y / height,
            text: text,
            font: every.font,
            size: every.size,
            color: every.color,
          ),
        );
      }
      if (stamps.isEmpty) continue;

      // Resources: keep what the page has and add our fonts under new names.
      final resourcesValue = doc.resolve(page.node['Resources'] ?? page.inherited['Resources'] ?? <String, Object>{});
      final resources = resourcesValue is Map ? Map<String, Object>.from(resourcesValue) : <String, Object>{};
      final fontsValue = doc.resolve(resources['Font'] ?? <String, Object>{});
      final fonts = fontsValue is Map ? Map<String, Object>.from(fontsValue) : <String, Object>{};
      resources['Font'] = fonts;

      final gsValue = doc.resolve(resources['ExtGState'] ?? <String, Object>{});
      final graphicsStates = gsValue is Map ? Map<String, Object>.from(gsValue) : <String, Object>{};
      final gsNames = <double, String>{};
      String opacityName(double opacity) {
        return gsNames.putIfAbsent(opacity, () {
          var k = 0;
          while (graphicsStates.containsKey('PwG$k')) {
            k++;
          }
          final name = 'PwG$k';
          final value = _Raw(_n(opacity));
          graphicsStates[name] = <String, Object>{'ca': value, 'CA': value, 'BM': const _Raw('/Multiply')};
          return name;
        });
      }

      final ops = <String>[];
      final fontNames = <PdfFont, String>{};
      String fontName(PdfFont font) {
        return fontNames.putIfAbsent(font, () {
          var k = 0;
          while (fonts.containsKey('PwF$k')) {
            k++;
          }
          final name = 'PwF$k';
          fonts[name] = _Ref(fontObject(font));
          return name;
        });
      }

      for (final stamp in stamps) {
        switch (stamp) {
          case TextStamp():
            if (stamp.text.isEmpty) continue;
            final name = fontName(stamp.font);
            // The text is placed by its baseline, a little below the top of the line.
            final origin = geometry.point(stamp.left, stamp.top + 0.8 * stamp.size / height);
            final right = geometry.vector(1, 0);
            final up = geometry.vector(0, -1);
            final c = stamp.color;
            ops.add(
              'BT /$name ${_n(stamp.size)} Tf ${_n(c.red)} ${_n(c.green)} ${_n(c.blue)} rg '
              '${_n(right.$1)} ${_n(right.$2)} ${_n(up.$1)} ${_n(up.$2)} ${_n(origin.$1)} ${_n(origin.$2)} Tm '
              '(${_escape(stamp.text)}) Tj ET',
            );
          case InkStamp():
            final c = stamp.color;
            ops.add('${_n(c.red)} ${_n(c.green)} ${_n(c.blue)} RG ${_n(stamp.width)} w 1 J 1 j');
            for (final stroke in stamp.strokes) {
              if (stroke.length < 2) continue;
              final points = <(double, double)>[
                for (var k = 0; k + 1 < stroke.length; k += 2) geometry.point(stroke[k], stroke[k + 1]),
              ];
              if (points.length == 1) points.add((points[0].$1 + 0.01, points[0].$2));
              final line = StringBuffer('${_n(points[0].$1)} ${_n(points[0].$2)} m');
              for (var k = 1; k < points.length; k++) {
                line.write(' ${_n(points[k].$1)} ${_n(points[k].$2)} l');
              }
              line.write(' S');
              ops.add(line.toString());
            }
          case RectStamp():
            final a = geometry.point(stamp.left, stamp.top);
            final b = geometry.point(stamp.right, stamp.top);
            final c = geometry.point(stamp.right, stamp.bottom);
            final d = geometry.point(stamp.left, stamp.bottom);
            final path = '${_n(a.$1)} ${_n(a.$2)} m ${_n(b.$1)} ${_n(b.$2)} l '
                '${_n(c.$1)} ${_n(c.$2)} l ${_n(d.$1)} ${_n(d.$2)} l h';
            final col = stamp.color;
            final paint = stamp.filled
                ? '${_n(col.red)} ${_n(col.green)} ${_n(col.blue)} rg $path f'
                : '${_n(col.red)} ${_n(col.green)} ${_n(col.blue)} RG ${_n(stamp.width)} w 1 j $path S';
            ops.add(stamp.opacity < 1 ? 'q /${opacityName(stamp.opacity)} gs $paint Q' : paint);
          case EllipseStamp():
            const k = 0.5523;
            final cx = (stamp.left + stamp.right) / 2;
            final cy = (stamp.top + stamp.bottom) / 2;
            final rx = (stamp.right - stamp.left).abs() / 2;
            final ry = (stamp.bottom - stamp.top).abs() / 2;
            String p(double u, double v) {
              final point = geometry.point(u, v);
              return '${_n(point.$1)} ${_n(point.$2)}';
            }

            final col = stamp.color;
            ops.add(
              '${_n(col.red)} ${_n(col.green)} ${_n(col.blue)} RG ${_n(stamp.width)} w '
              '${p(cx + rx, cy)} m '
              '${p(cx + rx, cy + k * ry)} ${p(cx + k * rx, cy + ry)} ${p(cx, cy + ry)} c '
              '${p(cx - k * rx, cy + ry)} ${p(cx - rx, cy + k * ry)} ${p(cx - rx, cy)} c '
              '${p(cx - rx, cy - k * ry)} ${p(cx - k * rx, cy - ry)} ${p(cx, cy - ry)} c '
              '${p(cx + k * rx, cy - ry)} ${p(cx + rx, cy - k * ry)} ${p(cx + rx, cy)} c h S',
            );
          case LineStamp():
            final col = stamp.color;
            final from = geometry.point(stamp.fromLeft, stamp.fromTop);
            final to = geometry.point(stamp.toLeft, stamp.toTop);
            final line = StringBuffer(
              '${_n(col.red)} ${_n(col.green)} ${_n(col.blue)} RG ${_n(stamp.width)} w 1 J 1 j '
              '${_n(from.$1)} ${_n(from.$2)} m ${_n(to.$1)} ${_n(to.$2)} l S',
            );
            if (stamp.arrow) {
              // The arrow head is worked out in points on the page as shown.
              final dx = (stamp.toLeft - stamp.fromLeft) * width;
              final dy = (stamp.toTop - stamp.fromTop) * height;
              final length = math.sqrt(dx * dx + dy * dy);
              if (length > 1) {
                final angle = math.atan2(dy, dx);
                final head = math.max(8.0, stamp.width * 5);
                (double, double) tip(double turn) {
                  final u = stamp.toLeft - head * math.cos(angle + turn) / width;
                  final v = stamp.toTop - head * math.sin(angle + turn) / height;
                  return geometry.point(u, v);
                }

                final left = tip(0.45);
                final right = tip(-0.45);
                line.write(
                  ' ${_n(left.$1)} ${_n(left.$2)} m ${_n(to.$1)} ${_n(to.$2)} l ${_n(right.$1)} ${_n(right.$2)} l S',
                );
              }
            }
            ops.add(line.toString());
        }
      }
      if (ops.isEmpty) continue;

      if (gsNames.isNotEmpty) resources['ExtGState'] = graphicsStates;

      // Contents: a "q" before the old content and our drawing after it.
      final before = allocate();
      final after = allocate();
      added[before] = latin1.encode('<</Length 1>>\nstream\nq\nendstream');
      final body = latin1.encode('Q\nq\n${ops.join('\n')}\nQ');
      added[after] = [...latin1.encode('<</Length ${body.length}>>\nstream\n'), ...body, ...latin1.encode('\nendstream')];

      final oldContents = page.node['Contents'];
      var existing = <Object>[];
      if (oldContents is _Ref) {
        final target = doc.object(oldContents.number);
        existing = target is List ? List<Object>.from(target) : <Object>[oldContents];
      } else if (oldContents is List) {
        existing = List<Object>.from(oldContents);
      }

      final node = Map<String, Object>.from(page.node);
      for (final key in const ['MediaBox', 'CropBox', 'Rotate']) {
        final inherited = page.inherited[key];
        if (!node.containsKey(key) && inherited != null) node[key] = inherited;
      }
      node['Resources'] = resources;
      node['Contents'] = <Object>[_Ref(before), ...existing, _Ref(after)];
      added[page.number] = latin1.encode(_serialize(node));
    }

    if (added.isEmpty) return data;

    final out = BytesBuilder();
    out.add(data);
    if (data.isEmpty || data.last != 0x0A) out.addByte(0x0A);
    final offsets = <int, int>{};
    final numbers = added.keys.toList()..sort();
    for (final number in numbers) {
      offsets[number] = out.length;
      out.add(latin1.encode('$number 0 obj\n'));
      out.add(added[number]!);
      out.add(latin1.encode('\nendobj\n'));
    }

    final xrefOffset = out.length;
    final xref = StringBuffer('xref\n');
    var k = 0;
    while (k < numbers.length) {
      var j = k;
      while (j + 1 < numbers.length && numbers[j + 1] == numbers[j] + 1) {
        j++;
      }
      xref.write('${numbers[k]} ${j - k + 1}\n');
      for (var m = k; m <= j; m++) {
        xref.write('${offsets[numbers[m]]!.toString().padLeft(10, '0')} 00000 n \n');
      }
      k = j + 1;
    }
    final trailer = <String, Object>{
      'Size': _Raw('$nextNumber'),
      'Root': doc.trailer['Root']!,
      'Prev': _Raw('${doc.xrefOffset}'),
    };
    for (final key in const ['Info', 'ID']) {
      final value = doc.trailer[key];
      if (value != null) trailer[key] = value;
    }
    xref.write('trailer\n${_serialize(trailer)}\nstartxref\n$xrefOffset\n%%EOF\n');
    out.add(latin1.encode(xref.toString()));
    return out.toBytes();
  }

  static String _n(double x) {
    var s = x.toStringAsFixed(3);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return (s.isEmpty || s == '-0') ? '0' : s;
  }

  static String _escape(String text) {
    return text.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  }

  static String _serialize(Object value) {
    if (value is _Ref) return '${value.number} 0 R';
    if (value is _Raw) return value.text;
    if (value is Map) {
      final out = StringBuffer('<<');
      value.forEach((key, item) => out.write('/$key ${_serialize(item as Object)} '));
      out.write('>>');
      return out.toString();
    }
    if (value is List) return '[${value.map((item) => _serialize(item as Object)).join(' ')}]';
    throw const FormatException('Unsupported value');
  }
}

/// One page of the PDF with the values it inherits from its parents.
class _Page {
  _Page(this.number, this.node, this.inherited);

  final int number;
  final Map<String, Object> node;
  final Map<String, Object> inherited;
}

/// Page size, turn and corner, and the maths between the page as shown on
/// screen and the page as stored in the file.
class _Geometry {
  _Geometry(this.x0, this.y0, this.boxWidth, this.boxHeight, this.rotation);

  final double x0;
  final double y0;
  final double boxWidth;
  final double boxHeight;
  final int rotation;

  double get displayWidth => (rotation == 0 || rotation == 180) ? boxWidth : boxHeight;
  double get displayHeight => (rotation == 0 || rotation == 180) ? boxHeight : boxWidth;

  static _Geometry of(_Doc doc, _Page page) {
    Object? find(String key) {
      final value = page.node[key] ?? page.inherited[key];
      return value == null ? null : doc.resolve(value);
    }

    final box = find('CropBox') ?? find('MediaBox');
    if (box is! List || box.length < 4) throw const FormatException('Page has no size');
    final values = [for (final item in box.take(4)) double.parse((doc.resolve(item as Object) as _Raw).text)];
    final left = values[0] < values[2] ? values[0] : values[2];
    final right = values[0] < values[2] ? values[2] : values[0];
    final bottom = values[1] < values[3] ? values[1] : values[3];
    final top = values[1] < values[3] ? values[3] : values[1];

    var rotation = 0;
    final turn = find('Rotate');
    if (turn is _Raw) rotation = (double.tryParse(turn.text)?.round() ?? 0) % 360;
    if (rotation < 0) rotation += 360;
    rotation = rotation ~/ 90 * 90 % 360;
    return _Geometry(left, bottom, right - left, top - bottom, rotation);
  }

  /// Turns a position on the page as shown on screen (fractions) into a
  /// position in the file's own coordinates.
  (double, double) point(double u, double v) {
    final dx = u * displayWidth;
    final dy = v * displayHeight;
    final double px;
    final double py;
    switch (rotation) {
      case 0:
        px = dx;
        py = boxHeight - dy;
      case 90:
        px = dy;
        py = dx;
      case 180:
        px = boxWidth - dx;
        py = dy;
      default:
        px = boxWidth - dy;
        py = boxHeight - dx;
    }
    return (x0 + px, y0 + py);
  }

  /// Turns a movement on screen (right, down) into a movement in the file.
  (double, double) vector(double dx, double dy) {
    switch (rotation) {
      case 0:
        return (dx, -dy);
      case 90:
        return (dy, dx);
      case 180:
        return (-dx, dy);
      default:
        return (-dy, -dx);
    }
  }
}

/// A very small reader for the classic PDF file layout.
class _Doc {
  _Doc(Uint8List data) : text = latin1.decode(data) {
    final start = text.lastIndexOf('startxref');
    if (start < 0) throw const FormatException('No xref');
    final match = RegExp(r'startxref\s+(\d+)').matchAsPrefix(text, start);
    if (match == null) throw const FormatException('No xref');
    xrefOffset = int.parse(match.group(1)!);

    if (!text.startsWith('xref', xrefOffset)) throw const FormatException('Not a classic xref table');
    var p = _skip(xrefOffset + 4);
    final header = RegExp(r'(\d+)\s+(\d+)\s*');
    final entry = RegExp(r'(\d{10}) (\d{5}) ([nf])\s*');
    while (!text.startsWith('trailer', p)) {
      final h = header.matchAsPrefix(text, p);
      if (h == null) throw const FormatException('Bad xref');
      final first = int.parse(h.group(1)!);
      final count = int.parse(h.group(2)!);
      p = h.end;
      for (var i = 0; i < count; i++) {
        final e = entry.matchAsPrefix(text, p);
        if (e == null) throw const FormatException('Bad xref entry');
        p = e.end;
        if (e.group(3) == 'n') offsets[first + i] = int.parse(e.group(1)!);
      }
      p = _skip(p);
    }
    final (value, _) = _value(p + 7);
    if (value is! Map) throw const FormatException('Bad trailer');
    trailer = Map<String, Object>.from(value);
    if (trailer.containsKey('Prev') || trailer.containsKey('Encrypt')) {
      throw const FormatException('Unsupported file layout');
    }
    size = int.parse((trailer['Size'] as _Raw).text);
  }

  final String text;
  late final int xrefOffset;
  final Map<int, int> offsets = {};
  late final Map<String, Object> trailer;
  late final int size;

  static bool _isSpace(int c) => c == 32 || c == 9 || c == 10 || c == 13 || c == 12 || c == 0;
  static bool _isDelimiter(int c) =>
      c == 0x28 || c == 0x29 || c == 0x3C || c == 0x3E || c == 0x5B || c == 0x5D || c == 0x7B || c == 0x7D || c == 0x2F || c == 0x25;

  int _skip(int p) {
    while (p < text.length) {
      final c = text.codeUnitAt(p);
      if (_isSpace(c)) {
        p++;
      } else if (c == 0x25) {
        while (p < text.length && text.codeUnitAt(p) != 10 && text.codeUnitAt(p) != 13) {
          p++;
        }
      } else {
        break;
      }
    }
    return p;
  }

  (String, int) _name(int p) {
    var q = p + 1;
    while (q < text.length && !_isSpace(text.codeUnitAt(q)) && !_isDelimiter(text.codeUnitAt(q))) {
      q++;
    }
    return (text.substring(p + 1, q), q);
  }

  static final RegExp _refPattern = RegExp(r'(\d+)[ \t\r\n]+(\d+)[ \t\r\n]+R(?![A-Za-z0-9])');

  (Object, int) _value(int start) {
    var p = _skip(start);
    if (p >= text.length) throw const FormatException('Unexpected end');
    final c = text.codeUnitAt(p);
    if (text.startsWith('<<', p)) {
      p += 2;
      final out = <String, Object>{};
      while (true) {
        p = _skip(p);
        if (text.startsWith('>>', p)) return (out, p + 2);
        if (text.codeUnitAt(p) != 0x2F) throw const FormatException('Bad dictionary');
        final (key, afterKey) = _name(p);
        final (item, afterItem) = _value(afterKey);
        out[key] = item;
        p = afterItem;
      }
    }
    if (c == 0x5B) {
      p++;
      final out = <Object>[];
      while (true) {
        p = _skip(p);
        if (text.codeUnitAt(p) == 0x5D) return (out, p + 1);
        final (item, after) = _value(p);
        out.add(item);
        p = after;
      }
    }
    if (c == 0x28) {
      var q = p + 1;
      var depth = 1;
      while (depth > 0) {
        final ch = text.codeUnitAt(q);
        if (ch == 0x5C) {
          q += 2;
          continue;
        }
        if (ch == 0x28) depth++;
        if (ch == 0x29) depth--;
        q++;
      }
      return (_Raw(text.substring(p, q)), q);
    }
    if (c == 0x3C) {
      final q = text.indexOf('>', p);
      return (_Raw(text.substring(p, q + 1)), q + 1);
    }
    if (c == 0x2F) {
      final (name, after) = _name(p);
      return (_Raw('/$name'), after);
    }
    final ref = _refPattern.matchAsPrefix(text, p);
    if (ref != null) return (_Ref(int.parse(ref.group(1)!)), ref.end);
    var q = p;
    while (q < text.length && !_isSpace(text.codeUnitAt(q)) && !_isDelimiter(text.codeUnitAt(q))) {
      q++;
    }
    if (q == p) throw const FormatException('Bad token');
    return (_Raw(text.substring(p, q)), q);
  }

  Object object(int number) {
    final offset = offsets[number];
    if (offset == null) throw const FormatException('Missing object');
    final head = RegExp(r'\d+\s+\d+\s+obj\s*').matchAsPrefix(text, offset);
    if (head == null) throw const FormatException('Bad object');
    return _value(head.end).$1;
  }

  Object resolve(Object value) {
    var current = value;
    for (var depth = 0; current is _Ref && depth < 20; depth++) {
      current = object(current.number);
    }
    return current;
  }

  List<_Page> pages() {
    final root = resolve(trailer['Root']!);
    if (root is! Map) throw const FormatException('Bad catalog');
    final out = <_Page>[];

    void walk(Object reference, Map<String, Object> inherited, int depth) {
      if (depth > 40) throw const FormatException('Page tree too deep');
      final node = resolve(reference);
      if (node is! Map) throw const FormatException('Bad page');
      final inherit = Map<String, Object>.from(inherited);
      for (final key in const ['Resources', 'MediaBox', 'CropBox', 'Rotate']) {
        final value = node[key];
        if (value != null) inherit[key] = value as Object;
      }
      final kids = node['Kids'];
      if (kids != null) {
        final list = resolve(kids as Object);
        if (list is! List) throw const FormatException('Bad kids');
        for (final kid in list) {
          walk(kid as Object, inherit, depth + 1);
        }
      } else {
        if (reference is! _Ref) throw const FormatException('Page is not a reference');
        out.add(_Page(reference.number, Map<String, Object>.from(node), inherit));
      }
    }

    walk(root['Pages'] as Object, const {}, 0);
    return out;
  }
}
