import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'cell_format.dart';
import 'xml_lite.dart';
import 'zip_reader.dart';

/// One sheet, ready to show as a table.
class SheetData {
  const SheetData({
    required this.name,
    required this.rows,
    required this.columnCount,
    required this.columnWidths,
    this.note,
  });

  final String name;

  /// Row by row, the text of each cell. A row can be shorter than [columnCount].
  final List<List<String>> rows;
  final int columnCount;

  /// Width of each column in logical pixels.
  final List<double> columnWidths;

  /// A short message shown above the table, for example when it was cut short.
  final String? note;

  bool get isEmpty => rows.isEmpty || columnCount == 0;
}

/// The sheets of an Excel or CSV file.
class WorkbookData {
  const WorkbookData(this.sheets);

  final List<SheetData> sheets;
}

/// Big sheets are cut here so the phone stays fast.
const maxSheetRows = 20000;
const maxSheetColumns = 200;

/// Reads an .xlsx or .csv file away from the screen thread.
Future<WorkbookData> readSheetFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final isCsv = path.toLowerCase().endsWith('.csv') || path.toLowerCase().endsWith('.tsv');
  final name = path.split(RegExp(r'[\\/]')).last;
  return Isolate.run(() => _readBytes(bytes, isCsv, name));
}

WorkbookData _readBytes(Uint8List bytes, bool isCsv, String fileName) {
  try {
    if (isCsv) return WorkbookData([_readCsv(bytes, fileName)]);
    if (ZipReader.looksLikeOldOffice(bytes)) {
      throw const OfficeFileException(
        'This is an old .xls file or a file locked with a password. Paperwise opens .xlsx files without a password. '
        'Save it as .xlsx in a spreadsheet app and try again.',
      );
    }
    if (!ZipReader.looksLikeZip(bytes)) {
      throw const OfficeFileException('This is not an Excel (.xlsx) file, or it is damaged.');
    }
    return _readXlsx(ZipReader(bytes));
  } on OfficeFileException {
    rethrow;
  } catch (_) {
    throw const OfficeFileException('This file could not be read. It may be damaged.');
  }
}

// ----- CSV

SheetData _readCsv(Uint8List bytes, String fileName) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);

  // Pick the separator that appears most often in the first line.
  final firstLine = text.split('\n').first;
  var separator = ',';
  var best = -1;
  for (final candidate in const [',', ';', '\t', '|']) {
    final count = candidate.allMatches(firstLine).length;
    if (count > best) {
      best = count;
      separator = candidate;
    }
  }

  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var truncatedRows = false;
  var truncatedColumns = false;

  void endCell() {
    if (row.length < maxSheetColumns) {
      row.add(cell.toString());
    } else {
      truncatedColumns = true;
    }
    cell.clear();
  }

  void endRow() {
    endCell();
    while (row.isNotEmpty && row.last.isEmpty) {
      row.removeLast();
    }
    rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(char);
      }
    } else if (char == '"' && cell.isEmpty) {
      inQuotes = true;
    } else if (char == separator) {
      endCell();
    } else if (char == '\n') {
      endRow();
      if (rows.length >= maxSheetRows) {
        truncatedRows = i + 1 < text.length;
        break;
      }
    } else if (char != '\r') {
      cell.write(char);
    }
  }
  if (rows.length < maxSheetRows && (cell.isNotEmpty || row.isNotEmpty)) endRow();
  while (rows.isNotEmpty && rows.last.isEmpty) {
    rows.removeLast();
  }

  final columns = rows.fold<int>(0, (most, r) => math.max(most, r.length));
  return SheetData(
    name: fileName,
    rows: rows,
    columnCount: columns,
    columnWidths: _autoWidths(rows, columns, const {}),
    note: _cutNote(truncatedRows, truncatedColumns),
  );
}

// ----- XLSX

WorkbookData _readXlsx(ZipReader zip) {
  final workbookPath = _mainPart(zip) ?? 'xl/workbook.xml';
  final workbookText = zip.readText(workbookPath);
  if (workbookText == null) {
    throw const OfficeFileException('This is not an Excel (.xlsx) file, or it is damaged.');
  }
  final folder = workbookPath.contains('/') ? workbookPath.substring(0, workbookPath.lastIndexOf('/')) : '';
  final workbook = parseXml(workbookText);
  final relations = _relationships(zip, workbookPath);

  final properties = workbook.descendants('workbookPr').firstOrNull;
  final date1904 = properties?.attr('date1904') == '1' || properties?.attr('date1904') == 'true';

  String? partOfType(String type) {
    for (final relation in relations.values) {
      if (relation.type.endsWith('/$type')) return resolvePart(folder, relation.target);
    }
    return null;
  }

  final shared = _sharedStrings(zip, partOfType('sharedStrings') ?? resolvePart(folder, 'sharedStrings.xml'));
  final formats = _cellFormats(zip, partOfType('styles') ?? resolvePart(folder, 'styles.xml'));

  final entries = workbook.descendants('sheet').toList();
  var visible = entries.where((s) {
    final state = s.attr('state');
    return state != 'hidden' && state != 'veryHidden';
  }).toList();
  if (visible.isEmpty) visible = entries;

  final sheets = <SheetData>[];
  for (final entry in visible) {
    final name = entry.attr('name') ?? 'Sheet ${sheets.length + 1}';
    final relation = relations[entry.attr('id')];
    if (relation == null) {
      sheets.add(_noteSheet(name, 'This sheet could not be found in the file.'));
      continue;
    }
    final path = resolvePart(folder, relation.target);
    if (relation.type.endsWith('/chartsheet')) {
      sheets.add(_noteSheet(name, 'This sheet is a chart. Charts are not shown yet.'));
      continue;
    }
    final text = zip.readText(path);
    if (text == null) {
      sheets.add(_noteSheet(name, 'This sheet could not be found in the file.'));
      continue;
    }
    if (text.length > 80 * 1024 * 1024) {
      sheets.add(_noteSheet(name, 'This sheet is too large to open on a phone.'));
      continue;
    }
    sheets.add(_readSheet(name, text, shared, formats, date1904));
  }

  if (sheets.isEmpty) throw const OfficeFileException('This file has no sheets.');
  return WorkbookData(sheets);
}

SheetData _noteSheet(String name, String note) =>
    SheetData(name: name, rows: const [], columnCount: 0, columnWidths: const [], note: note);

/// Finds the main part of the file from `_rels/.rels`.
String? _mainPart(ZipReader zip) {
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

class _Relation {
  const _Relation(this.type, this.target);

  final String type;
  final String target;
}

/// Reads the `.rels` file that belongs to [partPath].
Map<String, _Relation> _relationships(ZipReader zip, String partPath) {
  final slash = partPath.lastIndexOf('/');
  final folder = slash < 0 ? '' : partPath.substring(0, slash);
  final file = slash < 0 ? partPath : partPath.substring(slash + 1);
  final text = zip.readText(folder.isEmpty ? '_rels/$file.rels' : '$folder/_rels/$file.rels');
  final result = <String, _Relation>{};
  if (text == null) return result;
  for (final relation in parseXml(text).descendants('Relationship')) {
    final id = relation.attr('Id');
    final target = relation.attr('Target');
    if (id == null || target == null || relation.attr('TargetMode') == 'External') continue;
    result[id] = _Relation(relation.attr('Type') ?? '', target);
  }
  return result;
}

List<String> _sharedStrings(ZipReader zip, String path) {
  final text = zip.readText(path);
  if (text == null) return const [];
  final root = parseXml(text);
  final table = root.child('sst') ?? root;
  return [for (final item in table.childrenNamed('si')) _richText(item)];
}

/// The text of a shared or inline string, without the phonetic guides.
String _richText(XmlElement item) {
  final out = StringBuffer();
  for (final part in item.elements) {
    if (part.name == 't') {
      out.write(part.text);
    } else if (part.name == 'r') {
      for (final piece in part.childrenNamed('t')) {
        out.write(piece.text);
      }
    }
  }
  return out.toString();
}

/// The number format of each cell style, by style index.
List<CellFormat?> _cellFormats(ZipReader zip, String path) {
  final text = zip.readText(path);
  if (text == null) return const [];
  final root = parseXml(text);

  final custom = <int, String>{};
  for (final format in root.descendants('numFmt')) {
    final id = int.tryParse(format.attr('numFmtId') ?? '');
    final code = format.attr('formatCode');
    if (id != null && code != null) custom[id] = code;
  }

  final cache = <int, CellFormat>{};
  final result = <CellFormat?>[];
  final styles = root.descendants('cellXfs').firstOrNull;
  if (styles == null) return result;
  for (final style in styles.childrenNamed('xf')) {
    final id = int.tryParse(style.attr('numFmtId') ?? '0') ?? 0;
    result.add(cache.putIfAbsent(id, () => CellFormat(custom[id] ?? CellFormat.builtIn(id))));
  }
  return result;
}

SheetData _readSheet(
  String name,
  String text,
  List<String> shared,
  List<CellFormat?> formats,
  bool date1904,
) {
  final root = parseXml(text);
  final sheet = root.child('worksheet') ?? root;

  final explicitWidths = <int, double>{};
  final columns = sheet.child('cols');
  if (columns != null) {
    for (final column in columns.childrenNamed('col')) {
      final min = int.tryParse(column.attr('min') ?? '');
      final max = int.tryParse(column.attr('max') ?? '');
      final width = double.tryParse(column.attr('width') ?? '');
      if (min == null || max == null || width == null) continue;
      final pixels = (width * 7 + 12).clamp(48.0, 360.0).toDouble();
      for (var c = min - 1; c < math.min(max, maxSheetColumns); c++) {
        explicitWidths[c] = pixels;
      }
    }
  }

  final byRow = <int, List<String>>{};
  var lastRow = -1;
  var columnCount = 0;
  var truncatedRows = false;
  var truncatedColumns = false;
  var nextRow = 0;

  final data = sheet.child('sheetData');
  if (data != null) {
    for (final row in data.childrenNamed('row')) {
      final number = int.tryParse(row.attr('r') ?? '');
      final rowIndex = number == null ? nextRow : number - 1;
      nextRow = rowIndex + 1;
      if (rowIndex >= maxSheetRows) {
        truncatedRows = true;
        break;
      }

      final cells = <String>[];
      var nextColumn = 0;
      for (final cell in row.childrenNamed('c')) {
        final reference = cell.attr('r');
        final column = reference == null ? nextColumn : _columnIndex(reference);
        nextColumn = column + 1;
        if (column >= maxSheetColumns) {
          truncatedColumns = true;
          continue;
        }
        final value = _cellText(cell, shared, formats, date1904);
        if (value.isEmpty) continue;
        while (cells.length <= column) {
          cells.add('');
        }
        cells[column] = value;
      }
      if (cells.isEmpty) continue;
      byRow[rowIndex] = cells;
      lastRow = math.max(lastRow, rowIndex);
      columnCount = math.max(columnCount, cells.length);
    }
  }

  final rows = List<List<String>>.generate(lastRow + 1, (i) => byRow[i] ?? const <String>[]);
  return SheetData(
    name: name,
    rows: rows,
    columnCount: columnCount,
    columnWidths: _autoWidths(rows, columnCount, explicitWidths),
    note: _cutNote(truncatedRows, truncatedColumns),
  );
}

String _cellText(XmlElement cell, List<String> shared, List<CellFormat?> formats, bool date1904) {
  final type = cell.attr('t') ?? 'n';
  if (type == 'inlineStr') {
    final inline = cell.child('is');
    return inline == null ? '' : _richText(inline);
  }
  final raw = cell.child('v')?.text;
  if (raw == null) return '';
  switch (type) {
    case 's':
      final index = int.tryParse(raw.trim());
      return index != null && index >= 0 && index < shared.length ? shared[index] : '';
    case 'b':
      return raw.trim() == '1' ? 'TRUE' : 'FALSE';
    case 'str':
    case 'e':
      return raw;
    case 'd':
      return raw.replaceFirst('T00:00:00', '').replaceFirst('T', ' ');
  }
  final number = double.tryParse(raw.trim());
  if (number == null) return raw;
  final style = int.tryParse(cell.attr('s') ?? '');
  final format = style != null && style >= 0 && style < formats.length ? formats[style] : null;
  return format == null ? CellFormat.generalNumber(number) : format.format(number, date1904: date1904);
}

/// "C12" → 2 (columns count from 0).
int _columnIndex(String reference) {
  var index = 0;
  for (var i = 0; i < reference.length; i++) {
    final code = reference.codeUnitAt(i) | 0x20; // lower case
    if (code < 0x61 || code > 0x7A) break;
    index = index * 26 + (code - 0x60);
  }
  return index - 1;
}

/// Column widths: the file's own width, or one that fits the first rows.
List<double> _autoWidths(List<List<String>> rows, int columns, Map<int, double> explicit) {
  final widths = List<double>.filled(columns, 72);
  final sample = math.min(rows.length, 300);
  for (var c = 0; c < columns; c++) {
    final fixed = explicit[c];
    if (fixed != null) {
      widths[c] = fixed;
      continue;
    }
    var longest = 0;
    for (var r = 0; r < sample; r++) {
      final row = rows[r];
      if (c < row.length) {
        final firstLine = row[c].split('\n').first;
        longest = math.max(longest, firstLine.length);
      }
    }
    widths[c] = (longest * 7.6 + 20).clamp(56.0, 280.0).toDouble();
  }
  return widths;
}

String? _cutNote(bool rows, bool columns) {
  if (rows && columns) return 'Only the first 20,000 rows and 200 columns are shown.';
  if (rows) return 'Only the first 20,000 rows are shown.';
  if (columns) return 'Only the first 200 columns are shown.';
  return null;
}

/// "A", "B", ... "Z", "AA", ... for column [index] (from 0).
String columnName(int index) {
  var n = index + 1;
  final out = StringBuffer();
  while (n > 0) {
    final rest = (n - 1) % 26;
    out.write(String.fromCharCode(0x41 + rest));
    n = (n - 1) ~/ 26;
  }
  return out.toString().split('').reversed.join();
}
