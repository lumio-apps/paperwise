import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'xml_lite.dart';
import 'zip_reader.dart';

/// A piece of text with one look.
class DocRun {
  const DocRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.small = false,
    this.link = false,
    this.sizePt,
    this.color,
    this.highlight,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;

  /// Superscript or subscript.
  final bool small;
  final bool link;

  /// Font size in points, when the document sets one.
  final double? sizePt;

  /// Text color as 0xRRGGBB, when the document sets one.
  final int? color;

  /// Marker color as 0xRRGGBB, when the text is highlighted.
  final int? highlight;
}

/// One thing in the document, from top to bottom.
sealed class DocBlock {
  const DocBlock();
}

enum DocAlign { start, center, end, justify }

class DocParagraph extends DocBlock {
  const DocParagraph({
    required this.runs,
    this.heading = 0,
    this.align = DocAlign.start,
    this.listLabel,
    this.listLevel = 0,
    this.indent = 0,
  });

  final List<DocRun> runs;

  /// 0 for body text, 1 to 6 for headings, 7 for the document title.
  final int heading;
  final DocAlign align;

  /// "•", "1." or "a)" for list items.
  final String? listLabel;
  final int listLevel;

  /// Left indent in points.
  final double indent;

  bool get isEmpty => runs.every((r) => r.text.trim().isEmpty) && listLabel == null;
}

class DocImage extends DocBlock {
  const DocImage({required this.bytes, required this.width, required this.height});

  final Uint8List bytes;

  /// Size in logical pixels, as placed in the document.
  final double width;
  final double height;
}

/// A picture in a format Flutter cannot draw, such as EMF.
class DocMissingImage extends DocBlock {
  const DocMissingImage();
}

class DocPageBreak extends DocBlock {
  const DocPageBreak();
}

class DocTableCell {
  const DocTableCell({required this.blocks, this.span = 1, this.shade});

  final List<DocBlock> blocks;

  /// How many grid columns the cell covers.
  final int span;

  /// Background as 0xRRGGBB.
  final int? shade;
}

class DocTable extends DocBlock {
  const DocTable(this.rows, this.columns);

  final List<List<DocTableCell>> rows;

  /// The number of grid columns.
  final int columns;
}

/// A Word document, ready to show.
class DocumentData {
  const DocumentData(this.blocks);

  final List<DocBlock> blocks;
}

/// Reads a .docx file away from the screen thread.
Future<DocumentData> readDocumentFile(String path) async {
  final bytes = await File(path).readAsBytes();
  return Isolate.run(() => _readBytes(bytes));
}

DocumentData _readBytes(Uint8List bytes) {
  try {
    if (ZipReader.looksLikeOldOffice(bytes)) {
      throw const OfficeFileException(
        'This is an old .doc file or a file locked with a password. Paperwise opens .docx files without a password. '
        'Save it as .docx in a word processor and try again.',
      );
    }
    if (!ZipReader.looksLikeZip(bytes)) {
      throw const OfficeFileException('This is not a Word (.docx) file, or it is damaged.');
    }
    return _DocxReader(ZipReader(bytes)).read();
  } on OfficeFileException {
    rethrow;
  } catch (_) {
    throw const OfficeFileException('This file could not be read. It may be damaged.');
  }
}

/// Pictures stop being loaded after this many bytes, to keep memory low.
const _maxImageBytes = 60 * 1024 * 1024;

class _DocxReader {
  _DocxReader(this.zip);

  final ZipReader zip;
  late final String _folder;
  late final String _relsPath;
  final Map<String, String> _relations = {};
  final Map<String, _StyleInfo> _styles = {};
  final Map<String, Map<int, _ListLevel>> _abstractLists = {};
  final Map<String, String> _listToAbstract = {};
  final Map<String, List<int?>> _listCounters = {};
  int _imageBytes = 0;

  DocumentData read() {
    final mainPath = _mainPart() ?? 'word/document.xml';
    _folder = mainPath.contains('/') ? mainPath.substring(0, mainPath.lastIndexOf('/')) : '';
    final text = zip.readText(mainPath);
    if (text == null) throw const OfficeFileException('This is not a Word (.docx) file, or it is damaged.');

    _readRelations(mainPath);
    _readStyles();
    _readNumbering();

    final root = parseXml(text);
    final body = root.child('document')?.child('body');
    if (body == null) return const DocumentData([]);
    return DocumentData(_blocks(body.elements));
  }

  // ----- parts

  String? _mainPart() {
    final text = zip.readText('_rels/.rels');
    if (text == null) return null;
    for (final relation in parseXml(text).descendants('Relationship')) {
      if ((relation.attr('Type') ?? '').endsWith('/officeDocument')) {
        final target = relation.attr('Target');
        if (target != null) return resolvePart('', target);
      }
    }
    return null;
  }

  void _readRelations(String mainPath) {
    final file = mainPath.substring(mainPath.lastIndexOf('/') + 1);
    _relsPath = _folder.isEmpty ? '_rels/$file.rels' : '$_folder/_rels/$file.rels';
    final text = zip.readText(_relsPath);
    if (text == null) return;
    for (final relation in parseXml(text).descendants('Relationship')) {
      final id = relation.attr('Id');
      final target = relation.attr('Target');
      if (id == null || target == null || relation.attr('TargetMode') == 'External') continue;
      _relations[id] = resolvePart(_folder, target);
    }
  }

  String? _partOfType(String type) {
    final text = zip.readText(_relsPath);
    if (text == null) return null;
    for (final relation in parseXml(text).descendants('Relationship')) {
      if ((relation.attr('Type') ?? '').endsWith('/$type')) {
        final target = relation.attr('Target');
        if (target != null) return resolvePart(_folder, target);
      }
    }
    return null;
  }

  void _readStyles() {
    final text = zip.readText(_partOfType('styles') ?? resolvePart(_folder, 'styles.xml'));
    if (text == null) return;
    for (final style in parseXml(text).descendants('style')) {
      final id = style.attr('styleId');
      if (id == null) continue;
      final outline = int.tryParse(style.child('pPr')?.child('outlineLvl')?.attr('val') ?? '');
      _styles[id] = _StyleInfo(
        name: (style.child('name')?.attr('val') ?? '').toLowerCase(),
        basedOn: style.child('basedOn')?.attr('val'),
        outlineLevel: outline,
      );
    }
  }

  void _readNumbering() {
    final text = zip.readText(_partOfType('numbering') ?? resolvePart(_folder, 'numbering.xml'));
    if (text == null) return;
    final root = parseXml(text);
    for (final abstract in root.descendants('abstractNum')) {
      final id = abstract.attr('abstractNumId');
      if (id == null) continue;
      final levels = <int, _ListLevel>{};
      for (final level in abstract.childrenNamed('lvl')) {
        final index = int.tryParse(level.attr('ilvl') ?? '');
        if (index == null) continue;
        levels[index] = _ListLevel(
          format: level.child('numFmt')?.attr('val') ?? 'decimal',
          text: level.child('lvlText')?.attr('val') ?? '%${index + 1}.',
          start: int.tryParse(level.child('start')?.attr('val') ?? '') ?? 1,
        );
      }
      _abstractLists[id] = levels;
    }
    for (final list in root.descendants('num')) {
      final id = list.attr('numId');
      final abstract = list.child('abstractNumId')?.attr('val');
      if (id != null && abstract != null) _listToAbstract[id] = abstract;
    }
  }

  // ----- body

  List<DocBlock> _blocks(Iterable<XmlElement> elements) {
    final blocks = <DocBlock>[];
    for (final element in elements) {
      switch (element.name) {
        case 'p':
          _paragraph(element, blocks);
        case 'tbl':
          final table = _table(element);
          if (table != null) blocks.add(table);
        case 'sdt':
          final content = element.child('sdtContent');
          if (content != null) blocks.addAll(_blocks(content.elements));
        case 'customXml':
        case 'ins':
        case 'moveTo':
          blocks.addAll(_blocks(element.elements));
        case 'AlternateContent':
          final choice = element.child('Choice') ?? element.child('Fallback');
          if (choice != null) blocks.addAll(_blocks(choice.elements));
      }
    }
    return blocks;
  }

  void _paragraph(XmlElement paragraph, List<DocBlock> blocks) {
    final properties = paragraph.child('pPr');
    final runs = <DocRun>[];
    final after = <DocBlock>[];
    var pageBreak = false;

    if (properties?.child('pageBreakBefore') != null &&
        properties?.child('pageBreakBefore')?.attr('val') != '0' &&
        blocks.isNotEmpty) {
      blocks.add(const DocPageBreak());
    }

    void readInline(XmlElement parent, bool link) {
      for (final element in parent.elements) {
        switch (element.name) {
          case 'r':
            if (_run(element, link, runs, after)) pageBreak = true;
          case 'hyperlink':
            readInline(element, true);
          case 'ins':
          case 'moveTo':
          case 'smartTag':
          case 'customXml':
          case 'fldSimple':
          case 'bdo':
          case 'dir':
            readInline(element, link);
          case 'sdt':
            final content = element.child('sdtContent');
            if (content != null) readInline(content, link);
          case 'AlternateContent':
            final choice = element.child('Choice') ?? element.child('Fallback');
            if (choice != null) readInline(choice, link);
        }
      }
    }

    readInline(paragraph, false);

    final styleId = properties?.child('pStyle')?.attr('val');
    var heading = _headingOf(styleId);
    final ownOutline = int.tryParse(properties?.child('outlineLvl')?.attr('val') ?? '');
    if (heading == 0 && ownOutline != null && ownOutline < 6) heading = ownOutline + 1;

    final align = switch (properties?.child('jc')?.attr('val')) {
      'center' => DocAlign.center,
      'right' || 'end' => DocAlign.end,
      'both' || 'distribute' => DocAlign.justify,
      _ => DocAlign.start,
    };

    String? label;
    var level = 0;
    final numbering = properties?.child('numPr');
    if (numbering != null) {
      final listId = numbering.child('numId')?.attr('val');
      level = int.tryParse(numbering.child('ilvl')?.attr('val') ?? '') ?? 0;
      if (listId != null && listId != '0') label = _listLabel(listId, level < 0 ? 0 : (level > 8 ? 8 : level));
    }

    final indentTwips = double.tryParse(properties?.child('ind')?.attr('left') ?? properties?.child('ind')?.attr('start') ?? '');
    final indent = numbering == null && indentTwips != null && indentTwips > 0 ? indentTwips / 20 : 0.0;

    blocks.add(DocParagraph(
      runs: runs,
      heading: heading,
      align: align,
      listLabel: label,
      listLevel: level,
      indent: indent,
    ));
    blocks.addAll(after);
    if (pageBreak) blocks.add(const DocPageBreak());
  }

  /// Adds the text of a run. Returns true when the run holds a page break.
  bool _run(XmlElement run, bool link, List<DocRun> runs, List<DocBlock> after) {
    final p = run.child('rPr');
    if (_isOn(p?.child('vanish'))) return false;

    final bold = _isOn(p?.child('b'));
    final italic = _isOn(p?.child('i'));
    final underlineValue = p?.child('u')?.attr('val');
    final underline = link || (p?.child('u') != null && underlineValue != 'none');
    final strike = _isOn(p?.child('strike')) || _isOn(p?.child('dstrike'));
    final vertical = p?.child('vertAlign')?.attr('val');
    final small = vertical == 'superscript' || vertical == 'subscript';
    final halfPoints = double.tryParse(p?.child('sz')?.attr('val') ?? '');
    final colorValue = p?.child('color')?.attr('val');
    final color = colorValue == null || colorValue == 'auto' ? null : int.tryParse(colorValue, radix: 16);
    final highlight = _highlightColor(p?.child('highlight')?.attr('val')) ?? _shadeColor(p?.child('shd'));

    final text = StringBuffer();
    var pageBreak = false;

    void flush() {
      if (text.isEmpty) return;
      runs.add(DocRun(
        text.toString(),
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        small: small,
        link: link,
        sizePt: halfPoints == null ? null : halfPoints / 2,
        color: color,
        highlight: highlight,
      ));
      text.clear();
    }

    for (final element in run.elements) {
      switch (element.name) {
        case 't':
          text.write(element.text);
        case 'tab':
          text.write('    ');
        case 'br':
          if (element.attr('type') == 'page') {
            pageBreak = true;
          } else {
            text.write('\n');
          }
        case 'cr':
          text.write('\n');
        case 'noBreakHyphen':
          text.write('-');
        case 'drawing':
        case 'pict':
          flush();
          _picture(element, after);
        case 'AlternateContent':
          final choice = element.child('Choice') ?? element.child('Fallback');
          if (choice != null) {
            flush();
            _picture(choice, after);
          }
      }
    }
    flush();
    return pageBreak;
  }

  /// Pictures and text boxes inside a drawing go after the paragraph.
  void _picture(XmlElement drawing, List<DocBlock> after) {
    final blip = drawing.descendants('blip').firstOrNull ?? drawing.descendants('imagedata').firstOrNull;
    final id = blip?.attr('embed') ?? blip?.attr('id');
    if (id != null) {
      final path = _relations[id];
      final bytes = path == null ? null : zip.read(path);
      if (bytes != null && _canDraw(bytes) && _imageBytes + bytes.length <= _maxImageBytes) {
        _imageBytes += bytes.length;
        final extent = drawing.descendants('extent').firstOrNull;
        final cx = double.tryParse(extent?.attr('cx') ?? '');
        final cy = double.tryParse(extent?.attr('cy') ?? '');
        after.add(DocImage(
          bytes: bytes,
          width: cx == null || cx <= 0 ? 0 : cx / 9525,
          height: cy == null || cy <= 0 ? 0 : cy / 9525,
        ));
      } else if (bytes != null) {
        after.add(const DocMissingImage());
      }
    }
    for (final box in drawing.descendants('txbxContent')) {
      after.addAll(_blocks(box.elements));
    }
  }

  static bool _canDraw(Uint8List b) {
    if (b.length < 12) return false;
    final png = b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;
    final jpeg = b[0] == 0xFF && b[1] == 0xD8;
    final gif = b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46;
    final bmp = b[0] == 0x42 && b[1] == 0x4D;
    final webp = b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45;
    return png || jpeg || gif || bmp || webp;
  }

  DocTable? _table(XmlElement table) {
    final grid = table.child('tblGrid')?.childrenNamed('gridCol').length ?? 0;
    final rows = <List<DocTableCell>>[];
    var widest = 0;
    for (final row in table.childrenNamed('tr')) {
      final cells = <DocTableCell>[];
      var used = 0;
      for (final cell in row.childrenNamed('tc')) {
        final properties = cell.child('tcPr');
        // A cell merged into the one above shows nothing of its own.
        final merge = properties?.child('vMerge');
        final continues = merge != null && merge.attr('val') != 'restart';
        final spanValue = int.tryParse(properties?.child('gridSpan')?.attr('val') ?? '') ?? 1;
        final span = spanValue < 1 ? 1 : (spanValue > 63 ? 63 : spanValue);
        cells.add(DocTableCell(
          blocks: continues ? const [] : _blocks(cell.elements),
          span: span,
          shade: _shadeColor(properties?.child('shd')),
        ));
        used += span;
      }
      if (cells.isEmpty) continue;
      rows.add(cells);
      if (used > widest) widest = used;
    }
    if (rows.isEmpty) return null;
    return DocTable(rows, grid > widest ? grid : widest);
  }

  // ----- styles and lists

  int _headingOf(String? styleId) {
    var id = styleId;
    for (var depth = 0; id != null && depth < 8; depth++) {
      final style = _styles[id];
      if (style == null) {
        final match = RegExp(r'^heading\s*([1-6])$', caseSensitive: false).firstMatch(id);
        if (match != null) return int.parse(match.group(1)!);
        if (id.toLowerCase() == 'title') return 7;
        return 0;
      }
      final match = RegExp(r'^heading\s*([1-6])$').firstMatch(style.name);
      if (match != null) return int.parse(match.group(1)!);
      if (style.name == 'title') return 7;
      final outline = style.outlineLevel;
      if (outline != null && outline < 6) return outline + 1;
      id = style.basedOn;
    }
    return 0;
  }

  String _listLabel(String listId, int level) {
    final abstract = _abstractLists[_listToAbstract[listId]];
    final info = abstract?[level];
    if (info == null) return '•';
    if (info.format == 'none') return '';
    if (info.format == 'bullet') {
      final mark = info.text.trim();
      if (mark == '-' || mark == '–' || mark == '—' || mark == '*') return mark;
      if (mark == 'o') return '◦';
      return level.isOdd ? '◦' : '•';
    }

    final counters = _listCounters.putIfAbsent(listId, () => List<int?>.filled(9, null));
    counters[level] = counters[level] == null ? info.start : counters[level]! + 1;
    for (var deeper = level + 1; deeper < 9; deeper++) {
      counters[deeper] = null;
    }

    return info.text.replaceAllMapped(RegExp('%([1-9])'), (match) {
      final index = int.parse(match.group(1)!) - 1;
      final levelInfo = abstract?[index];
      final value = counters[index] ?? levelInfo?.start ?? 1;
      return _formatNumber(value, levelInfo?.format ?? 'decimal');
    });
  }

  static String _formatNumber(int value, String format) {
    switch (format) {
      case 'lowerLetter':
        return _letters(value).toLowerCase();
      case 'upperLetter':
        return _letters(value);
      case 'lowerRoman':
        return _roman(value).toLowerCase();
      case 'upperRoman':
        return _roman(value);
      case 'decimalZero':
        return value.toString().padLeft(2, '0');
      default:
        return '$value';
    }
  }

  static String _letters(int value) {
    if (value <= 0) return '$value';
    final letter = String.fromCharCode(0x41 + (value - 1) % 26);
    return letter * ((value - 1) ~/ 26 + 1);
  }

  static String _roman(int value) {
    if (value <= 0 || value >= 4000) return '$value';
    const numerals = [
      (1000, 'M'),
      (900, 'CM'),
      (500, 'D'),
      (400, 'CD'),
      (100, 'C'),
      (90, 'XC'),
      (50, 'L'),
      (40, 'XL'),
      (10, 'X'),
      (9, 'IX'),
      (5, 'V'),
      (4, 'IV'),
      (1, 'I'),
    ];
    var rest = value;
    final out = StringBuffer();
    for (final (amount, letters) in numerals) {
      while (rest >= amount) {
        out.write(letters);
        rest -= amount;
      }
    }
    return out.toString();
  }

  /// `<w:b/>` is on, `<w:b w:val="0"/>` is off.
  static bool _isOn(XmlElement? element) {
    if (element == null) return false;
    final value = element.attr('val');
    return value == null || value == '1' || value == 'true' || value == 'on';
  }

  static int? _shadeColor(XmlElement? shade) {
    final fill = shade?.attr('fill');
    if (fill == null || fill == 'auto' || fill.length != 6) return null;
    final value = int.tryParse(fill, radix: 16);
    // White fill is the same as no fill.
    return value == 0xFFFFFF ? null : value;
  }

  static int? _highlightColor(String? name) {
    return switch (name) {
      'yellow' => 0xFFFF00,
      'green' => 0x00FF00,
      'cyan' => 0x00FFFF,
      'magenta' => 0xFF00FF,
      'blue' => 0x0000FF,
      'red' => 0xFF0000,
      'darkBlue' => 0x000080,
      'darkCyan' => 0x008080,
      'darkGreen' => 0x008000,
      'darkMagenta' => 0x800080,
      'darkRed' => 0x800000,
      'darkYellow' => 0x808000,
      'darkGray' => 0x808080,
      'lightGray' => 0xC0C0C0,
      'black' => 0x000000,
      _ => null,
    };
  }
}

class _StyleInfo {
  const _StyleInfo({required this.name, this.basedOn, this.outlineLevel});

  final String name;
  final String? basedOn;
  final int? outlineLevel;
}

class _ListLevel {
  const _ListLevel({required this.format, required this.text, required this.start});

  final String format;
  final String text;
  final int start;
}
