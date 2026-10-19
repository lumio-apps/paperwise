import 'dart:convert';
import 'dart:typed_data';

/// The details a PDF carries about itself: title, author, the app that made
/// it and when. Read straight from the file, nothing is uploaded.
class PdfInfo {
  const PdfInfo({required this.fields, required this.hasXmp, required this.readable});

  /// Field name to value, only for fields that are filled in.
  final Map<String, String> fields;

  /// True when the file also has the newer XMP block (more of the same details).
  final bool hasXmp;

  /// False when the details sit in a packed part of the file that this reader
  /// does not open.
  final bool readable;

  bool get isClean => readable && fields.isEmpty && !hasXmp;

  static const _keys = <String>[
    'Title',
    'Author',
    'Subject',
    'Keywords',
    'Creator',
    'Producer',
    'CreationDate',
    'ModDate',
  ];

  /// Names shown to the user.
  static String labelOf(String key) => switch (key) {
        'CreationDate' => 'Created',
        'ModDate' => 'Last changed',
        'Creator' => 'Made with',
        'Producer' => 'PDF software',
        _ => key,
      };

  static PdfInfo read(Uint8List data) {
    final text = latin1.decode(data);
    final hasXmp = text.contains('<x:xmpmeta') || RegExp(r'/Type\s*/Metadata').hasMatch(text);

    final refs = RegExp(r'/Info\s+(\d+)\s+(\d+)\s+R').allMatches(text).toList();
    if (refs.isEmpty) return PdfInfo(fields: const {}, hasXmp: hasXmp, readable: true);

    final number = refs.last.group(1)!;
    final generation = refs.last.group(2)!;
    final starts = RegExp('(?:^|[\\r\\n\\t ])$number\\s+$generation\\s+obj').allMatches(text).toList();
    if (starts.isEmpty) return PdfInfo(fields: const {}, hasXmp: hasXmp, readable: false);

    final from = starts.last.end;
    final to = text.indexOf('endobj', from);
    final body = text.substring(from, to < 0 ? text.length : to);

    final fields = <String, String>{};
    for (final key in _keys) {
      final value = _stringAfter(body, key);
      if (value == null) continue;
      final shown = key.endsWith('Date') ? _niceDate(value) : value.trim();
      if (shown.isNotEmpty) fields[key] = shown;
    }
    return PdfInfo(fields: fields, hasXmp: hasXmp, readable: true);
  }

  static String? _stringAfter(String body, String key) {
    final match = RegExp('/$key(?![A-Za-z0-9])\\s*').firstMatch(body);
    if (match == null) return null;
    var p = match.end;
    if (p >= body.length) return null;
    if (body[p] == '(') return _literal(body, p + 1);
    if (body[p] == '<' && !(p + 1 < body.length && body[p + 1] == '<')) {
      final end = body.indexOf('>', p);
      if (end < 0) return null;
      return _hex(body.substring(p + 1, end));
    }
    return null;
  }

  static String _literal(String s, int start) {
    final bytes = <int>[];
    var depth = 1;
    var p = start;
    while (p < s.length) {
      final c = s.codeUnitAt(p);
      if (c == 0x5C) {
        p++;
        if (p >= s.length) break;
        final e = s[p];
        switch (e) {
          case 'n':
            bytes.add(10);
          case 'r':
            bytes.add(13);
          case 't':
            bytes.add(9);
          case 'b':
            bytes.add(8);
          case 'f':
            bytes.add(12);
          case '\r':
            if (p + 1 < s.length && s[p + 1] == '\n') p++;
          case '\n':
            break;
          default:
            if (RegExp(r'[0-7]').hasMatch(e)) {
              var octal = e;
              while (octal.length < 3 && p + 1 < s.length && RegExp(r'[0-7]').hasMatch(s[p + 1])) {
                p++;
                octal += s[p];
              }
              bytes.add(int.parse(octal, radix: 8) & 0xFF);
            } else {
              bytes.add(e.codeUnitAt(0) & 0xFF);
            }
        }
      } else if (c == 0x28) {
        depth++;
        bytes.add(c);
      } else if (c == 0x29) {
        depth--;
        if (depth == 0) break;
        bytes.add(c);
      } else {
        bytes.add(c & 0xFF);
      }
      p++;
    }
    return _decode(bytes);
  }

  static String _hex(String raw) {
    var digits = raw.replaceAll(RegExp(r'\s'), '');
    if (digits.length.isOdd) digits = '${digits}0';
    final bytes = <int>[];
    for (var i = 0; i + 1 < digits.length; i += 2) {
      final v = int.tryParse(digits.substring(i, i + 2), radix: 16);
      if (v != null) bytes.add(v);
    }
    return _decode(bytes);
  }

  static String _decode(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }

  /// "D:20260115093000+04'00'" becomes "2026-01-15 09:30".
  static String _niceDate(String raw) {
    final m = RegExp(r'^D:(\d{4})(\d{2})?(\d{2})?(\d{2})?(\d{2})?').firstMatch(raw.trim());
    if (m == null) return raw.trim();
    final date = '${m.group(1)}-${m.group(2) ?? '01'}-${m.group(3) ?? '01'}';
    if (m.group(4) == null) return date;
    return '$date ${m.group(4)}:${m.group(5) ?? '00'}';
  }
}
